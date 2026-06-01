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
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.View;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

public class HomePanelView extends View {
    private static final int PAGE_RESET_MS = 20_000;
    private static final int LOW_BATTERY_PERCENT = 20;
    private static final long BATTERY_TRANSITION_MS = 900L;

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
    private long batteryTransitionStartedAt = -BATTERY_TRANSITION_MS;
    private int rightPage;
    private float touchDownX;
    private float touchDownY;
    private boolean rightTouchActive;
    private float rightPanelStartX;
    private float rightPanelEndX;

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

    private final Runnable batteryAnimationTicker = new Runnable() {
        @Override
        public void run() {
            long elapsed = SystemClock.uptimeMillis() - batteryTransitionStartedAt;
            if (elapsed < BATTERY_TRANSITION_MS) {
                invalidate();
                postDelayed(this, 16L);
            }
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
        boolean chargingChanged = batteryLevel >= 0 && batteryCharging != charging;
        this.batteryLevel = level;
        this.batteryCharging = charging;
        if (chargingChanged) {
            batteryTransitionStartedAt = SystemClock.uptimeMillis();
            removeCallbacks(batteryAnimationTicker);
            post(batteryAnimationTicker);
        }
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
        removeCallbacks(batteryAnimationTicker);
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
        rightPanelStartX = rightX;
        rightPanelEndX = width - outer;

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
            rightTouchActive = isInRightPanel(touchDownX);
            return rightTouchActive;
        }

        if (event.getAction() == MotionEvent.ACTION_UP) {
            if (!rightTouchActive || !isInRightPanel(touchDownX)) return false;
            rightTouchActive = false;
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

    private boolean isInRightPanel(float x) {
        float width = getWidth();
        float outer = dp(10);
        float leftW = clamp(width * 0.27f, dp(210), width * 0.33f);
        float rightW = clamp(width * 0.31f, dp(225), width * 0.34f);
        float centerW = width - leftW - rightW - outer * 2f;

        if (centerW < dp(270)) {
            leftW = width * 0.28f;
            rightW = width * 0.30f;
            centerW = width - leftW - rightW - outer * 2f;
        }

        float rightStart = outer + leftW + centerW;
        float rightEnd = width - outer;
        return x >= rightStart && x <= rightEnd;
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
        drawFittedText(canvas, title, x + pad, titleY, label, Color.argb(190, 224, 242, 235), Paint.Align.LEFT, true, w - pad * 2f);

        String updated = weather != null
            ? "更新 " + updateFormat.format(weather.updatedAtMillis) + " · 30分钟刷新"
            : locationPermissionMissing ? "需要定位权限" : weatherStatus;
        if (weather != null && weather.sourceLabel != null && !weather.sourceLabel.isEmpty()) {
            updated = updated + " · " + weather.sourceLabel;
        }
        drawFittedText(canvas, updated, x + pad, titleY + dp(24), small, Color.argb(178, 224, 242, 235), Paint.Align.LEFT, true, w - pad * 2f);

        if (weather == null) {
            drawEmptyWeather(canvas, x, y, w, h);
            drawBattery(canvas, x + pad, y + h - dp(54), w - pad * 2f);
            return;
        }

        String icon = weatherIcon(weather.currentCode);
        drawCircleBadge(canvas, x + pad + dp(25), y + dp(92), dp(28), icon, dp(24));
        drawFittedText(canvas, weather.currentDescription,
            x + pad + dp(25),
            y + dp(142),
            scaleText(h, 16, 22),
            Color.WHITE,
            Paint.Align.CENTER,
            true,
            dp(82)
        );

        WeatherDay today = weather.days.isEmpty() ? null : weather.days.get(0);
        float textX = x + pad + dp(72);
        float textW = x + w - pad - textX;
        String highLow = today != null ? "最高 " + today.high + "°  最低 " + today.low + "°" : "最高 --°  最低 --°";
        drawText(canvas, weather.currentTemp + "°", textX, y + dp(98), scaleText(h, 48, 66), Color.rgb(238, 250, 246), Paint.Align.LEFT, true);
        drawFittedText(canvas, highLow, textX, y + dp(134), small, Color.argb(205, 238, 250, 246), Paint.Align.LEFT, true, textW);
        drawFittedText(canvas, "湿度 " + weather.humidity + "% · 风力 " + weather.windKmh + " km/h",
            textX,
            y + dp(158),
            small,
            Color.argb(185, 224, 242, 235),
            Paint.Align.LEFT,
            false,
            textW
        );

        if (weather.days.size() > 1) {
            drawTrend(canvas, x + pad, y + dp(186), w - pad * 2f, y + h - dp(95));
        } else {
            drawRealtimeStatus(canvas, x + pad, y + dp(214), w - pad * 2f);
        }
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

    private void drawTrend(Canvas canvas, float x, float y, float w, float maxY) {
        if (weather == null || weather.days.isEmpty()) return;

        int startIndex = weather.days.size() > 3 ? 1 : 0;
        int count = Math.min(3, weather.days.size() - startIndex);
        if (count <= 0) return;

        float available = Math.max(1f, maxY - y);
        float rowH = available / count;
        int minTemp = Integer.MAX_VALUE;
        int maxTemp = Integer.MIN_VALUE;
        for (int i = 0; i < count; i++) {
            WeatherDay day = weather.days.get(startIndex + i);
            minTemp = Math.min(minTemp, day.low);
            maxTemp = Math.max(maxTemp, day.high);
        }
        if (minTemp == Integer.MAX_VALUE || minTemp == maxTemp) {
            minTemp -= 1;
            maxTemp += 1;
        }

        Calendar calendar = Calendar.getInstance(Locale.CHINA);
        calendar.add(Calendar.DAY_OF_YEAR, startIndex);
        for (int i = 0; i < count; i++) {
            WeatherDay day = weather.days.get(startIndex + i);
            String label = startIndex == 1 && i == 0 ? "明天" : new SimpleDateFormat("E", Locale.CHINA).format(calendar.getTime());
            float rowY = y + i * rowH;
            float baseline = rowY + rowH * 0.62f;
            float barY = rowY + rowH * 0.50f;

            drawText(canvas, label, x, baseline, dp(12), Color.argb(190, 224, 242, 235), Paint.Align.LEFT, false);
            drawText(canvas, day.icon, x + dp(44), baseline, dp(12), Color.argb(210, 224, 242, 235), Paint.Align.CENTER, false);

            float lowX = x + w * 0.40f;
            float highX = x + w;
            float barStart = x + w * 0.50f;
            float barEnd = x + w * 0.82f;
            float lowPos = map(day.low, minTemp, maxTemp, barStart, barEnd);
            float highPos = map(day.high, minTemp, maxTemp, barStart, barEnd);
            drawTemperatureBar(canvas, barStart, barEnd, lowPos, highPos, barY);

            drawText(canvas, day.low + "°", lowX, baseline, dp(12), Color.rgb(224, 242, 235), Paint.Align.RIGHT, true);
            drawText(canvas, day.high + "°", highX, baseline, dp(12), Color.rgb(224, 242, 235), Paint.Align.RIGHT, true);

            calendar.add(Calendar.DAY_OF_YEAR, 1);
        }
    }

    private void drawRealtimeStatus(Canvas canvas, float x, float y, float w) {
        rect.set(x, y, x + w, y + dp(50));
        paint.setColor(Color.argb(18, 255, 255, 255));
        canvas.drawRoundRect(rect, dp(7), dp(7), paint);
        drawText(canvas, "UAPI 实时天气", x + dp(12), y + dp(20), dp(13), Color.rgb(224, 242, 235), Paint.Align.LEFT, true);
        String report = weather != null && weather.reportTimeLabel != null && !weather.reportTimeLabel.isEmpty()
            ? "数据时间 " + weather.reportTimeLabel
            : "趋势页暂以实时信息为准";
        drawText(canvas, report, x + dp(12), y + dp(40), dp(12), Color.argb(178, 224, 242, 235), Paint.Align.LEFT, false);
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

        boolean lowBattery = !batteryCharging && batteryLevel <= LOW_BATTERY_PERCENT;
        String right = batteryCharging ? "充电中" : "未充电";
        drawText(canvas, "电量 " + batteryLevel + "%", x, y, dp(12), Color.argb(188, 224, 242, 235), Paint.Align.LEFT, false);
        int statusColor = batteryCharging
            ? Color.rgb(135, 235, 155)
            : lowBattery ? Color.rgb(255, 174, 92) : Color.rgb(172, 190, 255);
        drawText(canvas, right, x + w, y, dp(12), statusColor, Paint.Align.RIGHT, false);

        float barY = y + dp(17);
        float barStart = x + dp(4);
        float barEnd = x + w - dp(4);
        float fillEnd = barStart + (barEnd - barStart) * Math.max(0, Math.min(100, batteryLevel)) / 100f;
        int trackColor = batteryCharging
            ? Color.argb(58, 120, 245, 145)
            : lowBattery ? Color.argb(62, 255, 145, 80) : Color.argb(56, 150, 170, 255);
        int start = batteryCharging
            ? Color.rgb(79, 224, 120)
            : lowBattery ? Color.rgb(255, 164, 70) : Color.rgb(103, 132, 255);
        int end = batteryCharging
            ? Color.rgb(174, 246, 115)
            : lowBattery ? Color.rgb(255, 94, 72) : Color.rgb(176, 204, 255);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);

        float transitionPulse = batteryTransitionPulse();
        if (transitionPulse > 0f) {
            paint.setStrokeWidth(dp(10) + dp(8) * transitionPulse);
            paint.setColor(Color.argb(Math.round(96 * transitionPulse), Color.red(statusColor), Color.green(statusColor), Color.blue(statusColor)));
            canvas.drawLine(barStart, barY, fillEnd, barY, paint);
        }

        paint.setStrokeWidth(dp(8));
        paint.setColor(trackColor);
        canvas.drawLine(barStart, barY, barEnd, barY, paint);
        paint.setShader(new LinearGradient(x, barY, x + w, barY, start, end, Shader.TileMode.CLAMP));
        canvas.drawLine(barStart, barY, fillEnd, barY, paint);
        paint.setShader(null);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private float batteryTransitionPulse() {
        long elapsed = SystemClock.uptimeMillis() - batteryTransitionStartedAt;
        if (elapsed < 0L || elapsed >= BATTERY_TRANSITION_MS) return 0f;
        float progress = elapsed / (float) BATTERY_TRANSITION_MS;
        return (float) Math.sin(progress * Math.PI);
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
        drawText(canvas, "明日天气", x + pad, y + dp(23), dp(14), Color.argb(190, 224, 242, 235), Paint.Align.LEFT, true);
        drawPageDots(canvas, x + w - pad - dp(18), y + dp(21), dp(3.2f), dp(12));

        if (rightPage == 0) {
            drawTomorrowCard(canvas, x + pad, y + dp(42), w - pad * 2f, h - dp(128));
        } else {
            drawReservedPage(canvas, x + pad, y + dp(52), w - pad * 2f, h - dp(130), rightPage + 1);
        }
    }

    private void drawTomorrowCard(Canvas canvas, float x, float y, float w, float h) {
        WeatherDay tomorrow = weather != null && weather.days.size() > 1 ? weather.days.get(1) : null;

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

        float gridY = y + dp(62);
        float gap = dp(8);
        float cellW = (w - gap) / 2f;
        float cellH = dp(46);
        drawMetricCell(canvas, x, gridY, cellW, cellH, "降水", tomorrow.precipitation + "%");
        drawMetricCell(canvas, x + cellW + gap, gridY, cellW, cellH, "紫外线", tomorrow.uv + " " + uvLevel(tomorrow.uv));
        drawMetricCell(canvas, x, gridY + dp(53), cellW, cellH, "风速", tomorrow.windKmh + " km/h");
        drawMetricCell(canvas, x + cellW + gap, gridY + dp(53), cellW, cellH, "温差", Math.abs(tomorrow.high - tomorrow.low) + "°");

        List<String[]> tips = buildTips(tomorrow);
        float tipY = gridY + dp(122);
        for (int i = 0; i < tips.size(); i++) {
            drawTip(canvas, x + dp(10), tipY + i * dp(27), w - dp(20), tips.get(i)[0], tips.get(i)[1]);
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
        canvas.drawCircle(x + dp(10), y + dp(8), dp(9), paint);
        drawText(canvas, icon, x + dp(10), y + dp(12), dp(11), Color.rgb(255, 205, 94), Paint.Align.CENTER, true);
        drawFittedText(canvas, text, x + dp(26), y + dp(12), dp(11), Color.WHITE, Paint.Align.LEFT, true, w - dp(26));
    }

    private void drawReservedPage(Canvas canvas, float x, float y, float w, float h, int page) {
        drawText(canvas, "第 " + page + " 页", x + w * 0.5f, y + h * 0.42f, dp(26), Color.WHITE, Paint.Align.CENTER, true);
        drawText(canvas, "后续可放日程、快捷 App 或家庭信息", x + w * 0.5f, y + h * 0.42f + dp(34), dp(13), Color.argb(175, 224, 242, 235), Paint.Align.CENTER, false);
    }

    private void drawPageDots(Canvas canvas, float cx, float cy, float radius, float gap) {
        for (int i = 0; i < 3; i++) {
            paint.setColor(i == rightPage ? Color.rgb(100, 220, 205) : Color.argb(95, 255, 255, 255));
            canvas.drawCircle(cx + (i - 1) * gap, cy, i == rightPage ? radius * 1.2f : radius, paint);
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

    private void drawFittedText(Canvas canvas, String text, float x, float y, float size, int color, Paint.Align align, boolean bold, float maxWidth) {
        String value = text == null ? "" : text;
        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(color);
        paint.setTextAlign(align);
        paint.setFakeBoldText(bold);

        float textSize = size;
        float minSize = dp(9);
        paint.setTextSize(textSize);
        while (textSize > minSize && paint.measureText(value) > maxWidth) {
            textSize -= dp(0.5f);
            paint.setTextSize(textSize);
        }

        if (paint.measureText(value) > maxWidth) {
            value = ellipsize(value, maxWidth);
        }

        canvas.drawText(value, x, y, paint);
        paint.setFakeBoldText(false);
    }

    private String ellipsize(String text, float maxWidth) {
        if (text == null || text.isEmpty()) return "";
        String value = text;
        while (value.length() > 1 && paint.measureText(value + "...") > maxWidth) {
            value = value.substring(0, value.length() - 1);
        }
        return value.length() < text.length() ? value + "..." : value;
    }

    private List<String[]> buildTips(WeatherDay day) {
        ArrayList<String[]> tips = new ArrayList<>();
        String clothing = firstNonEmpty(day.clothingTip, fallbackClothingTip(day));
        String umbrella = firstNonEmpty(day.umbrellaTip, day.precipitation >= 50 ? "降水概率较高，建议带伞。" : day.precipitation >= 20 ? "可能有雨，随身备伞更稳妥。" : "降水概率不高，可轻装出行。");
        String travel = firstNonEmpty(day.travelTip, day.sportTip, day.sunProtectionTip, fallbackTravelTip(day));
        tips.add(new String[] { "衣", clothing });
        tips.add(new String[] { "伞", umbrella });
        tips.add(new String[] { "行", travel });
        return tips;
    }

    private String fallbackClothingTip(WeatherDay day) {
        return day.low <= 12 ? "偏凉，建议加外套。" : day.low <= 20 ? "早晚偏凉，建议加一件薄外套。" : "温度舒适，轻薄衣物即可。";
    }

    private String fallbackTravelTip(WeatherDay day) {
        return day.uv >= 8 ? "紫外线较强，注意防晒。" : day.windKmh >= 30 ? "风力偏大，出行留意阵风。" : "天气总体平稳，适合出行。";
    }

    private String firstNonEmpty(String... values) {
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) return value.trim();
        }
        return null;
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
        public String sourceLabel = "";
        public String reportTimeLabel = "";
        public boolean forecastAvailable = true;
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
        public String windDirection;
        public String clothingTip;
        public String umbrellaTip;
        public String sportTip;
        public String travelTip;
        public String sunProtectionTip;
    }
}
