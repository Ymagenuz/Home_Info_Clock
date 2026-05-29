package com.homepanel.clock;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.location.Location;
import android.view.MotionEvent;
import android.view.View;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

public class HomePanelView extends View {
    private static final int PAGE_RESET_MS = 20_000;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy年M月d日 EEEE", Locale.CHINA);
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm", Locale.CHINA);
    private final SimpleDateFormat updateFormat = new SimpleDateFormat("HH:mm", Locale.CHINA);
    private final float density;

    private WeatherSnapshot weather;
    private Location location;
    private String locationLabel;
    private String weatherStatus = "等待定位";
    private boolean locationPermissionMissing;
    private int batteryLevel = -1;
    private boolean batteryCharging;
    private int rightPage;
    private float touchDownX;
    private float touchDownY;

    private final Runnable ticker = new Runnable() {
        @Override
        public void run() {
            invalidate();
            postDelayed(this, 1_000L);
        }
    };

    private final Runnable resetRightPage = new Runnable() {
        @Override
        public void run() {
            rightPage = 0;
            invalidate();
        }
    };

    public HomePanelView(Context context) {
        super(context);
        density = getResources().getDisplayMetrics().density;
        setFocusable(true);
    }

    public void setLocation(Location location, boolean permissionMissing) {
        this.location = location;
        this.locationPermissionMissing = permissionMissing;
        if (location != null && (locationLabel == null || locationLabel.isEmpty())) {
            this.locationLabel = String.format(Locale.US, "位置 %.4f, %.4f", location.getLatitude(), location.getLongitude());
        }
        invalidate();
    }

    public void setLocationLabel(String label) {
        if (label != null && !label.trim().isEmpty()) {
            this.locationLabel = label.trim();
        }
        invalidate();
    }

    public void setWeather(WeatherSnapshot weather) {
        this.weather = weather;
        this.weatherStatus = "";
        invalidate();
    }

    public void setWeatherStatus(String status) {
        this.weatherStatus = status == null ? "" : status;
        invalidate();
    }

    public void setBattery(int level, boolean charging) {
        this.batteryLevel = level;
        this.batteryCharging = charging;
        invalidate();
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        removeCallbacks(ticker);
        post(ticker);
    }

    @Override
    protected void onDetachedFromWindow() {
        removeCallbacks(ticker);
        removeCallbacks(resetRightPage);
        super.onDetachedFromWindow();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        drawBackground(canvas);

        float width = getWidth();
        float height = getHeight();
        float outer = dp(10);
        float leftW = clamp(width * 0.27f, dp(210), width * 0.33f);
        float rightW = clamp(width * 0.31f, dp(225), width * 0.34f);
        float centerW = width - leftW - rightW - outer * 2f;

        if (centerW < dp(270)) {
            leftW = width * 0.28f;
            rightW = width * 0.30f;
            centerW = width - leftW - rightW - outer * 2f;
        }

        float leftX = outer;
        float centerX = leftX + leftW;
        float rightX = centerX + centerW;
        float top = outer;
        float bottom = height - outer;

        drawSeparator(canvas, centerX, top, bottom);
        drawSeparator(canvas, rightX, top, bottom);

        drawWeatherPanel(canvas, leftX, top, leftW, bottom - top);
        drawClockPanel(canvas, centerX, top, centerW, bottom - top);
        drawRightPanel(canvas, rightX, top, width - rightX - outer, bottom - top);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            touchDownX = event.getX();
            touchDownY = event.getY();
            return true;
        }

        if (event.getAction() == MotionEvent.ACTION_UP) {
            float dx = event.getX() - touchDownX;
            float dy = event.getY() - touchDownY;
            if (Math.abs(dx) > dp(36) && Math.abs(dx) > Math.abs(dy)) {
                if (dx < 0) {
                    rightPage = Math.min(2, rightPage + 1);
                } else {
                    rightPage = Math.max(0, rightPage - 1);
                }
                removeCallbacks(resetRightPage);
                postDelayed(resetRightPage, PAGE_RESET_MS);
                invalidate();
            }
            return true;
        }

        return true;
    }

    private void drawBackground(Canvas canvas) {
        paint.setShader(new LinearGradient(
            0,
            0,
            getWidth(),
            getHeight(),
            new int[] { Color.rgb(10, 29, 29), Color.rgb(24, 35, 35), Color.rgb(41, 35, 27) },
            new float[] { 0f, 0.57f, 1f },
            Shader.TileMode.CLAMP
        ));
        canvas.drawRect(0, 0, getWidth(), getHeight(), paint);
        paint.setShader(new RadialGradient(
            getWidth() * 0.52f,
            getHeight() * 0.48f,
            Math.max(getWidth(), getHeight()) * 0.55f,
            Color.argb(44, 120, 230, 210),
            Color.TRANSPARENT,
            Shader.TileMode.CLAMP
        ));
        canvas.drawRect(0, 0, getWidth(), getHeight(), paint);
        paint.setShader(null);
    }

    private void drawSeparator(Canvas canvas, float x, float top, float bottom) {
        paint.setShader(new LinearGradient(
            x,
            top,
            x,
            bottom,
            Color.argb(18, 255, 255, 255),
            Color.argb(58, 255, 255, 255),
            Shader.TileMode.CLAMP
        ));
        paint.setStrokeWidth(dp(1));
        canvas.drawLine(x, top, x, bottom, paint);
        paint.setShader(null);
    }

    private void drawWeatherPanel(Canvas canvas, float x, float y, float w, float h) {
        float pad = dp(18);
        float small = scaleText(h, 12, 14);
        float label = scaleText(h, 13, 16);
        float titleY = y + dp(23);

        String title = weather != null && weather.locationLabel != null && !weather.locationLabel.isEmpty()
            ? weather.locationLabel
            : locationLabel != null && !locationLabel.isEmpty() ? locationLabel
            : location != null ? "定位完成，更新天气中" : "当前位置天气";
        drawText(canvas, title, x + pad, titleY, label, Color.argb(190, 224, 242, 235), Paint.Align.LEFT, true);

        String updated = weather != null
            ? "更新 " + updateFormat.format(weather.updatedAtMillis) + " · 15分钟刷新"
            : locationPermissionMissing ? "需要定位权限" : weatherStatus;
        drawText(canvas, updated, x + pad, titleY + dp(24), small, Color.argb(178, 224, 242, 235), Paint.Align.LEFT, true);

        if (weather == null) {
            drawEmptyWeather(canvas, x, y, w, h);
            drawBattery(canvas, x + pad, y + h - dp(54), w - pad * 2f);
            return;
        }

        String icon = weatherIcon(weather.currentCode);
        drawCircleBadge(canvas, x + pad + dp(25), y + dp(92), dp(28), icon, dp(24));

        drawText(canvas, weather.currentTemp + "°", x + pad + dp(72), y + dp(98), scaleText(h, 48, 66), Color.rgb(238, 250, 246), Paint.Align.LEFT, true);
        drawText(canvas, weather.currentDescription, x + pad + dp(72), y + dp(126), scaleText(h, 18, 25), Color.WHITE, Paint.Align.LEFT, true);
        drawText(canvas, "湿度 " + weather.humidity + "%   风 " + weather.windKmh + " km/h",
            x + pad + dp(72),
            y + dp(150),
            small,
            Color.argb(185, 224, 242, 235),
            Paint.Align.LEFT,
            false
        );

        WeatherDay today = weather.days.isEmpty() ? null : weather.days.get(0);
        if (today != null) {
            drawTodaySummary(canvas, x + pad, y + dp(166), w - pad * 2f, dp(54), today);
        }

        drawTrend(canvas, x + pad, y + dp(232), w - pad * 2f, y + h - dp(72));
        drawBattery(canvas, x + pad, y + h - dp(54), w - pad * 2f);
    }

    private void drawEmptyWeather(Canvas canvas, float x, float y, float w, float h) {
        float cx = x + w * 0.5f;
        float cy = y + h * 0.46f;
        drawCircleBadge(canvas, cx, cy - dp(22), dp(34), "⌖", dp(26));
        String text = locationPermissionMissing ? "请授予定位权限" : weatherStatus;
        if (text == null || text.isEmpty()) text = "等待天气数据";
        drawText(canvas, text, cx, cy + dp(34), dp(18), Color.rgb(238, 250, 246), Paint.Align.CENTER, true);
    }

    private void drawTodaySummary(Canvas canvas, float x, float y, float w, float h, WeatherDay today) {
        rect.set(x, y, x + w, y + h);
        paint.setShader(new LinearGradient(x, y, x + w, y + h, Color.argb(26, 255, 255, 255), Color.argb(10, 255, 255, 255), Shader.TileMode.CLAMP));
        canvas.drawRoundRect(rect, dp(7), dp(7), paint);
        paint.setShader(null);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1));
        paint.setColor(Color.argb(34, 255, 255, 255));
        canvas.drawRoundRect(rect, dp(7), dp(7), paint);
        paint.setStyle(Paint.Style.FILL);

        drawText(canvas, today.icon, x + dp(18), y + dp(33), dp(22), Color.rgb(255, 205, 94), Paint.Align.CENTER, false);
        drawText(canvas, "今天", x + dp(40), y + dp(24), dp(17), Color.WHITE, Paint.Align.LEFT, true);
        drawText(canvas, today.description + " · 降水" + today.precipitation + "%", x + dp(40), y + dp(43), dp(12), Color.argb(185, 224, 242, 235), Paint.Align.LEFT, false);
        drawText(canvas, today.high + "°/" + today.low + "°", x + w - dp(8), y + dp(34), dp(21), Color.WHITE, Paint.Align.RIGHT, true);
    }

    private void drawTrend(Canvas canvas, float x, float y, float w, float maxY) {
        if (weather == null || weather.days.isEmpty()) return;

        int count = Math.min(3, weather.days.size());
        float available = Math.max(dp(78), maxY - y);
        float rowH = Math.min(dp(38), available / count);
        int minTemp = Integer.MAX_VALUE;
        int maxTemp = Integer.MIN_VALUE;
        for (WeatherDay day : weather.days) {
            minTemp = Math.min(minTemp, day.low);
            maxTemp = Math.max(maxTemp, day.high);
        }
        if (minTemp == Integer.MAX_VALUE || minTemp == maxTemp) {
            minTemp -= 1;
            maxTemp += 1;
        }

        Calendar calendar = Calendar.getInstance(Locale.CHINA);
        for (int i = 0; i < count; i++) {
            WeatherDay day = weather.days.get(i);
            String label = i == 0 ? "今天" : new SimpleDateFormat("E", Locale.CHINA).format(calendar.getTime());
            if (i == 0) label = "今天";
            float rowY = y + i * rowH;

            drawText(canvas, label, x, rowY + dp(13), dp(12), Color.argb(190, 224, 242, 235), Paint.Align.LEFT, false);
            drawText(canvas, day.icon, x + dp(48), rowY + dp(13), dp(12), Color.argb(210, 224, 242, 235), Paint.Align.CENTER, false);

            float barStart = x + w * 0.40f;
            float barEnd = x + w * 0.79f;
            float barY = rowY + dp(12);
            float lowPos = map(day.low, minTemp, maxTemp, barStart, barEnd);
            float highPos = map(day.high, minTemp, maxTemp, barStart, barEnd);
            drawTemperatureBar(canvas, barStart, barEnd, lowPos, highPos, barY);

            drawText(canvas, day.low + "°/" + day.high + "°", x + w, rowY + dp(13), dp(11), Color.rgb(224, 242, 235), Paint.Align.RIGHT, true);
            drawText(canvas, "💧 降水 " + day.precipitation + "%", (barStart + barEnd) * 0.5f, rowY + dp(29), dp(10), Color.rgb(98, 211, 245), Paint.Align.CENTER, true);

            calendar.add(Calendar.DAY_OF_YEAR, 1);
        }
    }

    private void drawTemperatureBar(Canvas canvas, float start, float end, float low, float high, float y) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(6));
        paint.setColor(Color.argb(55, 220, 235, 228));
        canvas.drawLine(start, y, end, y, paint);
        paint.setShader(new LinearGradient(low, y, high, y, Color.rgb(123, 217, 196), Color.rgb(245, 207, 101), Shader.TileMode.CLAMP));
        canvas.drawLine(low, y, high, y, paint);
        paint.setShader(null);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawBattery(Canvas canvas, float x, float y, float w) {
        if (batteryLevel < 0) return;

        String right = batteryCharging ? "充电中" : "未充电";
        drawText(canvas, "电量 " + batteryLevel + "%", x, y, dp(12), Color.argb(188, 224, 242, 235), Paint.Align.LEFT, false);
        drawText(canvas, right, x + w, y, dp(12), Color.argb(188, 224, 242, 235), Paint.Align.RIGHT, false);

        float barY = y + dp(17);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(8));
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(Color.argb(48, 255, 255, 255));
        canvas.drawLine(x + dp(4), barY, x + w - dp(4), barY, paint);
        int start = batteryCharging ? Color.rgb(130, 237, 168) : Color.rgb(95, 178, 255);
        int end = batteryCharging ? Color.rgb(238, 252, 116) : Color.rgb(80, 224, 206);
        float fillEnd = x + dp(4) + (w - dp(8)) * Math.max(0, Math.min(100, batteryLevel)) / 100f;
        paint.setShader(new LinearGradient(x, barY, x + w, barY, start, end, Shader.TileMode.CLAMP));
        canvas.drawLine(x + dp(4), barY, fillEnd, barY, paint);
        paint.setShader(null);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawClockPanel(Canvas canvas, float x, float y, float w, float h) {
        Calendar now = Calendar.getInstance(Locale.CHINA);
        float cx = x + w * 0.5f;
        float radius = Math.min(w * 0.34f, h * 0.34f);
        float cy = y + Math.max(radius + dp(18), h * 0.36f);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(6));
        paint.setColor(Color.rgb(224, 237, 233));
        canvas.drawCircle(cx, cy, radius, paint);

        paint.setStrokeWidth(dp(1));
        paint.setColor(Color.argb(38, 255, 255, 255));
        canvas.drawCircle(cx, cy, radius * 0.78f, paint);
        paint.setStyle(Paint.Style.FILL);

        for (int i = 1; i <= 12; i++) {
            double angle = Math.toRadians(i * 30 - 90);
            float tx = cx + (float) Math.cos(angle) * radius * 0.78f;
            float ty = cy + (float) Math.sin(angle) * radius * 0.78f + dp(5);
            drawText(canvas, String.valueOf(i), tx, ty, dp(17), Color.argb(235, 255, 255, 255), Paint.Align.CENTER, true);
        }

        int hour = now.get(Calendar.HOUR);
        int minute = now.get(Calendar.MINUTE);
        float minuteAngle = minute * 6f - 90f;
        float hourAngle = (hour + minute / 60f) * 30f - 90f;
        drawHand(canvas, cx, cy, hourAngle, radius * 0.47f, dp(7), Color.rgb(238, 248, 245));
        drawHand(canvas, cx, cy, minuteAngle, radius * 0.66f, dp(5), Color.rgb(99, 220, 205));

        paint.setColor(Color.rgb(245, 196, 82));
        canvas.drawCircle(cx, cy, dp(8), paint);
        paint.setColor(Color.WHITE);
        canvas.drawCircle(cx, cy, dp(4), paint);

        drawText(canvas, dateFormat.format(now.getTime()), cx, y + h - dp(88), dp(18), Color.argb(190, 224, 242, 235), Paint.Align.CENTER, true);
        drawText(canvas, timeFormat.format(now.getTime()), cx, y + h - dp(22), scaleText(h, 56, 74), Color.rgb(238, 250, 246), Paint.Align.CENTER, true);
    }

    private void drawHand(Canvas canvas, float cx, float cy, float angleDeg, float length, float stroke, int color) {
        double angle = Math.toRadians(angleDeg);
        float endX = cx + (float) Math.cos(angle) * length;
        float endY = cy + (float) Math.sin(angle) * length;
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(stroke);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(color);
        canvas.drawLine(cx, cy, endX, endY, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawRightPanel(Canvas canvas, float x, float y, float w, float h) {
        float pad = dp(18);
        drawText(canvas, "预留板块", x + pad, y + dp(23), dp(14), Color.argb(190, 224, 242, 235), Paint.Align.LEFT, true);

        if (rightPage == 0) {
            drawTomorrowCard(canvas, x + pad, y + dp(54), w - pad * 2f, h - dp(96));
        } else {
            drawReservedPage(canvas, x + pad, y + dp(66), w - pad * 2f, h - dp(114), rightPage + 1);
        }

        drawPageDots(canvas, x + w * 0.5f, y + h - dp(22));
    }

    private void drawTomorrowCard(Canvas canvas, float x, float y, float w, float h) {
        WeatherDay tomorrow = weather != null && weather.days.size() > 1 ? weather.days.get(1) : null;
        rect.set(x, y, x + w, y + h);
        paint.setShader(new LinearGradient(x, y, x + w, y + h, Color.argb(18, 255, 255, 255), Color.argb(8, 255, 255, 255), Shader.TileMode.CLAMP));
        canvas.drawRoundRect(rect, dp(7), dp(7), paint);
        paint.setShader(null);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1));
        paint.setColor(Color.argb(34, 255, 255, 255));
        canvas.drawRoundRect(rect, dp(7), dp(7), paint);
        paint.setStyle(Paint.Style.FILL);

        if (tomorrow == null) {
            drawText(canvas, weatherStatus == null || weatherStatus.isEmpty() ? "等待天气数据" : weatherStatus,
                x + w * 0.5f,
                y + h * 0.5f,
                dp(18),
                Color.rgb(238, 250, 246),
                Paint.Align.CENTER,
                true
            );
            return;
        }

        float headY = y + dp(38);
        drawText(canvas, tomorrow.icon, x + dp(28), headY, dp(29), Color.rgb(255, 205, 94), Paint.Align.CENTER, false);
        drawText(canvas, "明天", x + dp(58), headY - dp(4), dp(18), Color.WHITE, Paint.Align.LEFT, true);
        drawText(canvas, tomorrow.description, x + dp(58), headY + dp(16), dp(12), Color.argb(180, 224, 242, 235), Paint.Align.LEFT, false);
        drawText(canvas, tomorrow.high + "°/" + tomorrow.low + "°", x + w - dp(12), headY + dp(2), dp(22), Color.WHITE, Paint.Align.RIGHT, true);

        float gridY = y + dp(68);
        float gap = dp(8);
        float cellW = (w - gap) / 2f;
        drawMetricCell(canvas, x, gridY, cellW, dp(51), "降水", tomorrow.precipitation + "%");
        drawMetricCell(canvas, x + cellW + gap, gridY, cellW, dp(51), "紫外线", tomorrow.uv + " " + uvLevel(tomorrow.uv));
        drawMetricCell(canvas, x, gridY + dp(59), cellW, dp(51), "风速", tomorrow.windKmh + " km/h");
        drawMetricCell(canvas, x + cellW + gap, gridY + dp(59), cellW, dp(51), "温差", Math.abs(tomorrow.high - tomorrow.low) + "°");

        List<String[]> tips = buildTips(tomorrow);
        float tipY = gridY + dp(136);
        for (int i = 0; i < tips.size(); i++) {
            drawTip(canvas, x + dp(10), tipY + i * dp(33), w - dp(20), tips.get(i)[0], tips.get(i)[1]);
        }
    }

    private void drawMetricCell(Canvas canvas, float x, float y, float w, float h, String label, String value) {
        rect.set(x, y, x + w, y + h);
        paint.setColor(Color.argb(30, 255, 255, 255));
        canvas.drawRoundRect(rect, dp(6), dp(6), paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1));
        paint.setColor(Color.argb(34, 255, 255, 255));
        canvas.drawRoundRect(rect, dp(6), dp(6), paint);
        paint.setStyle(Paint.Style.FILL);
        drawText(canvas, label, x + dp(9), y + dp(18), dp(11), Color.argb(170, 224, 242, 235), Paint.Align.LEFT, false);
        drawText(canvas, value, x + dp(9), y + dp(39), dp(17), Color.WHITE, Paint.Align.LEFT, true);
    }

    private void drawTip(Canvas canvas, float x, float y, float w, String icon, String text) {
        paint.setColor(Color.argb(36, 255, 205, 94));
        canvas.drawCircle(x + dp(10), y + dp(8), dp(10), paint);
        drawText(canvas, icon, x + dp(10), y + dp(13), dp(12), Color.rgb(255, 205, 94), Paint.Align.CENTER, true);
        drawText(canvas, text, x + dp(26), y + dp(13), dp(12), Color.WHITE, Paint.Align.LEFT, true);
    }

    private void drawReservedPage(Canvas canvas, float x, float y, float w, float h, int page) {
        drawText(canvas, "第 " + page + " 页", x + w * 0.5f, y + h * 0.42f, dp(26), Color.WHITE, Paint.Align.CENTER, true);
        drawText(canvas, "后续可放日程、快捷 App 或家庭信息", x + w * 0.5f, y + h * 0.42f + dp(34), dp(13), Color.argb(175, 224, 242, 235), Paint.Align.CENTER, false);
    }

    private void drawPageDots(Canvas canvas, float cx, float cy) {
        float gap = dp(20);
        for (int i = 0; i < 3; i++) {
            paint.setColor(i == rightPage ? Color.rgb(100, 220, 205) : Color.argb(95, 255, 255, 255));
            canvas.drawCircle(cx + (i - 1) * gap, cy, i == rightPage ? dp(6) : dp(5), paint);
        }
    }

    private void drawCircleBadge(Canvas canvas, float cx, float cy, float radius, String text, float textSize) {
        paint.setShader(new RadialGradient(cx, cy, radius, Color.argb(42, 255, 255, 255), Color.argb(10, 255, 255, 255), Shader.TileMode.CLAMP));
        canvas.drawCircle(cx, cy, radius, paint);
        paint.setShader(null);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1));
        paint.setColor(Color.argb(44, 255, 255, 255));
        canvas.drawCircle(cx, cy, radius, paint);
        paint.setStyle(Paint.Style.FILL);
        drawText(canvas, text, cx, cy + textSize * 0.35f, textSize, Color.rgb(255, 205, 94), Paint.Align.CENTER, false);
    }

    private void drawText(Canvas canvas, String text, float x, float y, float size, int color, Paint.Align align, boolean bold) {
        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(color);
        paint.setTextSize(size);
        paint.setTextAlign(align);
        paint.setFakeBoldText(bold);
        canvas.drawText(text == null ? "" : text, x, y, paint);
        paint.setFakeBoldText(false);
    }

    private List<String[]> buildTips(WeatherDay day) {
        ArrayList<String[]> tips = new ArrayList<>();
        String clothing = day.low <= 12 ? "偏凉，建议加外套。" : day.low <= 20 ? "早晚偏凉，建议加一件薄外套。" : "温度舒适，轻薄衣物即可。";
        String umbrella = day.precipitation >= 50 ? "降水概率较高，建议带伞。" : day.precipitation >= 20 ? "可能有雨，随身备伞更稳妥。" : "降水概率不高，可轻装出行。";
        String travel = day.uv >= 8 ? "紫外线较强，注意防晒。" : day.windKmh >= 30 ? "风力偏大，出行留意阵风。" : "天气总体平稳，适合出行。";
        tips.add(new String[] { "衣", clothing });
        tips.add(new String[] { "伞", umbrella });
        tips.add(new String[] { "行", travel });
        return tips;
    }

    private String uvLevel(int uv) {
        if (uv >= 8) return "强";
        if (uv >= 6) return "较强";
        if (uv >= 3) return "中";
        return "低";
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

    private float map(float value, float inMin, float inMax, float outMin, float outMax) {
        float t = (value - inMin) / (inMax - inMin);
        t = Math.max(0f, Math.min(1f, t));
        return outMin + (outMax - outMin) * t;
    }

    private float scaleText(float height, float min, float max) {
        float t = (height - dp(320)) / dp(150);
        t = Math.max(0f, Math.min(1f, t));
        return dp(min + (max - min) * t);
    }

    private float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    private float dp(float value) {
        return value * density;
    }

    public static class WeatherSnapshot {
        public String locationLabel = "当前位置";
        public long updatedAtMillis;
        public int currentTemp;
        public int apparentTemp;
        public int humidity;
        public int windKmh;
        public int currentCode;
        public String currentDescription = "天气";
        public List<WeatherDay> days = new ArrayList<>();
    }

    public static class WeatherDay {
        public String date;
        public int code;
        public String description = "天气";
        public String icon = "•";
        public int high;
        public int low;
        public int precipitation;
        public int uv;
        public int windKmh;
    }
}
