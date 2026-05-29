package com.homepanel.clock;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    private static final int LOCATION_REQUEST_CODE = 1001;
    private static final String TAG = "HomeInfoClock";
    private static final long WEATHER_REFRESH_MS = 15L * 60L * 1000L;
    private static final long LOCATION_REFRESH_MS = 30_000L;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService ioExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService labelExecutor = Executors.newSingleThreadExecutor();

    private HomePanelView panelView;
    private LocationManager locationManager;
    private Location lastLocation;
    private long lastWeatherFetchAt;
    private long lastLocationLabelAt;
    private boolean fetchingWeather;

    private final LocationListener locationListener = location -> {
        lastLocation = location;
        Log.i(TAG, "location update provider=" + location.getProvider()
            + " lat=" + location.getLatitude()
            + " lon=" + location.getLongitude()
            + " accuracy=" + location.getAccuracy());
        panelView.setLocation(location, false);
        resolveLocationLabelIfNeeded(location);
        fetchWeatherIfNeeded(false);
    };

    private final Runnable refreshRunnable = new Runnable() {
        @Override
        public void run() {
            updateBattery();
            fetchWeatherIfNeeded(true);
            mainHandler.postDelayed(this, 60_000L);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        enterImmersiveMode();

        panelView = new HomePanelView(this);
        setContentView(panelView);

        locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        updateBattery();
        requestLocationIfNeeded();
    }

    @Override
    protected void onResume() {
        super.onResume();
        enterImmersiveMode();
        updateBattery();
        startLocationUpdates();
        fetchWeatherIfNeeded(true);
        mainHandler.removeCallbacks(refreshRunnable);
        mainHandler.postDelayed(refreshRunnable, 60_000L);
    }

    @Override
    protected void onPause() {
        super.onPause();
        stopLocationUpdates();
        mainHandler.removeCallbacks(refreshRunnable);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        ioExecutor.shutdownNow();
        labelExecutor.shutdownNow();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) enterImmersiveMode();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOCATION_REQUEST_CODE) {
            startLocationUpdates();
            fetchWeatherIfNeeded(true);
        }
    }

    private void enterImmersiveMode() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        );
    }

    private void requestLocationIfNeeded() {
        if (hasLocationPermission()) {
            startLocationUpdates();
            fetchWeatherIfNeeded(true);
            return;
        }

        requestPermissions(
            new String[] {
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            },
            LOCATION_REQUEST_CODE
        );
    }

    @SuppressLint("MissingPermission")
    private void startLocationUpdates() {
        if (locationManager == null || !hasLocationPermission()) {
            panelView.setLocation(null, true);
            return;
        }

        Location best = bestLastKnownLocation();
        if (best != null) {
            lastLocation = best;
            panelView.setLocation(best, false);
            resolveLocationLabelIfNeeded(best);
        }

        try {
            locationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                LOCATION_REFRESH_MS,
                5f,
                locationListener
            );
            locationManager.requestSingleUpdate(LocationManager.NETWORK_PROVIDER, locationListener, null);
        } catch (IllegalArgumentException ignored) {
        }

        try {
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                LOCATION_REFRESH_MS,
                5f,
                locationListener
            );
            locationManager.requestSingleUpdate(LocationManager.GPS_PROVIDER, locationListener, null);
        } catch (IllegalArgumentException ignored) {
        }
    }

    private void stopLocationUpdates() {
        if (locationManager == null) return;

        try {
            locationManager.removeUpdates(locationListener);
        } catch (SecurityException ignored) {
        }
    }

    private boolean hasLocationPermission() {
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    @SuppressLint("MissingPermission")
    private Location bestLastKnownLocation() {
        if (locationManager == null || !hasLocationPermission()) return null;

        Location best = null;
        for (String provider : locationManager.getProviders(true)) {
            Location candidate;
            try {
                candidate = locationManager.getLastKnownLocation(provider);
            } catch (SecurityException ignored) {
                continue;
            }

            if (candidate != null && (best == null || candidate.getAccuracy() < best.getAccuracy())) {
                best = candidate;
            }
        }

        if (best != null) {
            Log.i(TAG, "last known provider=" + best.getProvider()
                + " lat=" + best.getLatitude()
                + " lon=" + best.getLongitude()
                + " accuracy=" + best.getAccuracy());
        } else {
            Log.i(TAG, "last known location unavailable");
        }
        return best;
    }

    private void updateBattery() {
        Intent status = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if (status == null) return;

        int level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        int scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
        int plugged = status.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0);
        int percent = scale > 0 && level >= 0 ? Math.round(level * 100f / scale) : -1;

        if (percent >= 0) {
            panelView.setBattery(percent, plugged != 0);
        }
    }

    private void fetchWeatherIfNeeded(boolean allowCached) {
        Location location = lastLocation;
        if (location == null) {
            Location best = bestLastKnownLocation();
            if (best != null) {
                lastLocation = best;
                location = best;
                panelView.setLocation(best, false);
                resolveLocationLabelIfNeeded(best);
            }
        }

        if (location == null) {
            panelView.setWeatherStatus("等待定位");
            return;
        }

        long now = System.currentTimeMillis();
        if (allowCached && now - lastWeatherFetchAt < WEATHER_REFRESH_MS) return;
        if (fetchingWeather) return;

        fetchingWeather = true;
        panelView.setWeatherStatus("更新天气中");
        Location requestLocation = new Location(location);

        ioExecutor.execute(() -> {
            try {
                HomePanelView.WeatherSnapshot snapshot = fetchWeather(requestLocation);
                snapshot.locationLabel = resolveLocationLabel(requestLocation);
                snapshot.updatedAtMillis = System.currentTimeMillis();
                mainHandler.post(() -> {
                    lastWeatherFetchAt = snapshot.updatedAtMillis;
                    fetchingWeather = false;
                    panelView.setWeather(snapshot);
                });
            } catch (Exception error) {
                Log.w(TAG, "weather fetch failed", error);
                mainHandler.post(() -> {
                    fetchingWeather = false;
                    panelView.setWeatherStatus("天气更新失败");
                });
            }
        });
    }

    private HomePanelView.WeatherSnapshot fetchWeather(Location location) throws Exception {
        String url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + location.getLatitude()
            + "&longitude=" + location.getLongitude()
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,wind_speed_10m_max"
            + "&forecast_days=7&timezone=auto";

        JSONObject root = new JSONObject(readUrl(url));
        JSONObject current = root.getJSONObject("current");
        JSONObject daily = root.getJSONObject("daily");

        HomePanelView.WeatherSnapshot snapshot = new HomePanelView.WeatherSnapshot();
        int currentCode = current.optInt("weather_code", 0);
        snapshot.currentTemp = Math.round((float) current.optDouble("temperature_2m", 0));
        snapshot.apparentTemp = Math.round((float) current.optDouble("apparent_temperature", snapshot.currentTemp));
        snapshot.humidity = Math.round((float) current.optDouble("relative_humidity_2m", 0));
        snapshot.windKmh = Math.round((float) current.optDouble("wind_speed_10m", 0));
        snapshot.currentCode = currentCode;
        snapshot.currentDescription = weatherDescription(currentCode);
        snapshot.days = parseDailyForecast(daily);
        return snapshot;
    }

    private List<HomePanelView.WeatherDay> parseDailyForecast(JSONObject daily) throws Exception {
        java.util.ArrayList<HomePanelView.WeatherDay> days = new java.util.ArrayList<>();
        JSONArray dates = daily.getJSONArray("time");
        JSONArray codes = daily.getJSONArray("weather_code");
        JSONArray highs = daily.getJSONArray("temperature_2m_max");
        JSONArray lows = daily.getJSONArray("temperature_2m_min");
        JSONArray pops = daily.getJSONArray("precipitation_probability_max");
        JSONArray uvs = daily.getJSONArray("uv_index_max");
        JSONArray winds = daily.getJSONArray("wind_speed_10m_max");

        for (int i = 0; i < dates.length(); i++) {
            int code = codes.optInt(i, 0);
            HomePanelView.WeatherDay day = new HomePanelView.WeatherDay();
            day.date = dates.optString(i);
            day.code = code;
            day.description = weatherDescription(code);
            day.icon = weatherIcon(code);
            day.high = Math.round((float) highs.optDouble(i, 0));
            day.low = Math.round((float) lows.optDouble(i, 0));
            day.precipitation = Math.max(0, pops.optInt(i, 0));
            day.uv = Math.round((float) uvs.optDouble(i, 0));
            day.windKmh = Math.round((float) winds.optDouble(i, 0));
            days.add(day);
        }

        return days;
    }

    private String readUrl(String urlText) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(urlText).openConnection();
        connection.setConnectTimeout(8_000);
        connection.setReadTimeout(8_000);
        connection.setRequestProperty("Accept", "application/json");

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
            connection.getInputStream(),
            StandardCharsets.UTF_8
        ))) {
            StringBuilder builder = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                builder.append(line);
            }
            return builder.toString();
        } finally {
            connection.disconnect();
        }
    }

    private String resolveLocationLabel(Location location) {
        try {
            Geocoder geocoder = new Geocoder(this, Locale.CHINA);
            List<Address> addresses = geocoder.getFromLocation(location.getLatitude(), location.getLongitude(), 1);
            if (addresses != null && !addresses.isEmpty()) {
                Address address = addresses.get(0);
                String city = firstNonEmpty(address.getLocality(), address.getSubAdminArea(), address.getAdminArea());
                String district = firstNonEmpty(address.getSubLocality(), address.getFeatureName());
                if (city != null && district != null && !city.equals(district)) return city + " " + district;
                if (city != null) return city;
            }
        } catch (Exception error) {
            Log.w(TAG, "reverse geocode failed", error);
        }

        return String.format(
            Locale.US,
            "位置 %.4f, %.4f",
            location.getLatitude(),
            location.getLongitude()
        );
    }

    private void resolveLocationLabelIfNeeded(Location location) {
        long now = System.currentTimeMillis();
        if (now - lastLocationLabelAt < WEATHER_REFRESH_MS) return;
        lastLocationLabelAt = now;

        String fallback = String.format(
            Locale.US,
            "位置 %.4f, %.4f",
            location.getLatitude(),
            location.getLongitude()
        );
        panelView.setLocationLabel(fallback);

        Location requestLocation = new Location(location);
        labelExecutor.execute(() -> {
            String label = resolveLocationLabel(requestLocation);
            mainHandler.post(() -> panelView.setLocationLabel(label));
        });
    }

    private String firstNonEmpty(String... values) {
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) return value.trim();
        }
        return null;
    }

    private String weatherDescription(int code) {
        if (code == 0) return "晴";
        if (code == 1 || code == 2) return "多云";
        if (code == 3) return "阴";
        if (code == 45 || code == 48) return "雾";
        if (code >= 51 && code <= 57) return "毛毛雨";
        if (code >= 61 && code <= 67) return "雨";
        if (code >= 71 && code <= 77) return "雪";
        if (code >= 80 && code <= 82) return "阵雨";
        if (code >= 85 && code <= 86) return "阵雪";
        if (code >= 95) return "雷雨";
        return "天气";
    }

    private String weatherIcon(int code) {
        if (code == 0) return "☀";
        if (code == 1 || code == 2) return "◐";
        if (code == 3) return "☁";
        if (code == 45 || code == 48) return "≋";
        if (code >= 51 && code <= 67) return "☔";
        if (code >= 71 && code <= 77) return "❄";
        if (code >= 80 && code <= 82) return "☔";
        if (code >= 95) return "⚡";
        return "•";
    }
}
