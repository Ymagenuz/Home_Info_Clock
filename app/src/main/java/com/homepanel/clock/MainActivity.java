package com.homepanel.clock;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONException;
import org.json.JSONObject;

public class MainActivity extends Activity {
    private static final int LOCATION_REQUEST_CODE = 1001;

    private WebView webView;
    private LocationManager locationManager;
    private Location lastLocation;

    private final LocationListener locationListener = location -> lastLocation = location;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        enterImmersiveMode();

        locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        setupWebView();
        requestLocationIfNeeded();
        webView.loadUrl("file:///android_asset/clock.html");
    }

    @Override
    protected void onResume() {
        super.onResume();
        enterImmersiveMode();
        startLocationUpdates();
    }

    @Override
    protected void onPause() {
        super.onPause();
        stopLocationUpdates();
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
        }
    }

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    private void setupWebView() {
        webView = new WebView(this);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setGeolocationEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMediaPlaybackRequiresUserGesture(false);

        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                callback.invoke(origin, true, false);
            }
        });
        webView.addJavascriptInterface(new NativeBridge(), "HomePanelNative");
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
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            startLocationUpdates();
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
        if (locationManager == null || !hasLocationPermission()) return;

        lastLocation = bestLastKnownLocation();

        try {
            locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 30_000L, 5f, locationListener);
        } catch (IllegalArgumentException ignored) {
        }

        try {
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 30_000L, 5f, locationListener);
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
        if (locationManager == null) return null;
        if (!hasLocationPermission()) return null;

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
        return best;
    }

    private String jsonError(String message) {
        try {
            JSONObject object = new JSONObject();
            object.put("ok", false);
            object.put("error", message);
            return object.toString();
        } catch (JSONException ignored) {
            return "{\"ok\":false}";
        }
    }

    public class NativeBridge {
        @JavascriptInterface
        public String getLocation() {
            Location location = lastLocation != null ? lastLocation : bestLastKnownLocation();
            if (location == null) {
                return jsonError("location unavailable");
            }

            try {
                JSONObject object = new JSONObject();
                object.put("ok", true);
                object.put("latitude", location.getLatitude());
                object.put("longitude", location.getLongitude());
                object.put("accuracy", location.getAccuracy());
                object.put("provider", location.getProvider());
                object.put("source", "android");
                return object.toString();
            } catch (JSONException ignored) {
                return jsonError("location json failed");
            }
        }

        @JavascriptInterface
        public String getBattery() {
            Intent status = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (status == null) {
                return jsonError("battery unavailable");
            }

            int level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
            int plugged = status.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0);
            int percent = scale > 0 && level >= 0 ? Math.round(level * 100f / scale) : -1;

            try {
                JSONObject object = new JSONObject();
                object.put("ok", percent >= 0);
                object.put("level", percent);
                object.put("charging", plugged != 0);
                return object.toString();
            } catch (JSONException ignored) {
                return jsonError("battery json failed");
            }
        }

        @JavascriptInterface
        public boolean openApp(String packageName) {
            if (packageName == null || packageName.trim().isEmpty()) return false;

            Intent intent = getPackageManager().getLaunchIntentForPackage(packageName.trim());
            if (intent == null) return false;

            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                return true;
            } catch (Exception ignored) {
                return false;
            }
        }

        @JavascriptInterface
        public boolean openUrl(String url) {
            if (url == null || url.trim().isEmpty()) return false;

            try {
                Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url.trim()));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                return true;
            } catch (Exception ignored) {
                return false;
            }
        }

        @JavascriptInterface
        public boolean openIntent(String uri) {
            if (uri == null || uri.trim().isEmpty()) return false;

            try {
                Intent intent = Intent.parseUri(uri.trim(), Intent.URI_INTENT_SCHEME);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                return true;
            } catch (Exception ignored) {
                return false;
            }
        }

        @JavascriptInterface
        public void openLocationSettings() {
            Intent intent = new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        }
    }
}
