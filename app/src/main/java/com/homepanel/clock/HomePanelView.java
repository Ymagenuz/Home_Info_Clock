package com.homepanel.clock;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
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
    private static final int RIGHT_PAGE_COUNT = 3;
    private static final long RIGHT_PAGE_ANIMATION_MS = 260L;
    private static final long CLOCK_FRAME_MS = 33L;
    private static final long SIMPLE_MODE_ANIMATION_MS = 320L;
    private static final boolean WEATHER_ICON_TEST_CYCLE = false;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final RectF bilibiliButtonRect = new RectF();
    private final SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy年M月d日 EEEE", Locale.CHINA);
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm", Locale.CHINA);
    private final SimpleDateFormat simpleDateFormat = new SimpleDateFormat("yyyy-MM-dd", Locale.US);
    private final SimpleDateFormat simpleWeekdayFormat = new SimpleDateFormat("EEE", Locale.US);
    private final SimpleDateFormat updateFormat = new SimpleDateFormat("HH:mm", Locale.CHINA);
    private final float density;

    private WeatherSnapshot weather;
    private Location location;
    private String locationLabel;
    private String weatherStatus = "等待定位";
    private boolean locationPermissionMissing;
    private int batteryLevel = -1;
    private boolean batteryCharging;
    private int previousBatteryLevel = -1;
    private boolean previousBatteryCharging;
    private long batteryTransitionStartedAt = -BATTERY_TRANSITION_MS;
    private int rightPage;
    private float touchDownX;
    private float touchDownY;
    private boolean rightTouchActive;
    private boolean rightDragging;
    private float rightDragOffsetPx;
    private float rightPanelStartX;
    private float rightPanelEndX;
    private float rightPageAnimationStart;
    private long rightPageAnimationStartedAt = -RIGHT_PAGE_ANIMATION_MS;
    private boolean simpleMode;
    private float simpleModeAnimationStart;
    private long simpleModeAnimationStartedAt = -SIMPLE_MODE_ANIMATION_MS;
    private ActionListener actionListener;
    private boolean compactWeatherIconStroke;

    private final Runnable ticker = new Runnable() {
        @Override
        public void run() {
            invalidate();
            postDelayed(this, CLOCK_FRAME_MS);
        }
    };

    private final Runnable resetRightPage = new Runnable() {
        @Override
        public void run() {
            setRightPage(0);
        }
    };

    private final Runnable rightPageAnimationTicker = new Runnable() {
        @Override
        public void run() {
            long elapsed = SystemClock.uptimeMillis() - rightPageAnimationStartedAt;
            if (elapsed < RIGHT_PAGE_ANIMATION_MS) {
                invalidate();
                postDelayed(this, 16L);
            }
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

    public void setActionListener(ActionListener listener) {
        this.actionListener = listener;
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
        boolean batteryChanged = batteryLevel >= 0 && (batteryLevel != level || batteryCharging != charging);
        if (batteryChanged) {
            previousBatteryLevel = batteryLevel;
            previousBatteryCharging = batteryCharging;
        }
        this.batteryLevel = level;
        this.batteryCharging = charging;
        if (batteryChanged) {
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
        removeCallbacks(rightPageAnimationTicker);
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

        drawModeTransition(canvas, width, height, leftX, centerX, rightX, top, bottom, leftW, centerW, outer);
    }

    private void drawModeTransition(Canvas canvas, float width, float height, float leftX, float centerX, float rightX, float top, float bottom, float leftW, float centerW, float outer) {
        long elapsed = SystemClock.uptimeMillis() - simpleModeAnimationStartedAt;
        if (elapsed < 0L || elapsed >= SIMPLE_MODE_ANIMATION_MS) {
            if (simpleMode) {
                drawSimpleMode(canvas, outer, top, width - outer * 2f, bottom - top);
            } else {
                drawFullMode(canvas, leftX, centerX, rightX, top, bottom, leftW, centerW, outer);
            }
            return;
        }

        float phase = elapsed / (float) SIMPLE_MODE_ANIMATION_MS;
        if (simpleMode) {
            if (phase < 0.5f) {
                drawFullModeAlpha(canvas, width, height, leftX, centerX, rightX, top, bottom, leftW, centerW, outer, 1f - phase * 2f);
            } else {
                drawSimpleModeAlpha(canvas, width, height, outer, top, width - outer * 2f, bottom - top, (phase - 0.5f) * 2f);
            }
        } else {
            if (phase < 0.5f) {
                drawSimpleModeAlpha(canvas, width, height, outer, top, width - outer * 2f, bottom - top, 1f - phase * 2f);
            } else {
                drawFullModeAlpha(canvas, width, height, leftX, centerX, rightX, top, bottom, leftW, centerW, outer, (phase - 0.5f) * 2f);
            }
        }
    }

    private void drawFullModeAlpha(Canvas canvas, float width, float height, float leftX, float centerX, float rightX, float top, float bottom, float leftW, float centerW, float outer, float alpha) {
        int save = canvas.saveLayerAlpha(0, 0, width, height, Math.round(255f * Math.max(0f, Math.min(1f, alpha))));
        drawFullMode(canvas, leftX, centerX, rightX, top, bottom, leftW, centerW, outer);
        canvas.restoreToCount(save);
    }

    private void drawSimpleModeAlpha(Canvas canvas, float width, float height, float x, float y, float w, float h, float alpha) {
        int save = canvas.saveLayerAlpha(0, 0, width, height, Math.round(255f * Math.max(0f, Math.min(1f, alpha))));
        drawSimpleMode(canvas, x, y, w, h);
        canvas.restoreToCount(save);
    }

    private void drawFullMode(Canvas canvas, float leftX, float centerX, float rightX, float top, float bottom, float leftW, float centerW, float outer) {
        drawSeparator(canvas, centerX, top, bottom);
        drawSeparator(canvas, rightX, top, bottom);

        drawWeatherPanel(canvas, leftX, top, leftW, bottom - top);
        drawClockPanel(canvas, centerX, top, centerW, bottom - top);
        drawAnimatedRightPanel(canvas, rightX, top, getWidth() - rightX - outer, bottom - top);
    }

    private void drawSimpleMode(Canvas canvas, float x, float y, float w, float h) {
        float inset = Math.max(dp(34), w * 0.045f);
        float contentX = x + inset;
        float contentW = w - inset * 2f;
        float gap = dp(28);
        float leftW = contentW * 0.48f;
        float rightX = contentX + leftW + gap;
        float rightW = contentW - leftW - gap;

        drawSimpleClockPanel(canvas, contentX, y, leftW, h);
        drawSimpleTomorrowPanel(canvas, rightX, y, rightW, h);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            touchDownX = event.getX();
            touchDownY = event.getY();
            rightTouchActive = !simpleMode && isInRightPanel(touchDownX);
            rightDragging = false;
            rightDragOffsetPx = 0f;
            if (rightTouchActive) {
                removeCallbacks(rightPageAnimationTicker);
                rightPageAnimationStartedAt = -RIGHT_PAGE_ANIMATION_MS;
            }
            return true;
        }

        if (event.getAction() == MotionEvent.ACTION_MOVE) {
            float dx = event.getX() - touchDownX;
            float dy = event.getY() - touchDownY;
            if (!rightTouchActive) {
                return true;
            }
            if (!rightDragging && Math.abs(dx) > dp(8) && Math.abs(dx) > Math.abs(dy)) {
                rightDragging = true;
                removeCallbacks(resetRightPage);
            }
            if (rightDragging) {
                rightDragOffsetPx = resistedRightDrag(dx);
                invalidate();
            }
            return true;
        }

        if (event.getAction() == MotionEvent.ACTION_UP) {
            float dx = event.getX() - touchDownX;
            float dy = event.getY() - touchDownY;
            boolean tap = Math.abs(dx) < dp(12) && Math.abs(dy) < dp(12);
            if (rightTouchActive && (rightDragging || (Math.abs(dx) > dp(36) && Math.abs(dx) > Math.abs(dy)))) {
                settleRightDrag(dx);
                removeCallbacks(resetRightPage);
                postDelayed(resetRightPage, PAGE_RESET_MS);
            } else if (tap) {
                boolean handled = rightTouchActive && handleRightPanelTap(event.getX(), event.getY());
                if (!handled) {
                    toggleSimpleMode();
                }
            }
            rightTouchActive = false;
            rightDragging = false;
            rightDragOffsetPx = 0f;
            return true;
        }

        if (event.getAction() == MotionEvent.ACTION_CANCEL) {
            if (!rightTouchActive) return true;
            rightTouchActive = false;
            rightDragging = false;
            animateRightPageTo(rightPage, displayedRightPage());
            rightDragOffsetPx = 0f;
            return true;
        }

        return true;
    }

    private void toggleSimpleMode() {
        simpleModeAnimationStart = simpleModeProgress();
        simpleMode = !simpleMode;
        simpleModeAnimationStartedAt = SystemClock.uptimeMillis();
        rightDragging = false;
        rightDragOffsetPx = 0f;
        invalidate();
    }

    private float simpleModeProgress() {
        float target = simpleMode ? 1f : 0f;
        long elapsed = SystemClock.uptimeMillis() - simpleModeAnimationStartedAt;
        if (elapsed < 0L || elapsed >= SIMPLE_MODE_ANIMATION_MS) return target;

        float t = elapsed / (float) SIMPLE_MODE_ANIMATION_MS;
        float eased = 1f - (1f - t) * (1f - t) * (1f - t);
        return simpleModeAnimationStart + (target - simpleModeAnimationStart) * eased;
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

    private void setRightPage(int page) {
        int nextPage = Math.max(0, Math.min(RIGHT_PAGE_COUNT - 1, page));
        if (nextPage == rightPage) return;

        animateRightPageTo(nextPage, rightPage);
    }

    private void settleRightDrag(float dx) {
        float panelW = Math.max(1f, rightPanelEndX - rightPanelStartX);
        int targetPage = rightPage;
        if (Math.abs(dx) > panelW * 0.22f || Math.abs(dx) > dp(72)) {
            targetPage = dx < 0 ? rightPage + 1 : rightPage - 1;
        }
        targetPage = Math.max(0, Math.min(RIGHT_PAGE_COUNT - 1, targetPage));
        animateRightPageTo(targetPage, displayedRightPage());
    }

    private void animateRightPageTo(int nextPage, float fromPage) {
        if (Math.abs(fromPage - nextPage) < 0.001f) {
            rightPage = nextPage;
            rightDragOffsetPx = 0f;
            invalidate();
            return;
        }

        rightPageAnimationStart = fromPage;
        rightPage = nextPage;
        rightPageAnimationStartedAt = SystemClock.uptimeMillis();
        removeCallbacks(rightPageAnimationTicker);
        post(rightPageAnimationTicker);
        invalidate();
    }

    private boolean handleRightPanelTap(float x, float y) {
        if (rightPage == 1 && bilibiliButtonRect.contains(x, y) && actionListener != null) {
            actionListener.onOpenBilibili();
            return true;
        }
        return false;
    }

    private float displayedRightPage() {
        float panelW = Math.max(1f, rightPanelEndX - rightPanelStartX);
        return rightPage - rightDragOffsetPx / panelW;
    }

    private float resistedRightDrag(float dx) {
        if ((rightPage == 0 && dx > 0f) || (rightPage == RIGHT_PAGE_COUNT - 1 && dx < 0f)) {
            return dx * 0.28f;
        }
        return dx;
    }

    private void drawBackground(Canvas canvas) {
        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.BLACK);
        canvas.drawRect(0, 0, getWidth(), getHeight(), paint);
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

        drawCircleBadge(canvas, x + pad + dp(25), y + dp(92), dp(28), "", dp(24));
        drawCyclingColorWeatherIcon(canvas, x + pad + dp(25), y + dp(92), dp(46), weather.currentCode);
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
            drawCyclingColorWeatherIcon(canvas, x + dp(44), baseline - dp(4), dp(19), day.code, true);

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

    private void drawCompactBattery(Canvas canvas, float cx, float baseline) {
        if (batteryLevel < 0) return;

        float progress = batteryTransitionProgress();
        if (previousBatteryLevel >= 0 && progress < 0.5f) {
            drawCompactBatteryState(canvas, cx, baseline, previousBatteryLevel, previousBatteryCharging, 1f - progress * 2f);
            return;
        }
        if (previousBatteryLevel >= 0 && progress < 1f) {
            drawCompactBatteryState(canvas, cx, baseline, batteryLevel, batteryCharging, (progress - 0.5f) * 2f);
            return;
        }
        drawCompactBatteryState(canvas, cx, baseline, batteryLevel, batteryCharging, 1f);
    }

    private void drawCompactBatteryState(Canvas canvas, float cx, float baseline, int level, boolean charging, float alpha) {
        if (level < 0 || alpha <= 0f) return;

        boolean lowBattery = !charging && level <= LOW_BATTERY_PERCENT;
        int baseColor = charging
            ? Color.rgb(135, 235, 155)
            : lowBattery ? Color.rgb(255, 164, 70) : Color.rgb(248, 248, 250);
        int color = alphaColor(baseColor, Math.round((charging || lowBattery ? 230 : 205) * alpha));
        float iconW = dp(34);
        float iconH = dp(17);
        float textSize = dp(17);
        String percent = level + "%";
        paint.setTextSize(textSize);
        paint.setFakeBoldText(true);
        float textW = paint.measureText(percent);
        paint.setFakeBoldText(false);
        float lightningW = charging ? dp(18) : 0f;
        float totalW = iconW + dp(10) + textW + lightningW;
        float iconX = cx - totalW * 0.5f;
        float iconY = baseline - iconH;

        rect.set(iconX, iconY, iconX + iconW, iconY + iconH);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1.6f));
        paint.setColor(color);
        canvas.drawRoundRect(rect, dp(4), dp(4), paint);
        paint.setStyle(Paint.Style.FILL);
        rect.set(iconX + iconW + dp(2), iconY + dp(5), iconX + iconW + dp(5), iconY + iconH - dp(5));
        canvas.drawRoundRect(rect, dp(1.5f), dp(1.5f), paint);

        float fillW = (iconW - dp(7)) * Math.max(0, Math.min(100, level)) / 100f;
        rect.set(iconX + dp(3.5f), iconY + dp(3.5f), iconX + dp(3.5f) + fillW, iconY + iconH - dp(3.5f));
        paint.setColor(alphaColor(baseColor, Math.round((charging || lowBattery ? 170 : 120) * alpha)));
        canvas.drawRoundRect(rect, dp(2.5f), dp(2.5f), paint);

        float textX = iconX + iconW + dp(10);
        drawText(canvas, percent, textX, baseline, textSize, color, Paint.Align.LEFT, true);
        if (charging) {
            drawText(canvas, "⚡", textX + textW + dp(4), baseline, dp(16), color, Paint.Align.LEFT, true);
        }
    }

    private float batteryTransitionProgress() {
        long elapsed = SystemClock.uptimeMillis() - batteryTransitionStartedAt;
        if (elapsed < 0L || elapsed >= BATTERY_TRANSITION_MS) return 1f;
        float t = elapsed / (float) BATTERY_TRANSITION_MS;
        return 1f - (1f - t) * (1f - t);
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
        float radius = Math.min(w * 0.37f, h * 0.36f);
        float cy = y + Math.max(radius + dp(12), h * 0.36f);

        drawAnalogClock(canvas, cx, cy, radius);

        drawText(canvas, dateFormat.format(now.getTime()), cx, y + h - dp(88), dp(18), Color.argb(190, 224, 242, 235), Paint.Align.CENTER, true);
        drawText(canvas, timeFormat.format(now.getTime()), cx, y + h - dp(22), scaleText(h, 56, 74), Color.rgb(238, 250, 246), Paint.Align.CENTER, true);
    }

    private void drawSimpleClockPanel(Canvas canvas, float x, float y, float w, float h) {
        float cx = x + w * 0.5f;
        float batteryH = batteryLevel >= 0 ? dp(48) : 0f;
        float radius = Math.min(w * 0.42f, (h - batteryH - dp(28)) * 0.43f);
        float cy = y + (h - batteryH) * 0.5f;
        drawAnalogClock(canvas, cx, cy, radius);
        if (batteryLevel >= 0) {
            drawCompactBattery(canvas, cx, y + h - dp(28));
        }
    }

    private void drawSimpleTomorrowPanel(Canvas canvas, float x, float y, float w, float h) {
        WeatherDay tomorrow = weather != null && weather.days.size() > 1 ? weather.days.get(1) : null;
        float cx = x + w * 0.5f;
        Calendar now = Calendar.getInstance(Locale.US);
        float splitY = y + h * 0.55f;
        int digitalColor = Color.argb(226, 248, 248, 250);
        int weatherNumberColor = Color.argb(215, 248, 248, 250);
        float weatherNumberSize = dp(31);

        drawText(canvas, timeFormat.format(now.getTime()), cx, y + h * 0.39f, scaleText(h, 78, 104), digitalColor, Paint.Align.CENTER, true);
        String dateLine = simpleDateFormat.format(now.getTime()) + "  " + simpleWeekdayFormat.format(now.getTime()).toUpperCase(Locale.US);
        drawText(canvas, dateLine, cx, y + h * 0.48f, dp(19), Color.argb(175, 248, 248, 250), Paint.Align.CENTER, false);

        if (tomorrow == null) {
            drawText(canvas, weatherStatus == null || weatherStatus.isEmpty() ? "等待天气数据" : weatherStatus,
                cx,
                splitY + (y + h - splitY) * 0.5f,
                dp(22),
                Color.rgb(248, 248, 250),
                Paint.Align.CENTER,
                true
            );
            return;
        }

        float weatherCenterY = splitY + (y + h - splitY) * 0.27f;
        drawItalicText(canvas, "TOMORROW WEATHER", cx, weatherCenterY - dp(27), dp(11), Color.argb(78, 248, 248, 250), Paint.Align.CENTER, true);
        drawCyclingColorWeatherIcon(canvas, x + w * 0.16f, weatherCenterY, dp(46), tomorrow.code);
        drawCenteredText(canvas, tomorrow.high + "°", x + w * 0.35f, weatherCenterY, weatherNumberSize, weatherNumberColor, true);
        drawCenteredText(canvas, tomorrow.low + "°", x + w * 0.52f, weatherCenterY, weatherNumberSize, weatherNumberColor, true);
        drawSimpleRainIcon(canvas, x + w * 0.70f, weatherCenterY, dp(25), Color.argb(205, 248, 248, 250));
        drawCenteredText(canvas, tomorrow.precipitation + "%", x + w * 0.84f, weatherCenterY, weatherNumberSize, weatherNumberColor, true);
    }

    private void drawSimpleWeatherIcon(Canvas canvas, float cx, float cy, float size, int code) {
        if (code == 0) {
            drawSimpleSunIcon(canvas, cx, cy, size);
        } else if (code == 1) {
            drawSimplePartlyCloudyIcon(canvas, cx, cy, size);
        } else if (code == 2) {
            drawSimpleMostlyCloudyIcon(canvas, cx, cy, size);
        } else if (code >= 51 && code <= 67 || code >= 80 && code <= 82 || code >= 95 && code < 200) {
            if (code >= 95 && code < 200) {
                drawSimpleThunderIcon(canvas, cx, cy, size);
            } else {
                drawSimpleRainCloudIcon(canvas, cx, cy, size);
            }
        } else if (code >= 71 && code <= 77 || code >= 85 && code <= 86) {
            drawSimpleSnowIcon(canvas, cx, cy, size);
        } else if (code == 45 || code == 48) {
            drawSimpleFogIcon(canvas, cx, cy, size);
        } else if (code == 451) {
            drawSimpleHazeIcon(canvas, cx, cy, size);
        } else {
            drawSimpleCloudIcon(canvas, cx, cy, size);
        }
    }

    private void drawCyclingSimpleWeatherIcon(Canvas canvas, float cx, float cy, float size) {
        int[] codes = { 0, 1, 2, 3, 61, 95, 71, 45, 451 };
        long cycleMs = 2_200L;
        long now = SystemClock.uptimeMillis();
        int index = (int) ((now / cycleMs) % codes.length);
        int nextIndex = (index + 1) % codes.length;
        float t = (now % cycleMs) / (float) cycleMs;
        float fadeWindow = 0.28f;

        if (t > 1f - fadeWindow) {
            float fade = (t - (1f - fadeWindow)) / fadeWindow;
            int save = canvas.saveLayerAlpha(cx - size, cy - size, cx + size, cy + size, Math.round(255f * (1f - fade)));
            drawSimpleWeatherIcon(canvas, cx, cy, size, codes[index]);
            canvas.restoreToCount(save);

            save = canvas.saveLayerAlpha(cx - size, cy - size, cx + size, cy + size, Math.round(255f * fade));
            drawSimpleWeatherIcon(canvas, cx, cy, size, codes[nextIndex]);
            canvas.restoreToCount(save);
        } else {
            drawSimpleWeatherIcon(canvas, cx, cy, size, codes[index]);
        }
    }

    private void drawCyclingColorWeatherIcon(Canvas canvas, float cx, float cy, float size, int actualCode) {
        drawCyclingColorWeatherIcon(canvas, cx, cy, size, actualCode, false);
    }

    private void drawCyclingColorWeatherIcon(Canvas canvas, float cx, float cy, float size, int actualCode, boolean compactStroke) {
        int[] codes = { 0, 1, 2, 3, 61, 95, 71, 45, 451 };
        int[] accents = {
            Color.rgb(255, 197, 82),
            Color.rgb(255, 214, 112),
            Color.rgb(169, 214, 238),
            Color.rgb(206, 216, 226),
            Color.rgb(108, 214, 198),
            Color.rgb(255, 185, 82),
            Color.rgb(172, 212, 255),
            Color.rgb(190, 198, 205),
            Color.rgb(176, 186, 178)
        };

        if (!WEATHER_ICON_TEST_CYCLE) {
            compactWeatherIconStroke = compactStroke;
            drawColorWeatherIcon(canvas, cx, cy, size, actualCode, colorForWeatherCode(actualCode));
            compactWeatherIconStroke = false;
            return;
        }

        long cycleMs = 2_200L;
        long now = SystemClock.uptimeMillis();
        int index = (int) ((now / cycleMs) % codes.length);
        int nextIndex = (index + 1) % codes.length;
        float t = (now % cycleMs) / (float) cycleMs;
        float fadeWindow = 0.28f;

        if (t > 1f - fadeWindow) {
            float fade = (t - (1f - fadeWindow)) / fadeWindow;
            int save = canvas.saveLayerAlpha(cx - size, cy - size, cx + size, cy + size, Math.round(255f * (1f - fade)));
            compactWeatherIconStroke = compactStroke;
            drawColorWeatherIcon(canvas, cx, cy, size, codes[index], accents[index]);
            compactWeatherIconStroke = false;
            canvas.restoreToCount(save);

            save = canvas.saveLayerAlpha(cx - size, cy - size, cx + size, cy + size, Math.round(255f * fade));
            compactWeatherIconStroke = compactStroke;
            drawColorWeatherIcon(canvas, cx, cy, size, codes[nextIndex], accents[nextIndex]);
            compactWeatherIconStroke = false;
            canvas.restoreToCount(save);
        } else {
            compactWeatherIconStroke = compactStroke;
            drawColorWeatherIcon(canvas, cx, cy, size, codes[index], accents[index]);
            compactWeatherIconStroke = false;
        }
    }

    private int colorForWeatherCode(int code) {
        if (code == 0 || code == 1) return Color.rgb(255, 197, 82);
        if (code == 2) return Color.rgb(169, 214, 238);
        if (code >= 51 && code <= 67 || code >= 80 && code <= 82) return Color.rgb(108, 214, 198);
        if (code >= 95 && code < 200) return Color.rgb(255, 185, 82);
        if (code >= 71 && code <= 77 || code >= 85 && code <= 86) return Color.rgb(172, 212, 255);
        if (code == 45 || code == 48) return Color.rgb(190, 198, 205);
        if (code == 451) return Color.rgb(176, 186, 178);
        return Color.rgb(206, 216, 226);
    }

    private void drawColorWeatherIcon(Canvas canvas, float cx, float cy, float size, int code, int accent) {
        if (code == 0) {
            drawColorSunIcon(canvas, cx, cy, size, accent);
        } else if (code == 1) {
            drawColorPartlyCloudyIcon(canvas, cx, cy, size, accent);
        } else if (code == 2) {
            drawColorMostlyCloudyIcon(canvas, cx, cy, size, accent);
        } else if (code >= 95 && code < 200) {
            drawColorThunderIcon(canvas, cx, cy, size, accent);
        } else if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
            drawColorRainCloudIcon(canvas, cx, cy, size, accent);
        } else if (code >= 71 && code <= 77 || code >= 85 && code <= 86) {
            drawColorSnowIcon(canvas, cx, cy, size, accent);
        } else if (code == 45 || code == 48) {
            drawColorFogIcon(canvas, cx, cy, size, accent);
        } else if (code == 451) {
            drawColorHazeIcon(canvas, cx, cy, size, accent);
        } else {
            drawColorCloudIcon(canvas, cx, cy, size, accent);
        }
    }

    private void drawColorSunIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2.4f));
        paint.setColor(Color.argb(235, Color.red(accent), Color.green(accent), Color.blue(accent)));
        canvas.drawCircle(cx, cy, size * 0.18f, paint);
        for (int i = 0; i < 8; i++) {
            double angle = Math.toRadians(i * 45);
            canvas.drawLine(
                cx + (float) Math.cos(angle) * size * 0.29f,
                cy + (float) Math.sin(angle) * size * 0.29f,
                cx + (float) Math.cos(angle) * size * 0.43f,
                cy + (float) Math.sin(angle) * size * 0.43f,
                paint
            );
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawColorPartialSunIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2.4f));
        paint.setColor(Color.argb(235, Color.red(accent), Color.green(accent), Color.blue(accent)));
        canvas.drawCircle(cx, cy, size * 0.18f, paint);
        int[] rayAngles = { 180, 225, 270, 315 };
        for (int angleDeg : rayAngles) {
            double angle = Math.toRadians(angleDeg);
            canvas.drawLine(
                cx + (float) Math.cos(angle) * size * 0.29f,
                cy + (float) Math.sin(angle) * size * 0.29f,
                cx + (float) Math.cos(angle) * size * 0.43f,
                cy + (float) Math.sin(angle) * size * 0.43f,
                paint
            );
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawColorCloudIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        drawCloudShape(canvas, cx, cy, size, Color.argb(218, Color.red(accent), Color.green(accent), Color.blue(accent)), weatherIconStroke(2.7f));
    }

    private void drawColorPartlyCloudyIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        drawColorPartialSunIcon(canvas, cx - size * 0.18f, cy - size * 0.16f, size * 0.68f, accent);
        drawSimpleCloudMask(canvas, cx + size * 0.05f, cy + size * 0.05f, size * 0.90f);
        drawColorCloudIcon(canvas, cx + size * 0.05f, cy + size * 0.05f, size * 0.84f, Color.rgb(192, 220, 232));
    }

    private void drawColorMostlyCloudyIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        drawColorPartlyCloudyIcon(canvas, cx, cy - size * 0.03f, size * 0.92f, accent);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(1.8f));
        paint.setColor(Color.argb(128, Color.red(accent), Color.green(accent), Color.blue(accent)));
        float lineY = cy + size * 0.24f;
        canvas.drawLine(cx - size * 0.33f, lineY, cx - size * 0.07f, lineY, paint);
        canvas.drawLine(cx + size * 0.08f, lineY, cx + size * 0.35f, lineY, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawColorRainCloudIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        drawColorCloudIcon(canvas, cx, cy - size * 0.08f, size, Color.rgb(178, 215, 230));
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2.1f));
        paint.setColor(Color.argb(230, Color.red(accent), Color.green(accent), Color.blue(accent)));
        for (int i = -1; i <= 1; i++) {
            float dropX = cx + i * size * 0.16f;
            canvas.drawLine(dropX + size * 0.04f, cy + size * 0.17f, dropX - size * 0.03f, cy + size * 0.35f, paint);
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawColorThunderIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        drawColorCloudIcon(canvas, cx, cy - size * 0.11f, size, Color.rgb(178, 215, 230));
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2.1f));
        paint.setColor(Color.argb(230, 108, 214, 198));
        for (int i = -1; i <= 1; i += 2) {
            float dropX = cx + i * size * 0.16f;
            canvas.drawLine(dropX + size * 0.04f, cy + size * 0.14f, dropX - size * 0.03f, cy + size * 0.32f, paint);
        }

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2.3f));
        paint.setColor(Color.argb(235, Color.red(accent), Color.green(accent), Color.blue(accent)));
        android.graphics.Path bolt = new android.graphics.Path();
        bolt.moveTo(cx + size * 0.05f, cy + size * 0.02f);
        bolt.lineTo(cx - size * 0.07f, cy + size * 0.28f);
        bolt.lineTo(cx + size * 0.08f, cy + size * 0.25f);
        bolt.lineTo(cx - size * 0.02f, cy + size * 0.48f);
        canvas.drawPath(bolt, paint);
        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawColorSnowIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        drawSnowflake(canvas, cx, cy, size, Color.argb(230, Color.red(accent), Color.green(accent), Color.blue(accent)));
    }

    private void drawColorFogIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2.4f));
        paint.setColor(Color.argb(190, Color.red(accent), Color.green(accent), Color.blue(accent)));
        for (int i = -1; i <= 1; i++) {
            float y = cy + i * size * 0.16f;
            canvas.drawLine(cx - size * 0.36f, y, cx + size * 0.36f, y, paint);
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawColorHazeIcon(Canvas canvas, float cx, float cy, float size, int accent) {
        drawHazeShape(canvas, cx, cy, size, Color.argb(175, Color.red(accent), Color.green(accent), Color.blue(accent)));
    }

    private float weatherIconStroke(float normalDp) {
        return dp(compactWeatherIconStroke ? Math.max(1.35f, normalDp * 0.74f) : normalDp);
    }

    private void drawSimpleSunIcon(Canvas canvas, float cx, float cy, float size) {
        int color = Color.argb(218, 248, 248, 250);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(2.2f));
        paint.setColor(color);
        canvas.drawCircle(cx, cy, size * 0.18f, paint);
        for (int i = 0; i < 8; i++) {
            double angle = Math.toRadians(i * 45);
            float inner = size * 0.29f;
            float outer = size * 0.43f;
            canvas.drawLine(
                cx + (float) Math.cos(angle) * inner,
                cy + (float) Math.sin(angle) * inner,
                cx + (float) Math.cos(angle) * outer,
                cy + (float) Math.sin(angle) * outer,
                paint
            );
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSimpleCloudIcon(Canvas canvas, float cx, float cy, float size) {
        drawCloudShape(canvas, cx, cy, size, Color.argb(205, 248, 248, 250), dp(2.6f));
    }

    private void drawCloudShape(Canvas canvas, float cx, float cy, float size, int color, float strokeWidth) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeWidth(strokeWidth);
        paint.setColor(color);
        float baseY = cy + size * 0.12f;
        canvas.drawArc(cx - size * 0.42f, baseY - size * 0.28f, cx - size * 0.12f, baseY + size * 0.02f, 185, 150, false, paint);
        canvas.drawArc(cx - size * 0.25f, baseY - size * 0.48f, cx + size * 0.18f, baseY - size * 0.05f, 196, 170, false, paint);
        canvas.drawArc(cx + size * 0.03f, baseY - size * 0.34f, cx + size * 0.42f, baseY + size * 0.05f, 218, 132, false, paint);
        canvas.drawLine(cx - size * 0.34f, baseY, cx + size * 0.34f, baseY, paint);
        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSimplePartlyCloudyIcon(Canvas canvas, float cx, float cy, float size) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2f));
        paint.setColor(Color.argb(175, 248, 248, 250));
        float sunCx = cx - size * 0.18f;
        float sunCy = cy - size * 0.16f;
        canvas.drawCircle(sunCx, sunCy, size * 0.15f, paint);
        int[] rayAngles = { 180, 225, 270, 315 };
        for (int angleDeg : rayAngles) {
            double angle = Math.toRadians(angleDeg);
            float inner = size * 0.23f;
            float outer = size * 0.34f;
            canvas.drawLine(
                sunCx + (float) Math.cos(angle) * inner,
                sunCy + (float) Math.sin(angle) * inner,
                sunCx + (float) Math.cos(angle) * outer,
                sunCy + (float) Math.sin(angle) * outer,
                paint
            );
        }

        drawSimpleCloudMask(canvas, cx + size * 0.05f, cy + size * 0.05f, size * 0.90f);
        drawSimpleCloudIcon(canvas, cx + size * 0.05f, cy + size * 0.05f, size * 0.84f);
    }

    private void drawSimpleMostlyCloudyIcon(Canvas canvas, float cx, float cy, float size) {
        drawSimplePartlyCloudyIcon(canvas, cx, cy - size * 0.03f, size * 0.92f);
        int color = Color.argb(150, 248, 248, 250);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(1.8f));
        paint.setColor(color);
        float lineY = cy + size * 0.24f;
        canvas.drawLine(cx - size * 0.33f, lineY, cx - size * 0.07f, lineY, paint);
        canvas.drawLine(cx + size * 0.08f, lineY, cx + size * 0.35f, lineY, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSimpleCloudMask(Canvas canvas, float cx, float cy, float size) {
        float baseY = cy + size * 0.12f;
        android.graphics.Path mask = new android.graphics.Path();
        mask.moveTo(cx - size * 0.40f, baseY);
        mask.cubicTo(cx - size * 0.47f, baseY - size * 0.16f, cx - size * 0.31f, baseY - size * 0.33f, cx - size * 0.17f, baseY - size * 0.25f);
        mask.cubicTo(cx - size * 0.12f, baseY - size * 0.48f, cx + size * 0.20f, baseY - size * 0.52f, cx + size * 0.22f, baseY - size * 0.25f);
        mask.cubicTo(cx + size * 0.44f, baseY - size * 0.25f, cx + size * 0.50f, baseY, cx + size * 0.34f, baseY);
        mask.close();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.BLACK);
        canvas.drawPath(mask, paint);
    }

    private void drawSimpleRainCloudIcon(Canvas canvas, float cx, float cy, float size) {
        drawSimpleCloudIcon(canvas, cx, cy - size * 0.08f, size);
        int color = Color.argb(205, 248, 248, 250);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(2.1f));
        paint.setColor(color);
        for (int i = -1; i <= 1; i++) {
            float dropX = cx + i * size * 0.16f;
            canvas.drawLine(dropX + size * 0.04f, cy + size * 0.17f, dropX - size * 0.03f, cy + size * 0.35f, paint);
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSimpleThunderIcon(Canvas canvas, float cx, float cy, float size) {
        drawSimpleRainCloudIcon(canvas, cx, cy - size * 0.03f, size);
        int color = Color.argb(218, 248, 248, 250);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(2.2f));
        paint.setColor(color);
        android.graphics.Path bolt = new android.graphics.Path();
        bolt.moveTo(cx + size * 0.05f, cy + size * 0.02f);
        bolt.lineTo(cx - size * 0.07f, cy + size * 0.28f);
        bolt.lineTo(cx + size * 0.08f, cy + size * 0.25f);
        bolt.lineTo(cx - size * 0.02f, cy + size * 0.48f);
        canvas.drawPath(bolt, paint);
        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSimpleSnowIcon(Canvas canvas, float cx, float cy, float size) {
        drawSnowflake(canvas, cx, cy, size, Color.argb(205, 248, 248, 250));
    }

    private void drawSnowflake(Canvas canvas, float cx, float cy, float size, int color) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2f));
        paint.setColor(color);
        float radius = size * 0.34f;
        float branch = size * 0.10f;
        for (int i = 0; i < 6; i++) {
            double angle = Math.toRadians(i * 60 - 90);
            float endX = cx + (float) Math.cos(angle) * radius;
            float endY = cy + (float) Math.sin(angle) * radius;
            canvas.drawLine(cx, cy, endX, endY, paint);

            double left = angle + Math.toRadians(140);
            double right = angle - Math.toRadians(140);
            float jointX = cx + (float) Math.cos(angle) * radius * 0.62f;
            float jointY = cy + (float) Math.sin(angle) * radius * 0.62f;
            canvas.drawLine(jointX, jointY, jointX + (float) Math.cos(left) * branch, jointY + (float) Math.sin(left) * branch, paint);
            canvas.drawLine(jointX, jointY, jointX + (float) Math.cos(right) * branch, jointY + (float) Math.sin(right) * branch, paint);
        }
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(120, 248, 248, 250));
        canvas.drawCircle(cx, cy, dp(2.2f), paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSimpleFogIcon(Canvas canvas, float cx, float cy, float size) {
        int color = Color.argb(190, 248, 248, 250);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(2.4f));
        paint.setColor(color);
        for (int i = -1; i <= 1; i++) {
            float y = cy + i * size * 0.16f;
            canvas.drawLine(cx - size * 0.36f, y, cx + size * 0.36f, y, paint);
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawSimpleHazeIcon(Canvas canvas, float cx, float cy, float size) {
        drawHazeShape(canvas, cx, cy, size, Color.argb(165, 248, 248, 250));
    }

    private void drawHazeShape(Canvas canvas, float cx, float cy, float size, int color) {
        float[][] circles = {
            { -0.26f, -0.17f, 0.055f },
            { 0.03f, -0.11f, 0.045f },
            { 0.29f, -0.19f, 0.050f },
            { -0.10f, 0.09f, 0.050f },
            { 0.21f, 0.12f, 0.042f },
            { -0.32f, 0.22f, 0.040f }
        };

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(weatherIconStroke(2f));
        paint.setColor(color);
        float[] ys = { -0.26f, -0.08f, 0.10f, 0.28f };
        for (int i = 0; i < ys.length; i++) {
            float lineY = cy + ys[i] * size;
            float start = cx - size * (i % 2 == 0 ? 0.36f : 0.28f);
            float end = cx + size * (i % 2 == 0 ? 0.34f : 0.38f);
            drawHazeLineAvoidingCircles(canvas, start, end, lineY, cx, cy, size, circles);
        }

        paint.setStrokeWidth(weatherIconStroke(1.4f));
        paint.setColor(Color.argb(108, 248, 248, 250));
        for (float[] circle : circles) {
            canvas.drawCircle(cx + circle[0] * size, cy + circle[1] * size, circle[2] * size, paint);
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawHazeLineAvoidingCircles(Canvas canvas, float start, float end, float y, float cx, float cy, float size, float[][] circles) {
        float cursor = start;
        for (float[] circle : circles) {
            float circleX = cx + circle[0] * size;
            float circleY = cy + circle[1] * size;
            float radius = circle[2] * size + dp(3);
            float dy = Math.abs(y - circleY);
            if (dy >= radius || circleX + radius < start || circleX - radius > end) continue;

            float half = (float) Math.sqrt(radius * radius - dy * dy);
            float gapStart = Math.max(start, circleX - half);
            float gapEnd = Math.min(end, circleX + half);
            if (gapStart > cursor + dp(2)) {
                canvas.drawLine(cursor, y, gapStart - dp(1), y, paint);
            }
            cursor = Math.max(cursor, gapEnd + dp(1));
        }
        if (cursor < end) {
            canvas.drawLine(cursor, y, end, y, paint);
        }
    }

    private void drawSimpleRainIcon(Canvas canvas, float cx, float cy, float size, int color) {
        android.graphics.Path path = new android.graphics.Path();
        path.moveTo(cx, cy - size * 0.42f);
        path.cubicTo(cx + size * 0.28f, cy - size * 0.10f, cx + size * 0.38f, cy + size * 0.12f, cx + size * 0.23f, cy + size * 0.32f);
        path.cubicTo(cx + size * 0.10f, cy + size * 0.48f, cx - size * 0.10f, cy + size * 0.48f, cx - size * 0.23f, cy + size * 0.32f);
        path.cubicTo(cx - size * 0.38f, cy + size * 0.12f, cx - size * 0.28f, cy - size * 0.10f, cx, cy - size * 0.42f);
        path.close();

        int waterColor = Color.rgb(108, 214, 198);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(46, Color.red(waterColor), Color.green(waterColor), Color.blue(waterColor)));
        canvas.drawPath(path, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeWidth(dp(2.2f));
        paint.setColor(Color.argb(230, Color.red(waterColor), Color.green(waterColor), Color.blue(waterColor)));
        canvas.drawPath(path, paint);

        android.graphics.Path highlight = new android.graphics.Path();
        highlight.moveTo(cx - size * 0.08f, cy - size * 0.16f);
        highlight.cubicTo(cx - size * 0.20f, cy + size * 0.02f, cx - size * 0.15f, cy + size * 0.18f, cx - size * 0.02f, cy + size * 0.25f);
        paint.setStrokeWidth(dp(1.5f));
        paint.setColor(Color.argb(155, 248, 248, 250));
        canvas.drawPath(highlight, paint);

        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawAnalogClock(Canvas canvas, float cx, float cy, float radius) {
        Calendar now = Calendar.getInstance(Locale.CHINA);
        long nowMillis = System.currentTimeMillis();
        now.setTimeInMillis(nowMillis);

        drawAppleClockMarks(canvas, cx, cy, radius);

        for (int i = 1; i <= 12; i++) {
            double angle = Math.toRadians(i * 30 - 90);
            float numberSize = dp(20.5f);
            float tx = cx + (float) Math.cos(angle) * radius * 0.78f;
            float ty = cy + (float) Math.sin(angle) * radius * 0.78f + numberSize * 0.34f;
            drawText(canvas, String.valueOf(i), tx, ty, numberSize, Color.rgb(248, 248, 250), Paint.Align.CENTER, true);
        }

        int hour = now.get(Calendar.HOUR);
        int minute = now.get(Calendar.MINUTE);
        int second = now.get(Calendar.SECOND);
        float smoothSecond = second + (nowMillis % 1000L) / 1000f;
        float secondAngle = smoothSecond * 6f - 90f;
        float minuteAngle = (minute + smoothSecond / 60f) * 6f - 90f;
        float hourAngle = (hour + minute / 60f) * 30f - 90f;
        drawPrimaryClockHand(canvas, cx, cy, hourAngle, radius * 0.43f, radius * 0.08f, radius * 0.16f, dp(8.7f));
        drawPrimaryClockHand(canvas, cx, cy, minuteAngle, radius * 0.68f, radius * 0.10f, radius * 0.17f, dp(7.8f));
        drawClockHand(canvas, cx, cy, secondAngle, radius * 0.88f, radius * 0.12f, dp(2), Color.rgb(255, 179, 0));

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(255, 179, 0));
        canvas.drawCircle(cx, cy, dp(8), paint);
        paint.setColor(Color.rgb(20, 20, 20));
        canvas.drawCircle(cx, cy, dp(4.5f), paint);
    }

    private void drawAppleClockMarks(Canvas canvas, float cx, float cy, float radius) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        for (int i = 0; i < 60; i++) {
            boolean major = i % 5 == 0;
            double angle = Math.toRadians(i * 6 - 90);
            float outer = radius * 0.98f;
            float inner = radius * 0.91f;
            float startX = cx + (float) Math.cos(angle) * inner;
            float startY = cy + (float) Math.sin(angle) * inner;
            float endX = cx + (float) Math.cos(angle) * outer;
            float endY = cy + (float) Math.sin(angle) * outer;

            paint.setStrokeWidth(major ? dp(3.6f) : dp(2.2f));
            paint.setColor(major ? Color.argb(225, 248, 248, 250) : Color.argb(118, 248, 248, 250));
            canvas.drawLine(startX, startY, endX, endY, paint);
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawClockHand(Canvas canvas, float cx, float cy, float angleDeg, float length, float backLength, float stroke, int color) {
        double angle = Math.toRadians(angleDeg);
        float startX = cx - (float) Math.cos(angle) * backLength;
        float startY = cy - (float) Math.sin(angle) * backLength;
        float endX = cx + (float) Math.cos(angle) * length;
        float endY = cy + (float) Math.sin(angle) * length;
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(stroke);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setColor(color);
        canvas.drawLine(startX, startY, endX, endY, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawPrimaryClockHand(Canvas canvas, float cx, float cy, float angleDeg, float length, float backLength, float neckLength, float stroke) {
        double angle = Math.toRadians(angleDeg);
        float neckEndX = cx + (float) Math.cos(angle) * neckLength;
        float neckEndY = cy + (float) Math.sin(angle) * neckLength;
        float endX = cx + (float) Math.cos(angle) * length;
        float endY = cy + (float) Math.sin(angle) * length;

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(stroke);
        paint.setColor(Color.rgb(248, 248, 250));
        canvas.drawLine(neckEndX, neckEndY, endX, endY, paint);

        float neckStartX = cx - (float) Math.cos(angle) * backLength;
        float neckStartY = cy - (float) Math.sin(angle) * backLength;
        paint.setStrokeWidth(stroke * 0.44f);
        paint.setColor(Color.rgb(188, 190, 196));
        canvas.drawLine(neckStartX, neckStartY, neckEndX, neckEndY, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
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

    private void drawAnimatedRightPanel(Canvas canvas, float x, float y, float w, float h) {
        float pad = dp(18);
        String title = rightPage == 0 ? "明日天气" : rightPage == 1 ? "快捷入口" : "预留页";
        drawText(canvas, title, x + pad, y + dp(23), dp(14), Color.argb(190, 224, 242, 235), Paint.Align.LEFT, true);
        drawPageDots(canvas, x + w - pad - dp(18), y + dp(21), dp(3.2f), dp(12));

        float contentX = x + pad;
        float contentY = y + dp(42);
        float contentW = w - pad * 2f;
        float contentH = h - dp(128);
        bilibiliButtonRect.setEmpty();

        int save = canvas.save();
        canvas.clipRect(x, y + dp(35), x + w, y + h);
        float animatedPage = animatedRightPage();
        for (int page = 0; page < RIGHT_PAGE_COUNT; page++) {
            float pageX = contentX + (page - animatedPage) * w;
            if (pageX > x + w || pageX + contentW < x) continue;

            if (page == 0) {
                drawTomorrowCard(canvas, pageX, contentY, contentW, contentH);
            } else if (page == 1) {
                drawBilibiliPage(canvas, pageX, contentY + dp(10), contentW, contentH - dp(10));
            } else {
                drawReservedPage(canvas, pageX, contentY + dp(10), contentW, contentH - dp(10), page + 1);
            }
        }
        canvas.restoreToCount(save);
    }

    private float animatedRightPage() {
        if (rightDragging) return displayedRightPage();

        long elapsed = SystemClock.uptimeMillis() - rightPageAnimationStartedAt;
        if (elapsed < 0L || elapsed >= RIGHT_PAGE_ANIMATION_MS) return rightPage;

        float progress = elapsed / (float) RIGHT_PAGE_ANIMATION_MS;
        float eased = 1f - (1f - progress) * (1f - progress) * (1f - progress);
        return rightPageAnimationStart + (rightPage - rightPageAnimationStart) * eased;
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
        drawCyclingColorWeatherIcon(canvas, x + dp(28), headY - dp(3), dp(42), tomorrow.code);
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
            drawTip(canvas, x + dp(10), tipY + i * dp(42), w - dp(20), tips.get(i)[0], tips.get(i)[1]);
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
        canvas.drawCircle(x + dp(10), y + dp(10), dp(9), paint);
        drawText(canvas, icon, x + dp(10), y + dp(14), dp(11), Color.rgb(255, 205, 94), Paint.Align.CENTER, true);
        drawMultilineEllipsizedText(canvas, text, x + dp(28), y + dp(14), dp(12.8f), Color.WHITE, w - dp(28), 2);
    }

    private void drawSimpleTip(Canvas canvas, float x, float y, float w, String icon, String text) {
        paint.setColor(Color.argb(34, 255, 205, 94));
        canvas.drawCircle(x + dp(9), y - dp(5), dp(9), paint);
        drawText(canvas, icon, x + dp(9), y - dp(1), dp(11), Color.rgb(255, 205, 94), Paint.Align.CENTER, true);
        drawMultilineEllipsizedText(canvas, text, x + dp(28), y, dp(13.5f), Color.argb(205, 248, 248, 250), w - dp(28), 1);
    }

    private void drawBilibiliPage(Canvas canvas, float x, float y, float w, float h) {
        float cx = x + w * 0.5f;
        float cy = y + h * 0.42f;

        paint.setShader(new RadialGradient(cx, cy - dp(20), dp(92), Color.argb(38, 251, 114, 153), Color.TRANSPARENT, Shader.TileMode.CLAMP));
        canvas.drawCircle(cx, cy - dp(20), dp(92), paint);
        paint.setShader(null);

        drawText(canvas, "Bilibili", cx, cy - dp(28), dp(28), Color.WHITE, Paint.Align.CENTER, true);
        drawFittedText(canvas, "打开哔哩哔哩 App", cx, cy + dp(2), dp(13), Color.argb(185, 224, 242, 235), Paint.Align.CENTER, false, w - dp(24));

        float buttonW = Math.min(w - dp(28), dp(178));
        float buttonH = dp(48);
        float buttonX = cx - buttonW * 0.5f;
        float buttonY = cy + dp(30);
        bilibiliButtonRect.set(buttonX, buttonY, buttonX + buttonW, buttonY + buttonH);

        paint.setShader(new LinearGradient(buttonX, buttonY, buttonX + buttonW, buttonY + buttonH, Color.rgb(255, 125, 163), Color.rgb(67, 196, 255), Shader.TileMode.CLAMP));
        canvas.drawRoundRect(bilibiliButtonRect, dp(8), dp(8), paint);
        paint.setShader(null);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1));
        paint.setColor(Color.argb(85, 255, 255, 255));
        canvas.drawRoundRect(bilibiliButtonRect, dp(8), dp(8), paint);
        paint.setStyle(Paint.Style.FILL);

        drawText(canvas, ">", buttonX + dp(38), buttonY + dp(31), dp(17), Color.WHITE, Paint.Align.CENTER, true);
        drawText(canvas, "打开 Bilibili", buttonX + buttonW * 0.58f, buttonY + dp(31), dp(15), Color.WHITE, Paint.Align.CENTER, true);
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

    private void drawItalicText(Canvas canvas, String text, float x, float y, float size, int color, Paint.Align align, boolean bold) {
        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(color);
        paint.setTextSize(size);
        paint.setTextAlign(align);
        paint.setFakeBoldText(bold);
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.ITALIC));
        canvas.drawText(text == null ? "" : text, x, y, paint);
        paint.setTypeface(Typeface.DEFAULT);
        paint.setFakeBoldText(false);
    }

    private void drawCenteredText(Canvas canvas, String text, float cx, float cy, float size, int color, boolean bold) {
        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(color);
        paint.setTextSize(size);
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setFakeBoldText(bold);
        Paint.FontMetrics metrics = paint.getFontMetrics();
        canvas.drawText(text == null ? "" : text, cx, cy - (metrics.ascent + metrics.descent) * 0.5f, paint);
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

    private void drawMultilineEllipsizedText(Canvas canvas, String text, float x, float y, float size, int color, float maxWidth, int maxLines) {
        String value = text == null ? "" : text.trim();
        if (value.isEmpty() || maxLines <= 0) return;

        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(color);
        paint.setTextAlign(Paint.Align.LEFT);
        paint.setTextSize(size);
        paint.setFakeBoldText(true);

        ArrayList<String> lines = new ArrayList<>();
        StringBuilder line = new StringBuilder();
        boolean overflow = false;
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            String next = line.toString() + c;
            if (line.length() > 0 && paint.measureText(next) > maxWidth) {
                lines.add(line.toString());
                line.setLength(0);
                line.append(c);
                if (lines.size() == maxLines) {
                    overflow = true;
                    break;
                }
            } else {
                line.append(c);
            }
        }

        if (!overflow && line.length() > 0) {
            lines.add(line.toString());
        }
        if (lines.size() > maxLines) {
            overflow = true;
            while (lines.size() > maxLines) {
                lines.remove(lines.size() - 1);
            }
        }
        if (overflow && !lines.isEmpty()) {
            lines.set(lines.size() - 1, ellipsize(lines.get(lines.size() - 1), maxWidth));
        }

        float lineHeight = dp(15.5f);
        for (int i = 0; i < lines.size(); i++) {
            canvas.drawText(lines.get(i), x, y + i * lineHeight, paint);
        }
        paint.setFakeBoldText(false);
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

    private int alphaColor(int color, int alpha) {
        return Color.argb(Math.max(0, Math.min(255, alpha)), Color.red(color), Color.green(color), Color.blue(color));
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

    public interface ActionListener {
        void onOpenBilibili();
    }
}
