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
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.zip.GZIPInputStream;

public class MainActivity extends Activity {
    private static final int LOCATION_REQUEST_CODE = 1001;
    private static final String TAG = "HomeInfoClock";
    private static final long WEATHER_REFRESH_MS = 30L * 60L * 1000L;
    private static final long LOCATION_REFRESH_MS = 30_000L;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService ioExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService labelExecutor = Executors.newSingleThreadExecutor();

    private HomePanelView panelView;
    private LocationManager locationManager;
    private Location lastLocation;
    private long lastWeatherFetchAt;
    private long lastLocationLabelAt;
    private String cachedQWeatherJwt;
    private long cachedQWeatherJwtExpiresAtSeconds;
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
                    String message = error instanceof IllegalStateException
                        && error.getMessage() != null
                        && error.getMessage().contains("QWEATHER_API_KEY")
                        ? "请配置和风天气 Key"
                        : "天气更新失败";
                    panelView.setWeatherStatus(message);
                });
            }
        });
    }

    private HomePanelView.WeatherSnapshot fetchWeather(Location location) throws Exception {
        try {
            HomePanelView.WeatherSnapshot realtime = fetchUapiWeather(location);
            if (realtime.forecastAvailable && realtime.days.size() > 1) {
                return realtime;
            }
            try {
                HomePanelView.WeatherSnapshot forecast = fetchOpenMeteoWeather(location);
                forecast.locationLabel = realtime.locationLabel;
                forecast.updatedAtMillis = realtime.updatedAtMillis;
                forecast.currentTemp = realtime.currentTemp;
                forecast.apparentTemp = realtime.apparentTemp;
                forecast.humidity = realtime.humidity;
                forecast.windKmh = realtime.windKmh;
                forecast.currentCode = realtime.currentCode;
                forecast.currentDescription = realtime.currentDescription;
                forecast.reportTimeLabel = realtime.reportTimeLabel;
                forecast.sourceLabel = "实时+预报";
                forecast.forecastAvailable = true;
                return forecast;
            } catch (Exception forecastError) {
                Log.w(TAG, "Open-Meteo forecast fetch failed", forecastError);
                return realtime;
            }
        } catch (Exception uapiError) {
            Log.w(TAG, "UAPI weather fetch failed", uapiError);
            try {
                HomePanelView.WeatherSnapshot forecast = fetchOpenMeteoWeather(location);
                forecast.locationLabel = resolveLocationLabel(location);
                forecast.sourceLabel = "预报";
                return forecast;
            } catch (Exception forecastError) {
                Log.w(TAG, "Open-Meteo weather fetch failed", forecastError);
            }
        }

        try {
            if (!hasQWeatherJwtConfig() && !hasQWeatherApiKey()) {
                throw new IllegalStateException("weather forecast unavailable");
            }

            return fetchQWeather(location);
        } catch (Exception qweatherError) {
            Log.w(TAG, "QWeather weather fetch failed", qweatherError);
            throw qweatherError;
        }
    }

    private HomePanelView.WeatherSnapshot fetchQWeather(Location location) throws Exception {
        String locationParam = String.format(
            Locale.US,
            "%.2f,%.2f",
            location.getLongitude(),
            location.getLatitude()
        );
        String baseUrl = "https://" + BuildConfig.QWEATHER_API_HOST;

        JSONObject nowRoot = readQWeatherJson(baseUrl + "/v7/weather/now?location=" + locationParam + "&lang=zh&unit=m");
        JSONObject dailyRoot = readQWeatherJson(baseUrl + "/v7/weather/7d?location=" + locationParam + "&lang=zh&unit=m");
        JSONObject indicesRoot = readQWeatherJson(baseUrl + "/v7/indices/3d?location=" + locationParam + "&type=1,3,6,16&lang=zh");

        HomePanelView.WeatherSnapshot snapshot = new HomePanelView.WeatherSnapshot();
        JSONObject now = nowRoot.getJSONObject("now");
        String currentIcon = now.optString("icon", "999");
        snapshot.currentTemp = parseInt(now.optString("temp"), 0);
        snapshot.apparentTemp = parseInt(now.optString("feelsLike"), snapshot.currentTemp);
        snapshot.humidity = parseInt(now.optString("humidity"), 0);
        snapshot.windKmh = parseInt(now.optString("windSpeed"), 0);
        snapshot.currentCode = normalizeQWeatherIcon(currentIcon);
        snapshot.currentDescription = now.optString("text", weatherDescription(snapshot.currentCode));
        snapshot.sourceLabel = "和风预报";
        snapshot.forecastAvailable = true;
        snapshot.days = parseDailyForecast(dailyRoot, parseIndices(indicesRoot));
        return snapshot;
    }

    private HomePanelView.WeatherSnapshot fetchOpenMeteoWeather(Location location) throws Exception {
        String url = "https://api.open-meteo.com/v1/forecast?"
            + "latitude=" + String.format(Locale.US, "%.4f", location.getLatitude())
            + "&longitude=" + String.format(Locale.US, "%.4f", location.getLongitude())
            + "&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max,uv_index_max"
            + "&forecast_days=7&timezone=auto";
        JSONObject root = new JSONObject(readUrl(url));
        JSONObject current = root.getJSONObject("current");

        HomePanelView.WeatherSnapshot snapshot = new HomePanelView.WeatherSnapshot();
        snapshot.updatedAtMillis = System.currentTimeMillis();
        snapshot.currentTemp = Math.round((float) current.optDouble("temperature_2m", 0));
        snapshot.apparentTemp = snapshot.currentTemp;
        snapshot.humidity = Math.round((float) current.optDouble("relative_humidity_2m", 0));
        snapshot.windKmh = Math.round((float) current.optDouble("wind_speed_10m", 0));
        snapshot.currentCode = current.optInt("weather_code", 3);
        snapshot.currentDescription = weatherDescription(snapshot.currentCode);
        snapshot.sourceLabel = "预报";
        snapshot.forecastAvailable = true;
        snapshot.days = parseOpenMeteoDailyForecast(root.getJSONObject("daily"));
        return snapshot;
    }

    private List<HomePanelView.WeatherDay> parseOpenMeteoDailyForecast(JSONObject daily) throws Exception {
        java.util.ArrayList<HomePanelView.WeatherDay> days = new java.util.ArrayList<>();
        JSONArray dates = daily.getJSONArray("time");
        JSONArray codes = daily.getJSONArray("weather_code");
        JSONArray highs = daily.getJSONArray("temperature_2m_max");
        JSONArray lows = daily.getJSONArray("temperature_2m_min");
        JSONArray rain = daily.optJSONArray("precipitation_probability_max");
        JSONArray wind = daily.optJSONArray("wind_speed_10m_max");
        JSONArray uv = daily.optJSONArray("uv_index_max");

        for (int i = 0; i < dates.length(); i++) {
            HomePanelView.WeatherDay day = new HomePanelView.WeatherDay();
            day.date = dates.optString(i);
            day.code = codes.optInt(i, 3);
            day.description = weatherDescription(day.code);
            day.icon = weatherIcon(day.code);
            day.high = Math.round((float) highs.optDouble(i, 0));
            day.low = Math.round((float) lows.optDouble(i, 0));
            day.precipitation = rain == null ? 0 : rain.optInt(i, 0);
            day.windKmh = wind == null ? 0 : Math.round((float) wind.optDouble(i, 0));
            day.uv = uv == null ? 0 : Math.round((float) uv.optDouble(i, 0));
            days.add(day);
        }

        return days;
    }

    private HomePanelView.WeatherSnapshot fetchUapiWeather(Location location) throws Exception {
        String label = resolveLocationLabel(location);
        List<String> cityCandidates = cityQueryCandidates(label);
        if (cityCandidates.isEmpty()) {
            throw new IllegalStateException("city unavailable for no-key weather source");
        }

        JSONObject root = null;
        Exception lastError = null;
        for (String city : cityCandidates) {
            try {
                String url = "https://uapis.cn/api/v1/misc/weather?city="
                    + URLEncoder.encode(city, "UTF-8")
                    + "&forecast=true&indices=true";
                JSONObject candidate = new JSONObject(readUapiUrl(url));
                if (candidate.has("code") && candidate.optInt("code") != 200) {
                    throw new IllegalStateException("UAPI weather request failed: " + candidate);
                }
                if (!candidate.has("weather") || !candidate.has("temperature")) {
                    throw new IllegalStateException("UAPI weather response missing fields: " + candidate);
                }
                root = candidate;
                break;
            } catch (Exception error) {
                lastError = error;
            }
        }

        if (root == null) {
            throw lastError != null ? lastError : new IllegalStateException("UAPI weather unavailable");
        }

        String weatherText = root.optString("weather", "天气");
        int code = normalizeWeatherText(weatherText);
        int temp = Math.round((float) root.optDouble("temperature", 0));
        int humidity = parseInt(root.optString("humidity"), 0);
        int windKmh = windPowerToKmh(root.optString("wind_power"));
        String windDirection = root.optString("wind_direction");
        String reportTime = root.optString("report_time");

        HomePanelView.WeatherSnapshot snapshot = new HomePanelView.WeatherSnapshot();
        snapshot.locationLabel = firstNonEmpty(root.optString("city"), label);
        snapshot.updatedAtMillis = System.currentTimeMillis();
        snapshot.currentTemp = temp;
        snapshot.apparentTemp = temp;
        snapshot.humidity = humidity;
        snapshot.windKmh = windKmh;
        snapshot.currentCode = code;
        snapshot.currentDescription = weatherText;
        snapshot.sourceLabel = root.optJSONArray("forecast") == null ? "UAPI实时" : "UAPI预报";
        snapshot.reportTimeLabel = reportTime;
        snapshot.forecastAvailable = root.optJSONArray("forecast") != null;
        snapshot.days = parseUapiForecast(root, weatherText, code, temp, humidity, windKmh, windDirection);
        return snapshot;
    }

    private List<HomePanelView.WeatherDay> parseUapiForecast(
        JSONObject root,
        String weatherText,
        int code,
        int temp,
        int humidity,
        int windKmh,
        String windDirection
    ) {
        JSONArray forecast = root.optJSONArray("forecast");
        if (forecast == null || forecast.length() == 0) {
            return buildRealtimeFallbackDays(weatherText, code, temp, humidity, windKmh, windDirection);
        }

        java.util.ArrayList<HomePanelView.WeatherDay> days = new java.util.ArrayList<>();
        JSONObject lifeIndices = root.optJSONObject("life_indices");
        for (int i = 0; i < forecast.length(); i++) {
            JSONObject item = forecast.optJSONObject(i);
            if (item == null) continue;

            String textDay = firstNonEmpty(item.optString("weather_day"), item.optString("weather"), weatherText);
            int dayCode = normalizeWeatherText(textDay);
            HomePanelView.WeatherDay day = new HomePanelView.WeatherDay();
            day.date = item.optString("date");
            day.code = dayCode;
            day.description = textDay;
            day.icon = weatherIcon(dayCode);
            day.high = parseInt(item.optString("temp_max"), temp);
            day.low = parseInt(item.optString("temp_min"), temp);
            day.precipitation = parseInt(item.optString("pop"), item.optDouble("precip", 0d) > 0d ? 55 : 0);
            day.uv = parseInt(item.optString("uv_index"), 0);
            day.windKmh = windPowerToKmh(item.optString("wind_scale_day"));
            day.windDirection = item.optString("wind_dir_day");
            applyUapiLifeIndices(day, lifeIndices);
            days.add(day);
        }

        if (days.isEmpty()) {
            return buildRealtimeFallbackDays(weatherText, code, temp, humidity, windKmh, windDirection);
        }
        return days;
    }

    private void applyUapiLifeIndices(HomePanelView.WeatherDay day, JSONObject lifeIndices) {
        if (lifeIndices == null) return;
        day.clothingTip = uapiLifeAdvice(lifeIndices, "clothing");
        day.umbrellaTip = uapiLifeAdvice(lifeIndices, "umbrella");
        day.travelTip = firstNonEmpty(
            uapiLifeAdvice(lifeIndices, "travel"),
            uapiLifeAdvice(lifeIndices, "traffic")
        );
        day.sportTip = uapiLifeAdvice(lifeIndices, "exercise");
        day.sunProtectionTip = firstNonEmpty(
            uapiLifeAdvice(lifeIndices, "sunscreen"),
            uapiLifeAdvice(lifeIndices, "uv")
        );
    }

    private String uapiLifeAdvice(JSONObject lifeIndices, String key) {
        JSONObject item = lifeIndices.optJSONObject(key);
        return item == null ? null : item.optString("advice");
    }

    private List<HomePanelView.WeatherDay> buildRealtimeFallbackDays(
        String weatherText,
        int code,
        int temp,
        int humidity,
        int windKmh,
        String windDirection
    ) {
        java.util.ArrayList<HomePanelView.WeatherDay> days = new java.util.ArrayList<>();
        for (int i = 0; i < 4; i++) {
            HomePanelView.WeatherDay day = new HomePanelView.WeatherDay();
            day.date = "";
            day.code = code;
            day.description = i == 0 ? weatherText : "暂无预报";
            day.icon = weatherIcon(code);
            day.high = temp;
            day.low = temp;
            day.precipitation = weatherText.contains("雨") || weatherText.contains("雪") ? 55 : 0;
            day.uv = 0;
            day.windKmh = windKmh;
            day.windDirection = windDirection;
            day.clothingTip = temp <= 12 ? "偏凉，建议加外套。" : temp <= 20 ? "早晚偏凉，建议加一件薄外套。" : "温度舒适，轻薄衣物即可。";
            if (weatherText.contains("雨") || weatherText.contains("雪")) {
                day.umbrellaTip = "当前有降水，建议带伞。";
            } else if (humidity >= 85) {
                day.umbrellaTip = "湿度较高，留意短时降水。";
            } else {
                day.umbrellaTip = "当前无明显降水，可轻装出行。";
            }
            day.travelTip = humidity >= 85 ? "湿度高，留意路面湿滑。" : windKmh >= 30 ? "风力偏大，留意阵风。" : "天气平稳，适合出行。";
            days.add(day);
        }
        return days;
    }

    private JSONObject readQWeatherJson(String url) throws Exception {
        JSONObject root = new JSONObject(readUrl(url, true));
        String code = root.optString("code", "");
        if (!"200".equals(code)) {
            throw new IllegalStateException("QWeather request failed: code=" + code + " url=" + url);
        }
        return root;
    }

    private List<HomePanelView.WeatherDay> parseDailyForecast(
        JSONObject dailyRoot,
        Map<String, Map<String, String>> indicesByDate
    ) throws Exception {
        java.util.ArrayList<HomePanelView.WeatherDay> days = new java.util.ArrayList<>();
        JSONArray daily = dailyRoot.getJSONArray("daily");

        for (int i = 0; i < daily.length(); i++) {
            JSONObject item = daily.getJSONObject(i);
            String iconDay = item.optString("iconDay", "999");
            String textDay = item.optString("textDay", "");
            double precipMm = parseDouble(item.optString("precip"), 0d);
            HomePanelView.WeatherDay day = new HomePanelView.WeatherDay();
            day.date = item.optString("fxDate");
            day.code = normalizeQWeatherIcon(iconDay);
            day.description = textDay.isEmpty() ? weatherDescription(day.code) : textDay;
            day.icon = weatherIcon(day.code);
            day.high = parseInt(item.optString("tempMax"), 0);
            day.low = parseInt(item.optString("tempMin"), 0);
            day.precipitation = estimatePrecipitationProbability(textDay, precipMm);
            day.uv = parseInt(item.optString("uvIndex"), 0);
            day.windKmh = parseInt(item.optString("windSpeedDay"), 0);
            applyIndices(day, indicesByDate.get(day.date));
            days.add(day);
        }

        return days;
    }

    private Map<String, Map<String, String>> parseIndices(JSONObject indicesRoot) {
        Map<String, Map<String, String>> result = new HashMap<>();
        JSONArray daily = indicesRoot.optJSONArray("daily");
        if (daily == null) return result;

        for (int i = 0; i < daily.length(); i++) {
            JSONObject item = daily.optJSONObject(i);
            if (item == null) continue;
            String date = item.optString("date");
            String type = item.optString("type");
            String text = item.optString("text");
            if (date.isEmpty() || type.isEmpty() || text.isEmpty()) continue;

            Map<String, String> byType = result.get(date);
            if (byType == null) {
                byType = new HashMap<>();
                result.put(date, byType);
            }
            byType.put(type, text);
        }

        return result;
    }

    private void applyIndices(HomePanelView.WeatherDay day, Map<String, String> indices) {
        if (indices == null) return;
        day.sportTip = indices.get("1");
        day.clothingTip = indices.get("3");
        day.travelTip = indices.get("6");
        day.sunProtectionTip = indices.get("16");
    }

    private String readUrl(String urlText) throws Exception {
        return readUrl(urlText, false);
    }

    private String readUapiUrl(String urlText) throws Exception {
        return readUrl(urlText, false, true);
    }

    private String readUrl(String urlText, boolean qweatherRequest) throws Exception {
        return readUrl(urlText, qweatherRequest, false);
    }

    private String readUrl(String urlText, boolean qweatherRequest, boolean uapiRequest) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(urlText).openConnection();
        connection.setConnectTimeout(8_000);
        connection.setReadTimeout(8_000);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("Accept-Encoding", "gzip");
        if (qweatherRequest) {
            applyQWeatherAuth(connection);
        }
        if (uapiRequest) {
            applyUapiAuth(connection);
        }

        InputStream input = connection.getInputStream();
        if ("gzip".equalsIgnoreCase(connection.getContentEncoding())) {
            input = new GZIPInputStream(input);
        }

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8))) {
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

    private void applyQWeatherAuth(HttpURLConnection connection) throws Exception {
        if (hasQWeatherJwtConfig()) {
            connection.setRequestProperty("Authorization", "Bearer " + qweatherJwt());
            return;
        }

        if (hasQWeatherApiKey()) {
            connection.setRequestProperty("X-QW-Api-Key", BuildConfig.QWEATHER_API_KEY.trim());
        }
    }

    private void applyUapiAuth(HttpURLConnection connection) {
        if (hasUapiToken()) {
            connection.setRequestProperty("Authorization", "Bearer " + BuildConfig.UAPI_TOKEN.trim());
        }
    }

    private boolean hasUapiToken() {
        return BuildConfig.UAPI_TOKEN != null && !BuildConfig.UAPI_TOKEN.trim().isEmpty();
    }

    private boolean hasQWeatherApiKey() {
        return BuildConfig.QWEATHER_API_KEY != null && !BuildConfig.QWEATHER_API_KEY.trim().isEmpty();
    }

    private boolean hasQWeatherJwtConfig() {
        return BuildConfig.QWEATHER_JWT_PROJECT_ID != null
            && !BuildConfig.QWEATHER_JWT_PROJECT_ID.trim().isEmpty()
            && BuildConfig.QWEATHER_JWT_KEY_ID != null
            && !BuildConfig.QWEATHER_JWT_KEY_ID.trim().isEmpty()
            && BuildConfig.QWEATHER_JWT_PRIVATE_KEY != null
            && !BuildConfig.QWEATHER_JWT_PRIVATE_KEY.trim().isEmpty();
    }

    private synchronized String qweatherJwt() throws Exception {
        long nowSeconds = System.currentTimeMillis() / 1000L;
        if (cachedQWeatherJwt != null && nowSeconds < cachedQWeatherJwtExpiresAtSeconds - 300L) {
            return cachedQWeatherJwt;
        }

        long issuedAtSeconds = nowSeconds - 30L;
        long expiresAtSeconds = nowSeconds + 23L * 60L * 60L;
        String header = "{\"alg\":\"EdDSA\",\"kid\":\"" + jsonEscape(BuildConfig.QWEATHER_JWT_KEY_ID.trim()) + "\"}";
        String payload = "{\"sub\":\"" + jsonEscape(BuildConfig.QWEATHER_JWT_PROJECT_ID.trim())
            + "\",\"iat\":" + issuedAtSeconds
            + ",\"exp\":" + expiresAtSeconds + "}";
        String signingInput = base64Url(header.getBytes(StandardCharsets.UTF_8))
            + "."
            + base64Url(payload.getBytes(StandardCharsets.UTF_8));

        Signature signature = Signature.getInstance("Ed25519");
        signature.initSign(qweatherPrivateKey());
        signature.update(signingInput.getBytes(StandardCharsets.UTF_8));
        cachedQWeatherJwt = signingInput + "." + base64Url(signature.sign());
        cachedQWeatherJwtExpiresAtSeconds = expiresAtSeconds;
        return cachedQWeatherJwt;
    }

    private PrivateKey qweatherPrivateKey() throws Exception {
        String pem = BuildConfig.QWEATHER_JWT_PRIVATE_KEY
            .replace("\\n", "\n")
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replaceAll("\\s+", "");
        byte[] keyBytes = android.util.Base64.decode(pem, android.util.Base64.DEFAULT);
        return KeyFactory.getInstance("Ed25519").generatePrivate(new PKCS8EncodedKeySpec(keyBytes));
    }

    private String base64Url(byte[] bytes) {
        return android.util.Base64.encodeToString(
            bytes,
            android.util.Base64.URL_SAFE | android.util.Base64.NO_PADDING | android.util.Base64.NO_WRAP
        );
    }

    private String jsonEscape(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private int parseInt(String value, int fallback) {
        if (value == null || value.trim().isEmpty()) return fallback;
        try {
            return Math.round(Float.parseFloat(value.trim()));
        } catch (NumberFormatException ignored) {
            return fallback;
        }
    }

    private double parseDouble(String value, double fallback) {
        if (value == null || value.trim().isEmpty()) return fallback;
        try {
            return Double.parseDouble(value.trim());
        } catch (NumberFormatException ignored) {
            return fallback;
        }
    }

    private int estimatePrecipitationProbability(String text, double precipMm) {
        if (precipMm >= 10d) return 90;
        if (precipMm >= 2d) return 70;
        if (precipMm > 0d) return 45;
        if (text != null && (text.contains("雨") || text.contains("雪"))) return 55;
        return 0;
    }

    private int normalizeQWeatherIcon(String icon) {
        int code = parseInt(icon, 999);
        if (code == 100 || code == 150) return 0;
        if ((code >= 101 && code <= 103) || (code >= 151 && code <= 153)) return 2;
        if (code == 104 || code == 154) return 3;
        if (code >= 300 && code <= 399) return 61;
        if (code >= 400 && code <= 499) return 71;
        if (code >= 500 && code <= 515) return 45;
        if (code >= 200 && code <= 213) return 2;
        if (code == 900) return 0;
        if (code == 901) return 3;
        return 3;
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

    private List<String> cityQueryCandidates(String label) {
        java.util.ArrayList<String> candidates = new java.util.ArrayList<>();
        if (label == null) return candidates;
        String cleaned = label.trim();
        if (cleaned.isEmpty() || cleaned.startsWith("位置 ")) return candidates;

        String[] parts = cleaned.split("\\s+");
        for (int i = parts.length - 1; i >= 0; i--) {
            addCityCandidate(candidates, parts[i]);
        }
        addCityCandidate(candidates, cleaned);
        return candidates;
    }

    private void addCityCandidate(List<String> candidates, String value) {
        if (value == null) return;
        String candidate = value
            .replace("特别行政区", "")
            .replace("市辖区", "")
            .trim();
        if (!candidate.isEmpty() && !candidates.contains(candidate)) {
            candidates.add(candidate);
        }
    }

    private int windPowerToKmh(String windPower) {
        if (windPower == null || windPower.trim().isEmpty()) return 0;
        String text = windPower.trim();
        if (text.contains("微风")) return 5;

        int firstDigit = -1;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c >= '0' && c <= '9') {
                firstDigit = c - '0';
                break;
            }
        }
        if (firstDigit < 0) return 0;
        return Math.max(0, Math.round(firstDigit * 6.5f));
    }

    private int normalizeWeatherText(String text) {
        if (text == null) return 3;
        if (text.contains("雷")) return 95;
        if (text.contains("雪")) return 71;
        if (text.contains("雨")) return 61;
        if (text.contains("雾") || text.contains("霾")) return 45;
        if (text.contains("晴")) return 0;
        if (text.contains("云")) return 2;
        if (text.contains("阴")) return 3;
        return 3;
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
