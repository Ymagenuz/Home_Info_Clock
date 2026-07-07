package com.homepanel.clock;

import android.content.Context;
import android.content.SharedPreferences;
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
    private static final String TIMER_PREFS = "home_panel_timer";
    private static final String KEY_TIMER_HOURS = "hours";
    private static final String KEY_TIMER_MINUTES = "minutes";
    private static final String KEY_TIMER_SECONDS = "seconds";
    private static final String KEY_TIMER_RUNNING = "running";
    private static final String KEY_TIMER_ENDS_AT = "ends_at";
    private static final String KEY_TIMER_FINISHED = "finished";
    private static final int PAGE_RESET_MS = 20_000;
    private static final int LOW_BATTERY_PERCENT = 20;
    private static final long BATTERY_TRANSITION_MS = 900L;
    private static final int LEFT_PAGE_COUNT = 2;
    private static final int CENTER_PAGE_COUNT = 2;
    private static final int RIGHT_PAGE_COUNT = 3;
    private static final long RIGHT_PAGE_ANIMATION_MS = 260L;
    private static final long TIMER_ARROW_FADE_MS = 180L;
    private static final long TIMER_FINISHED_SHAKE_MS = 820L;
    private static final long TIMER_FINISHED_PAUSE_MS = 800L;
    private static final long CLOCK_FRAME_MS = 33L;
    private static final long SIMPLE_MODE_ANIMATION_MS = 320L;
    private static final boolean WEATHER_ICON_TEST_CYCLE = false;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final RectF timerHourButtonRect = new RectF();
    private final RectF timerMinuteButtonRect = new RectF();
    private final RectF timerSecondButtonRect = new RectF();
    private final RectF timerStartButtonRect = new RectF();
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
    private int leftPage;
    private boolean leftTouchActive;
    private boolean leftDragging;
    private boolean leftVerticalDragging;
    private float leftDragOffsetPx;
    private float leftPanelStartX;
    private float leftPanelEndX;
    private float leftPageAnimationStart;
    private long leftPageAnimationStartedAt = -RIGHT_PAGE_ANIMATION_MS;
    private float leftTrendScrollY;
    private float leftTrendMaxScroll;
    private float leftLastTouchY;
    private int centerPage;
    private boolean centerTouchActive;
    private boolean centerDragging;
    private float centerDragOffsetPx;
    private float centerPanelStartX;
    private float centerPanelEndX;
    private float centerPageAnimationStart;
    private long centerPageAnimationStartedAt = -RIGHT_PAGE_ANIMATION_MS;
    private int timerHours;
    private int timerMinutes;
    private int timerSeconds;
    private boolean timerRunning;
    private long timerEndsAtMillis;
    private long timerVisualStartedAt = -RIGHT_PAGE_ANIMATION_MS;
    private boolean timerFinished;
    private long timerFinishedStartedAt = -RIGHT_PAGE_ANIMATION_MS;
    private int timerActiveUnit = -1;
    private boolean timerRotating;
    private boolean timerClockwiseStarted;
    private long timerAdjustmentStartedAt = -TIMER_ARROW_FADE_MS;
    private long timerArrowFadeOutStartedAt = -TIMER_ARROW_FADE_MS;
    private float timerCenterX;
    private float timerCenterY;
    private float timerRadius;
    private float timerLastAngle;
    private float timerAccumulatedAngle;
    private float timerContinuousValue;
    private int timerFadingUnit = -1;
    private float timerFadingValue;
    private long timerValueFadeOutStartedAt = -TIMER_ARROW_FADE_MS;
    private int rightPage;
    private float touchDownX;
    private float touchDownY;
    private boolean weatherRefreshDragging;
    private boolean weatherRefreshLoading;
    private int weatherRefreshPanel = -1;
    private float weatherRefreshPull;
    private float weatherRefreshReboundStart;
    private long weatherRefreshReboundStartedAt = -RIGHT_PAGE_ANIMATION_MS;
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

    private final Runnable leftPageAnimationTicker = new Runnable() {
        @Override
        public void run() {
            long elapsed = SystemClock.uptimeMillis() - leftPageAnimationStartedAt;
            if (elapsed < RIGHT_PAGE_ANIMATION_MS) {
                invalidate();
                postDelayed(this, 16L);
            }
        }
    };

    private final Runnable centerPageAnimationTicker = new Runnable() {
        @Override
        public void run() {
            long elapsed = SystemClock.uptimeMillis() - centerPageAnimationStartedAt;
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

    private final Runnable weatherRefreshTimeout = new Runnable() {
        @Override
        public void run() {
            completeWeatherRefresh();
        }
    };

    public HomePanelView(Context context) {
        super(context);
        density = getResources().getDisplayMetrics().density;
        setFocusable(true);
        restoreTimerState();
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
        completeWeatherRefresh();
        invalidate();
    }

    public void setWeatherStatus(String status) {
        this.weatherStatus = status == null ? "" : status;
        if (weatherRefreshLoading && (status == null || !status.contains("更新"))) {
            completeWeatherRefresh();
        }
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
        removeCallbacks(leftPageAnimationTicker);
        removeCallbacks(centerPageAnimationTicker);
        removeCallbacks(rightPageAnimationTicker);
        removeCallbacks(weatherRefreshTimeout);
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
        leftPanelStartX = leftX;
        leftPanelEndX = centerX;
        centerPanelStartX = centerX;
        centerPanelEndX = rightX;
        rightPanelStartX = rightX;
        rightPanelEndX = width - outer;

        drawModeTransition(canvas, width, height, leftX, centerX, rightX, top, bottom, leftW, centerW, outer);
        if (timerFinished) {
            drawTimerFinishedOverlay(canvas, width, height);
        }
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

        drawAnimatedWeatherPanel(canvas, leftX, top, leftW, bottom - top);
        drawAnimatedClockPanel(canvas, centerX, top, centerW, bottom - top);
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
        if (timerFinished) {
            if (event.getAction() == MotionEvent.ACTION_UP) {
                dismissTimerFinished();
            }
            return true;
        }

        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            if (isSystemGestureEdge(event.getX())) return false;

            touchDownX = event.getX();
            touchDownY = event.getY();
            leftLastTouchY = touchDownY;
            leftTouchActive = !simpleMode && isInLeftPanel(touchDownX);
            centerTouchActive = !simpleMode && isInCenterPanel(touchDownX);
            rightTouchActive = !simpleMode && isInRightPanel(touchDownX);
            weatherRefreshDragging = false;
            weatherRefreshPanel = -1;
            weatherRefreshPull = 0f;
            if (leftTouchActive && rightTouchActive) {
                rightTouchActive = false;
            }
            if (leftTouchActive || centerTouchActive) {
                rightTouchActive = false;
            }
            if (leftTouchActive) {
                centerTouchActive = false;
            }
            leftDragging = false;
            leftVerticalDragging = false;
            leftDragOffsetPx = 0f;
            centerDragging = false;
            centerDragOffsetPx = 0f;
            timerActiveUnit = -1;
            timerRotating = false;
            timerClockwiseStarted = false;
            rightDragging = false;
            rightDragOffsetPx = 0f;
            if (leftTouchActive) {
                removeCallbacks(leftPageAnimationTicker);
                leftPageAnimationStartedAt = -RIGHT_PAGE_ANIMATION_MS;
            }
            if (centerTouchActive) {
                removeCallbacks(centerPageAnimationTicker);
                centerPageAnimationStartedAt = -RIGHT_PAGE_ANIMATION_MS;
                if (centerPage == 1) {
                    if (timerStartButtonRect.contains(touchDownX, touchDownY)) {
                        return true;
                    }
                    if (!timerRunning) {
                        int unit = timerUnitAt(touchDownX, touchDownY);
                        if (unit >= 0) {
                            beginTimerAdjustment(unit, touchDownX, touchDownY);
                        }
                    }
                }
            }
            if (rightTouchActive) {
                removeCallbacks(rightPageAnimationTicker);
                rightPageAnimationStartedAt = -RIGHT_PAGE_ANIMATION_MS;
            }
            return true;
        }

        if (event.getAction() == MotionEvent.ACTION_MOVE) {
            float dx = event.getX() - touchDownX;
            float dy = event.getY() - touchDownY;

            if (leftTouchActive) {
                if (!leftDragging && !leftVerticalDragging && !weatherRefreshDragging) {
                    if (leftPage == 0 && dy > dp(9) && dy > Math.abs(dx)) {
                        weatherRefreshDragging = true;
                        weatherRefreshPanel = 0;
                    } else if (leftPage == 1 && Math.abs(dy) > dp(8) && Math.abs(dy) > Math.abs(dx)) {
                        leftVerticalDragging = true;
                    } else if (Math.abs(dx) > dp(8) && Math.abs(dx) > Math.abs(dy)) {
                        leftDragging = true;
                    }
                }
                if (weatherRefreshDragging) {
                    updateWeatherRefreshPull(dy);
                } else if (leftDragging) {
                    leftDragOffsetPx = resistedLeftDrag(dx);
                    invalidate();
                } else if (leftVerticalDragging) {
                    float stepY = event.getY() - leftLastTouchY;
                    leftTrendScrollY = clamp(leftTrendScrollY - stepY, 0f, leftTrendMaxScroll);
                    leftLastTouchY = event.getY();
                    invalidate();
                }
                return true;
            }

            if (centerTouchActive) {
                if (timerRotating) {
                    updateTimerAdjustment(event.getX(), event.getY());
                    return true;
                }
                if (!centerDragging && Math.abs(dx) > dp(8) && Math.abs(dx) > Math.abs(dy)) {
                    centerDragging = true;
                }
                if (centerDragging) {
                    centerDragOffsetPx = resistedCenterDrag(dx);
                    invalidate();
                }
                return true;
            }

            if (rightTouchActive && !rightDragging && Math.abs(dx) > dp(8) && Math.abs(dx) > Math.abs(dy)) {
                if (!weatherRefreshDragging) {
                    rightDragging = true;
                    removeCallbacks(resetRightPage);
                }
            }
            if (rightTouchActive && !rightDragging && !weatherRefreshDragging && rightPage == 0 && dy > dp(9) && dy > Math.abs(dx)) {
                weatherRefreshDragging = true;
                weatherRefreshPanel = 1;
            }
            if (rightTouchActive && weatherRefreshDragging) {
                updateWeatherRefreshPull(dy);
                return true;
            }
            if (rightTouchActive && rightDragging) {
                rightDragOffsetPx = resistedRightDrag(dx);
                invalidate();
            }
            return true;
        }

        if (event.getAction() == MotionEvent.ACTION_UP) {
            float dx = event.getX() - touchDownX;
            float dy = event.getY() - touchDownY;
            boolean tap = Math.abs(dx) < dp(12) && Math.abs(dy) < dp(12);

            if (leftTouchActive) {
                if (weatherRefreshDragging) {
                    finishWeatherRefresh();
                } else if (leftDragging || (Math.abs(dx) > dp(36) && Math.abs(dx) > Math.abs(dy))) {
                    settleLeftDrag(dx);
                } else if (tap && !leftVerticalDragging) {
                    toggleSimpleMode();
                }
                leftTouchActive = false;
                leftDragging = false;
                leftVerticalDragging = false;
                leftDragOffsetPx = 0f;
                return true;
            }

            if (centerTouchActive) {
                if (timerRotating) {
                    finishTimerAdjustment();
                } else if (centerDragging || (Math.abs(dx) > dp(36) && Math.abs(dx) > Math.abs(dy))) {
                    settleCenterDrag(dx);
                } else if (tap && centerPage == 1 && timerStartButtonRect.contains(event.getX(), event.getY())) {
                    handleTimerStartButton();
                } else if (tap && centerPage == 0) {
                    toggleSimpleMode();
                }
                centerTouchActive = false;
                centerDragging = false;
                centerDragOffsetPx = 0f;
                return true;
            }

            if (rightTouchActive && (rightDragging || (Math.abs(dx) > dp(36) && Math.abs(dx) > Math.abs(dy)))) {
                settleRightDrag(dx);
                removeCallbacks(resetRightPage);
                postDelayed(resetRightPage, PAGE_RESET_MS);
            } else if (rightTouchActive && weatherRefreshDragging) {
                finishWeatherRefresh();
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
            if (leftTouchActive) {
                leftTouchActive = false;
                leftDragging = false;
                leftVerticalDragging = false;
                cancelWeatherRefresh();
                animateLeftPageTo(leftPage, displayedLeftPage());
                leftDragOffsetPx = 0f;
                return true;
            }
            if (centerTouchActive) {
                centerTouchActive = false;
                centerDragging = false;
                cancelWeatherRefresh();
                finishTimerAdjustment();
                animateCenterPageTo(centerPage, displayedCenterPage());
                centerDragOffsetPx = 0f;
                return true;
            }
            if (!rightTouchActive) return true;
            rightTouchActive = false;
            rightDragging = false;
            cancelWeatherRefresh();
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
        centerDragging = false;
        centerDragOffsetPx = 0f;
        finishTimerAdjustment();
        rightDragging = false;
        rightDragOffsetPx = 0f;
        invalidate();
    }

    private boolean isSystemGestureEdge(float x) {
        return x <= dp(26) || x >= getWidth() - dp(26);
    }

    private void updateWeatherRefreshPull(float dy) {
        weatherRefreshPull = dy <= 0f ? 0f : Math.min(dp(64), dy * 0.42f);
        invalidate();
    }

    private void finishWeatherRefresh() {
        boolean shouldRefresh = weatherRefreshPull >= dp(42);
        if (shouldRefresh && actionListener != null) {
            weatherRefreshDragging = false;
            weatherRefreshLoading = true;
            weatherRefreshPull = dp(46);
            removeCallbacks(weatherRefreshTimeout);
            postDelayed(weatherRefreshTimeout, 12_000L);
            actionListener.onWeatherRefreshRequested();
            invalidate();
        } else {
            cancelWeatherRefresh();
        }
    }

    private void cancelWeatherRefresh() {
        weatherRefreshDragging = false;
        weatherRefreshLoading = false;
        removeCallbacks(weatherRefreshTimeout);
        beginWeatherRefreshRebound(weatherRefreshPull);
    }

    private void completeWeatherRefresh() {
        if (!weatherRefreshLoading && weatherRefreshPull <= 0f) return;

        removeCallbacks(weatherRefreshTimeout);
        weatherRefreshDragging = false;
        weatherRefreshLoading = false;
        beginWeatherRefreshRebound(weatherRefreshPull);
    }

    private void beginWeatherRefreshRebound(float from) {
        weatherRefreshReboundStart = from;
        weatherRefreshReboundStartedAt = SystemClock.uptimeMillis();
        weatherRefreshPull = 0f;
        invalidate();
    }

    private float weatherRefreshOffset(int panel) {
        if (weatherRefreshPanel != panel) return 0f;
        if (weatherRefreshDragging || weatherRefreshLoading) return weatherRefreshPull;

        long elapsed = SystemClock.uptimeMillis() - weatherRefreshReboundStartedAt;
        if (elapsed < 0L || elapsed >= RIGHT_PAGE_ANIMATION_MS) {
            weatherRefreshPanel = -1;
            weatherRefreshReboundStart = 0f;
            return 0f;
        }

        float t = elapsed / (float) RIGHT_PAGE_ANIMATION_MS;
        float eased = 1f - (1f - t) * (1f - t) * (1f - t);
        return weatherRefreshReboundStart * (1f - eased);
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

    private boolean isInLeftPanel(float x) {
        float width = getWidth();
        float outer = dp(10);
        float leftW = clamp(width * 0.27f, dp(210), width * 0.33f);
        float rightW = clamp(width * 0.31f, dp(225), width * 0.34f);
        float centerW = width - leftW - rightW - outer * 2f;

        if (centerW < dp(270)) {
            leftW = width * 0.28f;
        }

        float leftStart = outer;
        float leftEnd = outer + leftW;
        return x >= leftStart && x <= leftEnd;
    }

    private boolean isInCenterPanel(float x) {
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

        float centerStart = outer + leftW;
        float centerEnd = centerStart + centerW;
        return x >= centerStart && x <= centerEnd;
    }

    private void setLeftPage(int page) {
        int nextPage = Math.max(0, Math.min(LEFT_PAGE_COUNT - 1, page));
        if (nextPage == leftPage) return;

        animateLeftPageTo(nextPage, leftPage);
    }

    private void settleLeftDrag(float dx) {
        float panelW = Math.max(1f, leftPanelEndX - leftPanelStartX);
        int targetPage = leftPage;
        if (Math.abs(dx) > panelW * 0.22f || Math.abs(dx) > dp(72)) {
            targetPage = dx < 0 ? leftPage + 1 : leftPage - 1;
        }
        targetPage = Math.max(0, Math.min(LEFT_PAGE_COUNT - 1, targetPage));
        animateLeftPageTo(targetPage, displayedLeftPage());
    }

    private void animateLeftPageTo(int nextPage, float fromPage) {
        if (Math.abs(fromPage - nextPage) < 0.001f) {
            leftPage = nextPage;
            leftDragOffsetPx = 0f;
            invalidate();
            return;
        }

        leftPageAnimationStart = fromPage;
        leftPage = nextPage;
        leftPageAnimationStartedAt = SystemClock.uptimeMillis();
        removeCallbacks(leftPageAnimationTicker);
        post(leftPageAnimationTicker);
        invalidate();
    }

    private float displayedLeftPage() {
        float panelW = Math.max(1f, leftPanelEndX - leftPanelStartX);
        return leftPage - leftDragOffsetPx / panelW;
    }

    private float resistedLeftDrag(float dx) {
        if ((leftPage == 0 && dx > 0f) || (leftPage == LEFT_PAGE_COUNT - 1 && dx < 0f)) {
            return dx * 0.28f;
        }
        return dx;
    }

    private float animatedLeftPage() {
        if (leftDragging) return displayedLeftPage();

        long elapsed = SystemClock.uptimeMillis() - leftPageAnimationStartedAt;
        if (elapsed < 0L || elapsed >= RIGHT_PAGE_ANIMATION_MS) return leftPage;

        float progress = elapsed / (float) RIGHT_PAGE_ANIMATION_MS;
        float eased = 1f - (1f - progress) * (1f - progress) * (1f - progress);
        return leftPageAnimationStart + (leftPage - leftPageAnimationStart) * eased;
    }

    private void settleCenterDrag(float dx) {
        float panelW = Math.max(1f, centerPanelEndX - centerPanelStartX);
        int targetPage = centerPage;
        if (Math.abs(dx) > panelW * 0.22f || Math.abs(dx) > dp(72)) {
            targetPage = dx < 0 ? centerPage + 1 : centerPage - 1;
        }
        targetPage = Math.max(0, Math.min(CENTER_PAGE_COUNT - 1, targetPage));
        animateCenterPageTo(targetPage, displayedCenterPage());
    }

    private void animateCenterPageTo(int nextPage, float fromPage) {
        if (Math.abs(fromPage - nextPage) < 0.001f) {
            centerPage = nextPage;
            centerDragOffsetPx = 0f;
            invalidate();
            return;
        }

        centerPageAnimationStart = fromPage;
        centerPage = nextPage;
        centerPageAnimationStartedAt = SystemClock.uptimeMillis();
        removeCallbacks(centerPageAnimationTicker);
        post(centerPageAnimationTicker);
        invalidate();
    }

    private float displayedCenterPage() {
        float panelW = Math.max(1f, centerPanelEndX - centerPanelStartX);
        return centerPage - centerDragOffsetPx / panelW;
    }

    private float resistedCenterDrag(float dx) {
        if ((centerPage == 0 && dx > 0f) || (centerPage == CENTER_PAGE_COUNT - 1 && dx < 0f)) {
            return dx * 0.28f;
        }
        return dx;
    }

    private float animatedCenterPage() {
        if (centerDragging) return displayedCenterPage();

        long elapsed = SystemClock.uptimeMillis() - centerPageAnimationStartedAt;
        if (elapsed < 0L || elapsed >= RIGHT_PAGE_ANIMATION_MS) return centerPage;

        float progress = elapsed / (float) RIGHT_PAGE_ANIMATION_MS;
        float eased = 1f - (1f - progress) * (1f - progress) * (1f - progress);
        return centerPageAnimationStart + (centerPage - centerPageAnimationStart) * eased;
    }

    private int timerUnitAt(float x, float y) {
        if (timerHourButtonRect.contains(x, y)) return 0;
        if (timerMinuteButtonRect.contains(x, y)) return 1;
        if (timerSecondButtonRect.contains(x, y)) return 2;
        return -1;
    }

    private void beginTimerAdjustment(int unit, float x, float y) {
        timerActiveUnit = unit;
        timerFadingUnit = -1;
        timerRotating = true;
        timerClockwiseStarted = false;
        timerAdjustmentStartedAt = SystemClock.uptimeMillis();
        timerArrowFadeOutStartedAt = -TIMER_ARROW_FADE_MS;
        timerAccumulatedAngle = 0f;
        timerLastAngle = angleAroundTimer(x, y);
        snapTimerToAngle(timerLastAngle, unit);
        invalidate();
    }

    private void updateTimerAdjustment(float x, float y) {
        float angle = angleAroundTimer(x, y);
        float delta = angle - timerLastAngle;
        if (delta > 180f) delta -= 360f;
        if (delta < -180f) delta += 360f;
        timerLastAngle = angle;

        timerAccumulatedAngle += delta;
        if (Math.abs(timerAccumulatedAngle) > 4f) {
            if (!timerClockwiseStarted) {
                timerArrowFadeOutStartedAt = SystemClock.uptimeMillis();
            }
            timerClockwiseStarted = true;
        }
        timerContinuousValue = clamp(timerContinuousValue + delta / timerStepDegrees(timerActiveUnit), 0f, timerActiveUnit == 0 ? 11f : 59f);
        setTimerValue(timerActiveUnit, Math.round(timerContinuousValue));
        persistTimerState();
        invalidate();
    }

    private void finishTimerAdjustment() {
        if (timerActiveUnit >= 0) {
            timerFadingUnit = timerActiveUnit;
            timerFadingValue = timerContinuousValue;
            timerValueFadeOutStartedAt = SystemClock.uptimeMillis();
        }
        timerRotating = false;
        timerActiveUnit = -1;
        timerClockwiseStarted = false;
        timerContinuousValue = 0f;
        invalidate();
    }

    private float angleAroundTimer(float x, float y) {
        float angle = (float) Math.toDegrees(Math.atan2(y - timerCenterY, x - timerCenterX)) + 90f;
        if (angle < 0f) angle += 360f;
        if (angle >= 360f) angle -= 360f;
        return angle;
    }

    private float timerStepDegrees(int unit) {
        return unit == 0 ? 30f : 6f;
    }

    private void snapTimerToAngle(float angle, int unit) {
        if (unit == 0) {
            timerContinuousValue = clamp(angle / timerStepDegrees(unit), 0f, 11f);
        } else {
            timerContinuousValue = clamp(angle / timerStepDegrees(unit), 0f, 59f);
        }
        setTimerValue(unit, Math.round(timerContinuousValue));
        persistTimerState();
    }

    private int timerDisplayTick(int unit) {
        if (unit == 0) {
            int value = Math.round(timerContinuousValue);
            return value == 0 ? 0 : ((value - 1) % 12) + 1;
        }
        return Math.round(timerContinuousValue);
    }

    private int timerValue(int unit) {
        if (unit == 0) return timerHours;
        if (unit == 1) return timerMinutes;
        return timerSeconds;
    }

    private void setTimerValue(int unit, int value) {
        if (unit == 0) {
            timerHours = Math.max(0, Math.min(11, value));
        } else if (unit == 1) {
            timerMinutes = Math.max(0, Math.min(59, value));
        } else {
            timerSeconds = Math.max(0, Math.min(59, value));
        }
    }

    private void handleTimerStartButton() {
        if (timerRunning) {
            clearTimer();
        } else if (timerTotalSeconds() > 0) {
            timerRunning = true;
            timerFinished = false;
            timerEndsAtMillis = System.currentTimeMillis() + timerTotalSeconds() * 1000L;
            timerVisualStartedAt = SystemClock.uptimeMillis();
            persistTimerState();
        }
        invalidate();
    }

    private void clearTimer() {
        timerRunning = false;
        timerFinished = false;
        timerEndsAtMillis = 0L;
        timerHours = 0;
        timerMinutes = 0;
        timerSeconds = 0;
        finishTimerAdjustment();
        persistTimerState();
    }

    private void showTimerFinished() {
        if (timerFinished) return;
        timerFinished = true;
        timerFinishedStartedAt = SystemClock.uptimeMillis();
    }

    private void dismissTimerFinished() {
        timerFinished = false;
        timerFinishedStartedAt = -RIGHT_PAGE_ANIMATION_MS;
        persistTimerState();
        invalidate();
    }

    private void restoreTimerState() {
        SharedPreferences prefs = getContext().getSharedPreferences(TIMER_PREFS, Context.MODE_PRIVATE);
        timerHours = prefs.getInt(KEY_TIMER_HOURS, 0);
        timerMinutes = prefs.getInt(KEY_TIMER_MINUTES, 0);
        timerSeconds = prefs.getInt(KEY_TIMER_SECONDS, 0);
        timerRunning = prefs.getBoolean(KEY_TIMER_RUNNING, false);
        timerEndsAtMillis = prefs.getLong(KEY_TIMER_ENDS_AT, 0L);
        timerFinished = prefs.getBoolean(KEY_TIMER_FINISHED, false);
        if (timerFinished) {
            timerFinishedStartedAt = SystemClock.uptimeMillis();
        }
        if (timerRunning && timerEndsAtMillis > 0L) {
            timerVisualStartedAt = SystemClock.uptimeMillis() - RIGHT_PAGE_ANIMATION_MS;
            syncTimerRunningState();
        }
    }

    private void persistTimerState() {
        getContext().getSharedPreferences(TIMER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY_TIMER_HOURS, timerHours)
            .putInt(KEY_TIMER_MINUTES, timerMinutes)
            .putInt(KEY_TIMER_SECONDS, timerSeconds)
            .putBoolean(KEY_TIMER_RUNNING, timerRunning)
            .putLong(KEY_TIMER_ENDS_AT, timerEndsAtMillis)
            .putBoolean(KEY_TIMER_FINISHED, timerFinished)
            .apply();
    }

    private void syncTimerRunningState() {
        if (!timerRunning) return;

        long remainingMs = timerEndsAtMillis - System.currentTimeMillis();
        if (remainingMs <= 0L) {
            timerRunning = false;
            timerHours = 0;
            timerMinutes = 0;
            timerSeconds = 0;
            showTimerFinished();
            persistTimerState();
            return;
        }

        int remaining = (int) Math.ceil(remainingMs / 1000d);
        timerHours = remaining / 3600;
        timerMinutes = (remaining / 60) % 60;
        timerSeconds = remaining % 60;
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

    private void drawAnimatedWeatherPanel(Canvas canvas, float x, float y, float w, float h) {
        int save = canvas.save();
        canvas.clipRect(x, y, x + w, y + h);
        float animatedPage = animatedLeftPage();
        for (int page = 0; page < LEFT_PAGE_COUNT; page++) {
            float pageX = x + (page - animatedPage) * w;
            if (pageX > x + w || pageX + w < x) continue;

            if (page == 0) {
                drawWeatherPanel(canvas, pageX, y, w, h);
            } else {
                drawWeatherTrendPage(canvas, pageX, y, w, h);
            }
        }
        canvas.restoreToCount(save);
        drawWeatherRefreshIndicator(canvas, x, y, w, 1);
    }

    private void drawWeatherPanel(Canvas canvas, float x, float y, float w, float h) {
        float pad = dp(18);
        float small = scaleText(h, 12, 14);
        float label = scaleText(h, 13, 16);
        float titleY = y + dp(23);
        drawWeatherRefreshIndicator(canvas, x, y, w, 0);

        int refreshSave = canvas.save();
        canvas.translate(0f, weatherRefreshOffset(0));

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
            canvas.restoreToCount(refreshSave);
            return;
        }

        WeatherDay today = weather.days.isEmpty() ? null : weather.days.get(0);
        float blockTop = y + dp(66);
        float iconCx = x + pad + dp(34);
        float iconCy = blockTop + dp(34);
        float rightX = x + pad + dp(82);
        int todayRain = today == null ? 0 : today.precipitation;
        String highLow = today != null ? today.high + "°/" + today.low + "°" : "--°/--°";

        drawCircleBadge(canvas, iconCx, iconCy, dp(28), "", dp(24));
        drawCyclingColorWeatherIcon(canvas, iconCx, iconCy, dp(46), weather.currentCode);

        drawText(canvas, weather.currentTemp + "°", rightX, blockTop + dp(39), dp(36), Color.rgb(238, 250, 246), Paint.Align.LEFT, true);
        drawFittedText(canvas, weather.currentDescription,
            iconCx,
            blockTop + dp(72),
            dp(15),
            Color.WHITE,
            Paint.Align.CENTER,
            true,
            dp(92)
        );
        drawFittedText(canvas, highLow, rightX, blockTop + dp(72), dp(19), Color.argb(225, 238, 250, 246), Paint.Align.LEFT, true, x + w - pad - rightX);

        float metricsTop = blockTop + dp(108);
        drawWeatherMetricRings(canvas, x + pad, metricsTop, w - pad * 2f, dp(98), today, todayRain);
        drawBattery(canvas, x + pad, y + h - dp(54), w - pad * 2f);
        canvas.restoreToCount(refreshSave);
    }

    private void drawWeatherRefreshIndicator(Canvas canvas, float x, float y, float w, int panel) {
        if (weatherRefreshPanel != panel || (!weatherRefreshDragging && !weatherRefreshLoading) || weatherRefreshPull <= 0f) return;

        float progress = Math.min(1f, weatherRefreshPull / dp(42));
        float cx = x + w * 0.5f;
        float cy = y + dp(12) + Math.min(weatherRefreshPull, dp(46)) * 0.42f;
        float startAngle = weatherRefreshLoading ? (SystemClock.uptimeMillis() % 900L) / 900f * 360f - 90f : -90f;
        float sweep = weatherRefreshLoading ? 270f : 360f * progress;
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(2.2f));
        paint.setColor(Color.argb(Math.round(70 + 110 * progress), 100, 220, 205));
        rect.set(cx - dp(12), cy - dp(12), cx + dp(12), cy + dp(12));
        canvas.drawArc(rect, startAngle, sweep, false, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
        drawText(canvas, weatherRefreshLoading ? "刷新中" : progress >= 1f ? "松开刷新" : "下拉刷新", cx, cy + dp(28), dp(10.5f), Color.argb(Math.round(120 + 80 * progress), 224, 242, 235), Paint.Align.CENTER, false);
    }

    private void drawWeatherTrendPage(Canvas canvas, float x, float y, float w, float h) {
        float pad = dp(18);
        float titleY = y + dp(23);
        drawFittedText(canvas, "天气趋势", x + pad, titleY, scaleText(h, 13, 16), Color.argb(190, 224, 242, 235), Paint.Align.LEFT, true, w - pad * 2f);

        if (weather == null || weather.days.isEmpty()) {
            drawText(canvas, weatherStatus == null || weatherStatus.isEmpty() ? "等待天气数据" : weatherStatus,
                x + w * 0.5f,
                y + h * 0.5f,
                dp(18),
                Color.rgb(238, 250, 246),
                Paint.Align.CENTER,
                true
            );
            leftTrendMaxScroll = 0f;
            return;
        }

        int count = weather.days.size();
        drawFittedText(canvas, "共 " + count + " 天 · 上下滑动查看", x + pad, titleY + dp(24), scaleText(h, 12, 14), Color.argb(178, 224, 242, 235), Paint.Align.LEFT, true, w - pad * 2f);

        float contentTop = y + dp(66);
        float contentBottom = y + h - dp(18);
        float viewportH = Math.max(dp(80), contentBottom - contentTop);
        float rowH = dp(36);
        float contentH = rowH * count;
        leftTrendMaxScroll = Math.max(0f, contentH - viewportH);
        leftTrendScrollY = clamp(leftTrendScrollY, 0f, leftTrendMaxScroll);

        int minTemp = Integer.MAX_VALUE;
        int maxTemp = Integer.MIN_VALUE;
        for (int i = 0; i < count; i++) {
            WeatherDay day = weather.days.get(i);
            minTemp = Math.min(minTemp, day.low);
            maxTemp = Math.max(maxTemp, day.high);
        }
        if (minTemp == Integer.MAX_VALUE || minTemp == maxTemp) {
            minTemp -= 1;
            maxTemp += 1;
        }

        int save = canvas.save();
        canvas.clipRect(x + pad, contentTop, x + w - pad, contentBottom);
        Calendar calendar = Calendar.getInstance(Locale.CHINA);
        for (int i = 0; i < count; i++) {
            WeatherDay day = weather.days.get(i);
            float rowTop = contentTop + i * rowH - leftTrendScrollY;
            if (rowTop > contentBottom || rowTop + rowH < contentTop) {
                calendar.add(Calendar.DAY_OF_YEAR, 1);
                continue;
            }

            String label = i == 0 ? "今天" : i == 1 ? "明天" : new SimpleDateFormat("E", Locale.CHINA).format(calendar.getTime());
            float baseline = rowTop + rowH * 0.65f;
            float barY = rowTop + rowH * 0.51f;
            drawText(canvas, label, x + pad, baseline, dp(11.5f), Color.argb(190, 224, 242, 235), Paint.Align.LEFT, false);
            drawCyclingColorWeatherIcon(canvas, x + pad + dp(42), baseline - dp(4), dp(18), day.code, true);

            float lowX = x + pad + w * 0.37f;
            float barStart = x + pad + w * 0.50f;
            float barEnd = x + pad + w * 0.78f;
            float highX = x + w - pad;
            float lowPos = map(day.low, minTemp, maxTemp, barStart, barEnd);
            float highPos = map(day.high, minTemp, maxTemp, barStart, barEnd);
            drawTemperatureBar(canvas, barStart, barEnd, lowPos, highPos, barY);
            drawText(canvas, day.low + "°", lowX, baseline, dp(11.5f), Color.rgb(224, 242, 235), Paint.Align.RIGHT, true);
            drawText(canvas, day.high + "°", highX, baseline, dp(11.5f), Color.rgb(224, 242, 235), Paint.Align.RIGHT, true);

            calendar.add(Calendar.DAY_OF_YEAR, 1);
        }
        canvas.restoreToCount(save);
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
            float barStart = x + w * 0.53f;
            float barEnd = x + w * 0.82f;
            float highX = x + w;
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

    private void drawWeatherMetricRings(Canvas canvas, float x, float y, float w, float h, WeatherDay today, int todayRain) {
        int uv = today == null ? 0 : today.uv;

        String[] labels = { "湿度", "降水", "紫外线" };
        String[] values = {
            weather.humidity + "%",
            todayRain + "%",
            uv + " " + uvLevel(uv)
        };
        float[] progresses = {
            weather.humidity / 100f,
            todayRain / 100f,
            uv / 11f
        };
        int[] colors = {
            Color.rgb(112, 224, 204),
            Color.rgb(104, 196, 255),
            Color.rgb(255, 215, 105)
        };

        int columns = 3;
        float cellW = w / columns;
        float radius = Math.min(Math.min(cellW, h) * 0.34f, dp(34));

        for (int i = 0; i < labels.length; i++) {
            float cx = x + cellW * (i + 0.5f);
            float cy = y + radius + dp(4);
            drawCircularWeatherMetric(canvas, cx, cy, radius, i, labels[i], values[i], progresses[i], colors[i], true);
        }
    }

    private void drawCircularWeatherMetric(Canvas canvas, float cx, float cy, float radius, int iconType, String label, String value, float progress, int color, boolean showText) {
        float clamped = Math.max(0f, Math.min(1f, progress));
        int brightColor = blendColor(color, Color.WHITE, 0.22f);

        paint.setShader(new RadialGradient(cx, cy, radius + dp(10), Color.argb(18, 255, 255, 255), Color.argb(3, 255, 255, 255), Shader.TileMode.CLAMP));
        canvas.drawCircle(cx, cy, radius + dp(7), paint);
        paint.setShader(null);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(5.4f));
        paint.setColor(Color.argb(22, 220, 235, 228));
        rect.set(cx - radius, cy - radius, cx + radius, cy + radius);
        canvas.drawArc(rect, -90f, 360f, false, paint);

        paint.setStrokeWidth(dp(5.4f));
        paint.setShader(new LinearGradient(cx - radius, cy - radius, cx + radius, cy + radius, brightColor, color, Shader.TileMode.CLAMP));
        canvas.drawArc(rect, -90f, 360f * clamped, false, paint);
        paint.setShader(null);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);

        drawWeatherMetricIcon(canvas, cx, cy, radius * 0.76f, iconType, color);
        if (showText) {
            drawFittedText(canvas, label, cx, cy + radius + dp(17), dp(10.5f), Color.argb(178, 224, 242, 235), Paint.Align.CENTER, false, radius * 2.5f);
            drawFittedText(canvas, value, cx, cy + radius + dp(35), dp(12), Color.argb(220, 238, 250, 246), Paint.Align.CENTER, true, radius * 2.7f);
        }
    }

    private void drawWeatherMetricIcon(Canvas canvas, float cx, float cy, float size, int type, int color) {
        if (type == 0) {
            drawHumidityIcon(canvas, cx, cy, size, color);
        } else if (type == 1) {
            drawSimpleRainIcon(canvas, cx, cy, size * 0.94f, color);
        } else if (type == 2) {
            drawUvIcon(canvas, cx, cy, size, color);
        } else if (type == 3) {
            drawWindIcon(canvas, cx, cy, size, color);
        } else {
            drawTemperatureRangeIcon(canvas, cx, cy, size, color);
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

    private void drawAnimatedClockPanel(Canvas canvas, float x, float y, float w, float h) {
        int save = canvas.save();
        canvas.clipRect(x, y, x + w, y + h);
        float animatedPage = animatedCenterPage();
        for (int page = 0; page < CENTER_PAGE_COUNT; page++) {
            float pageX = x + (page - animatedPage) * w;
            if (pageX > x + w || pageX + w < x) continue;

            if (page == 0) {
                drawClockPanel(canvas, pageX, y, w, h);
            } else {
                drawTimerPanel(canvas, pageX, y, w, h);
            }
        }
        canvas.restoreToCount(save);
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

    private void drawTimerPanel(Canvas canvas, float x, float y, float w, float h) {
        syncTimerRunningState();
        float cx = x + w * 0.5f;
        float radius = Math.min(w * 0.37f, h * 0.36f);
        float cy = y + Math.max(radius + dp(12), h * 0.36f);
        timerCenterX = cx;
        timerCenterY = cy;
        timerRadius = radius;

        float buttonW = Math.min(dp(78), radius * 0.54f);
        float buttonH = dp(48);
        float gap = dp(10);
        float totalW = buttonW * 3f + gap * 2f;
        float buttonY = cy - buttonH * 0.5f;
        timerHourButtonRect.set(cx - totalW * 0.5f, buttonY, cx - totalW * 0.5f + buttonW, buttonY + buttonH);
        timerMinuteButtonRect.set(timerHourButtonRect.right + gap, buttonY, timerHourButtonRect.right + gap + buttonW, buttonY + buttonH);
        timerSecondButtonRect.set(timerMinuteButtonRect.right + gap, buttonY, timerMinuteButtonRect.right + gap + buttonW, buttonY + buttonH);

        int displayUnit = timerDisplayUnit();
        int activeColor = displayUnit >= 0 ? timerUnitColor(displayUnit) : Color.rgb(255, 179, 0);
        drawTimerRing(canvas, cx, cy, radius, activeColor);
        drawTimerCountdownRings(canvas, cx, cy, radius, true);
        if (timerRotating) {
            drawTimerRotationArrows(canvas, cx, cy, radius);
        }
        if (timerRotating && timerActiveUnit >= 0) {
            drawTimerTickValue(canvas, cx, cy, radius, activeColor);
        }

        drawTimerButton(canvas, timerHourButtonRect, "时", timerHours, 0);
        drawTimerButton(canvas, timerMinuteButtonRect, "分", timerMinutes, 1);
        drawTimerButton(canvas, timerSecondButtonRect, "秒", timerSeconds, 2);

        drawText(canvas, "定时器", cx, y + h - dp(78), dp(18), Color.argb(190, 224, 242, 235), Paint.Align.CENTER, true);
        drawTimerStartButton(canvas, cx, y + h - dp(37), Math.min(w * 0.48f, dp(190)), dp(50));
    }

    private void drawTimerRing(Canvas canvas, float cx, float cy, float radius, int activeColor) {
        int displayUnit = timerDisplayUnit();
        float value = timerDisplayValue();
        int units = displayUnit == 0 ? 12 : 60;
        float angleValue = displayUnit == 0
            ? (value <= 0f ? 0f : (((value - 1f) % 12f) + 1f) / 12f)
            : value / 60f;
        float highlightAlpha = timerValueHighlightAlpha();

        rect.set(cx - radius, cy - radius, cx + radius, cy + radius);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(9.5f));
        paint.setColor(displayUnit >= 0 ? Color.argb(58, Color.red(activeColor), Color.green(activeColor), Color.blue(activeColor)) : Color.argb(22, 248, 248, 250));
        canvas.drawArc(rect, -90f, 360f, false, paint);
        if (displayUnit >= 0 && angleValue > 0f && highlightAlpha > 0f) {
            paint.setColor(alphaColor(activeColor, Math.round(165f * highlightAlpha)));
            canvas.drawArc(rect, -90f, 360f * angleValue, false, paint);
        }

        paint.setStrokeWidth(dp(2.1f));
        float activeTickFloat = displayUnit == 0
            ? (value <= 0f ? 0f : ((value - 1f) % 12f) + 1f)
            : value;
        for (int i = 0; i < units; i++) {
            double angle = Math.toRadians(i * (360f / units) - 90f);
            float tickDistance = timerCircularDistance(i, activeTickFloat, units);
            float emphasis = displayUnit >= 0 ? Math.max(0f, 1f - tickDistance) * highlightAlpha : 0f;
            float outer = radius * 0.99f + dp(8) * emphasis;
            float baseInner = radius * (i % (units == 12 ? 1 : 5) == 0 ? 0.91f : 0.94f);
            float inner = baseInner - dp(8) * emphasis;
            float startX = cx + (float) Math.cos(angle) * inner;
            float startY = cy + (float) Math.sin(angle) * inner;
            float endX = cx + (float) Math.cos(angle) * outer;
            float endY = cy + (float) Math.sin(angle) * outer;
            paint.setStrokeWidth(dp(2.1f + 1.5f * emphasis));
            paint.setColor(emphasis > 0f ? Color.argb(Math.round(210 + 45 * emphasis), 248, 248, 250) : i % (units == 12 ? 1 : 5) == 0 ? Color.argb(230, 248, 248, 250) : Color.argb(132, 248, 248, 250));
            canvas.drawLine(startX, startY, endX, endY, paint);
        }
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawTimerButton(Canvas canvas, RectF button, String label, int value, int unit) {
        int color = timerUnitColor(unit);
        boolean active = timerRotating && timerActiveUnit == unit;
        float cx = button.centerX();
        float cy = button.centerY();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(active ? alphaColor(color, 78) : Color.argb(28, 255, 255, 255));
        canvas.drawRoundRect(button, dp(9), dp(9), paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1));
        paint.setColor(active ? alphaColor(color, 210) : Color.argb(38, 255, 255, 255));
        canvas.drawRoundRect(button, dp(9), dp(9), paint);
        paint.setStyle(Paint.Style.FILL);

        drawText(canvas, String.format(Locale.CHINA, "%02d", value), cx, cy - dp(1), dp(20), Color.rgb(238, 250, 246), Paint.Align.CENTER, true);
        drawText(canvas, label, cx, cy + dp(17), dp(10.5f), active ? color : Color.argb(170, 224, 242, 235), Paint.Align.CENTER, true);
    }

    private void drawTimerStartButton(Canvas canvas, float cx, float cy, float w, float h) {
        float left = cx - w * 0.5f;
        float top = cy - h * 0.5f;
        rect.set(left, top, left + w, top + h);
        timerStartButtonRect.set(rect);
        int color = timerRunning ? Color.rgb(255, 136, 94) : timerTotalSeconds() > 0 ? Color.rgb(100, 220, 205) : Color.argb(170, 224, 242, 235);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(timerRunning ? Color.argb(46, 255, 136, 94) : timerTotalSeconds() > 0 ? Color.argb(38, 100, 220, 205) : Color.argb(22, 255, 255, 255));
        canvas.drawRoundRect(rect, h * 0.5f, h * 0.5f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1.2f));
        paint.setColor(timerRunning ? Color.argb(135, 255, 136, 94) : timerTotalSeconds() > 0 ? Color.argb(130, 100, 220, 205) : Color.argb(42, 255, 255, 255));
        canvas.drawRoundRect(rect, h * 0.5f, h * 0.5f, paint);
        paint.setStyle(Paint.Style.FILL);

        drawText(canvas, timerRunning ? "清零" : timerTotalSeconds() > 0 ? "开始 " + String.format(Locale.CHINA, "%02d:%02d:%02d", timerHours, timerMinutes, timerSeconds) : "开始", cx, cy + dp(6), dp(18), color, Paint.Align.CENTER, true);
    }

    private void drawTimerRotationArrows(Canvas canvas, float cx, float cy, float radius) {
        float alpha = timerArrowAlpha();
        if (alpha <= 0f) return;
        int color = Color.argb(Math.round(92f * alpha), 248, 248, 250);
        float arrowRadius = radius + dp(24);
        drawRingArrow(canvas, cx, cy, arrowRadius, 145f, 72f, color);
        drawRingArrow(canvas, cx, cy, arrowRadius, -45f, 90f, color);
    }

    private void drawRingArrow(Canvas canvas, float cx, float cy, float radius, float startAngle, float sweep, int color) {
        RectF arrowRect = new RectF(cx - radius, cy - radius, cx + radius, cy + radius);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(2.4f));
        paint.setColor(color);
        canvas.drawArc(arrowRect, startAngle, sweep, false, paint);

        double end = Math.toRadians(startAngle + sweep);
        float endX = cx + (float) Math.cos(end) * radius;
        float endY = cy + (float) Math.sin(end) * radius;
        double tangent = end + (sweep >= 0f ? Math.toRadians(90) : -Math.toRadians(90));
        double a1 = tangent + Math.toRadians(150);
        double a2 = tangent - Math.toRadians(150);
        canvas.drawLine(endX, endY, endX + (float) Math.cos(a1) * dp(8), endY + (float) Math.sin(a1) * dp(8), paint);
        canvas.drawLine(endX, endY, endX + (float) Math.cos(a2) * dp(8), endY + (float) Math.sin(a2) * dp(8), paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawTimerCountdownRings(Canvas canvas, float cx, float cy, float radius, boolean onTimerPage) {
        if (!timerRunning) return;

        float alpha = timerCountdownVisualAlpha();
        if (alpha <= 0f) return;

        float remaining = Math.max(0f, (timerEndsAtMillis - System.currentTimeMillis()) / 1000f);
        if (remaining <= 0f) return;

        float hourValue = countdownParentValue(remaining, 3600f, 11.999f);
        float minuteValue = countdownParentValue(remaining % 3600f, 60f, 59f);
        float secondValue = remaining % 60f;
        float baseRadius = onTimerPage ? radius * 0.73f : radius * 0.71f;
        float gap = onTimerPage ? dp(8.4f) : dp(7.4f);
        float stroke = onTimerPage ? dp(4.2f) : dp(3.7f);

        drawCountdownUnitRing(canvas, cx, cy, baseRadius, hourValue, 12f, timerUnitColor(0), alpha, stroke);
        drawCountdownUnitRing(canvas, cx, cy, baseRadius + gap, minuteValue, 60f, timerUnitColor(1), alpha, stroke);
        drawCountdownUnitRing(canvas, cx, cy, baseRadius + gap * 2f, secondValue, 60f, timerUnitColor(2), alpha, stroke);
    }

    private void drawCountdownUnitRing(Canvas canvas, float cx, float cy, float r, float value, float scale, int color, float alpha, float stroke) {
        if (value <= 0.01f) return;

        float normalized = value % scale;
        if (normalized <= 0.01f) normalized = scale;
        float fraction = Math.max(0f, Math.min(1f, normalized / scale));
        float cycleAlpha = scale >= 60f && normalized > scale - 0.6f ? clamp((scale - normalized) / 0.6f, 0f, 1f) : 1f;
        rect.set(cx - r, cy - r, cx + r, cy + r);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(stroke);
        paint.setColor(alphaColor(color, Math.round(185f * alpha * cycleAlpha)));
        canvas.drawArc(rect, -90f, 360f * fraction, false, paint);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private float countdownParentValue(float seconds, float unitSeconds, float maxValue) {
        float raw = seconds / unitSeconds;
        int floor = (int) Math.floor(raw);
        float value = Math.min(maxValue, floor);
        float remainder = seconds - floor * unitSeconds;
        float transitionSeconds = 0.85f;
        float sinceDrop = unitSeconds - remainder;
        if (sinceDrop >= 0f && sinceDrop < transitionSeconds) {
            float t = sinceDrop / transitionSeconds;
            float extra = 1f - t * t;
            value = floor + extra;
        }
        if (floor <= 0 && sinceDrop >= transitionSeconds) return 0f;
        return Math.min(maxValue, value);
    }

    private float timerCountdownVisualAlpha() {
        if (!timerRunning) return 0f;
        float t = (SystemClock.uptimeMillis() - timerVisualStartedAt) / (float) RIGHT_PAGE_ANIMATION_MS;
        return easeOutCubic(Math.max(0f, Math.min(1f, t)));
    }

    private float timerArrowAlpha() {
        long now = SystemClock.uptimeMillis();
        if (timerClockwiseStarted) {
            float t = (now - timerArrowFadeOutStartedAt) / (float) TIMER_ARROW_FADE_MS;
            return Math.max(0f, 1f - t);
        }
        float t = (now - timerAdjustmentStartedAt) / (float) TIMER_ARROW_FADE_MS;
        return Math.max(0f, Math.min(1f, t));
    }

    private float timerValueHighlightAlpha() {
        if (timerRotating) return 1f;
        long now = SystemClock.uptimeMillis();
        if (timerFadingUnit < 0) return 0f;
        float t = (now - timerValueFadeOutStartedAt) / (float) TIMER_ARROW_FADE_MS;
        return Math.max(0f, 1f - t);
    }

    private int timerDisplayUnit() {
        if (timerActiveUnit >= 0) return timerActiveUnit;
        if (timerFadingUnit >= 0 && timerValueHighlightAlpha() > 0f) return timerFadingUnit;
        return -1;
    }

    private float timerDisplayValue() {
        if (timerActiveUnit >= 0) return timerContinuousValue;
        if (timerFadingUnit >= 0) return timerFadingValue;
        return 0f;
    }

    private float timerCircularDistance(float a, float b, int units) {
        float diff = Math.abs(a - b);
        return Math.min(diff, units - diff);
    }

    private float easeOutCubic(float t) {
        float clamped = Math.max(0f, Math.min(1f, t));
        return 1f - (1f - clamped) * (1f - clamped) * (1f - clamped);
    }

    private void drawTimerTickValue(Canvas canvas, float cx, float cy, float radius, int color) {
        int value = timerValue(timerActiveUnit);
        int units = timerActiveUnit == 0 ? 12 : 60;
        int tick = timerActiveUnit == 0 ? (value == 0 ? 0 : ((value - 1) % 12) + 1) : value;
        float angleDeg = tick * (360f / units) - 90f;
        double angle = Math.toRadians(angleDeg);
        float tx = cx + (float) Math.cos(angle) * (radius + dp(34));
        float ty = cy + (float) Math.sin(angle) * (radius + dp(34));
        paint.setColor(alphaColor(color, 85));
        canvas.drawCircle(tx, ty, dp(16), paint);
        drawCenteredText(canvas, String.valueOf(value), tx, ty, dp(13), Color.rgb(248, 248, 250), true);
    }

    private int timerTotalSeconds() {
        return timerHours * 3600 + timerMinutes * 60 + timerSeconds;
    }

    private int timerUnitColor(int unit) {
        if (unit == 0) return Color.rgb(255, 205, 94);
        if (unit == 1) return Color.rgb(100, 220, 205);
        return Color.rgb(255, 136, 94);
    }

    private void drawTimerFinishedOverlay(Canvas canvas, float width, float height) {
        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(0, 0, 0));
        canvas.drawRect(0, 0, width, height, paint);

        float cx = width * 0.5f;
        float cy = height * 0.44f;
        long elapsed = Math.max(0L, SystemClock.uptimeMillis() - timerFinishedStartedAt);
        long cycle = TIMER_FINISHED_SHAKE_MS + TIMER_FINISHED_PAUSE_MS;
        float phase = (elapsed % cycle) / (float) cycle;
        float rotate = 0f;
        float scale = 1f;
        if (phase < TIMER_FINISHED_SHAKE_MS / (float) cycle) {
            float t = phase * cycle / (float) TIMER_FINISHED_SHAKE_MS;
            float envelope = (float) Math.sin(t * Math.PI);
            float wave = (float) Math.sin(t * Math.PI * 10f) * envelope;
            rotate = wave * 12f;
            scale = 1f + 0.07f * Math.abs(wave);
        }

        int save = canvas.save();
        canvas.translate(cx, cy - dp(42));
        canvas.scale(scale, scale);
        canvas.rotate(rotate);
        drawTimerBellIcon(canvas, 0f, 0f, dp(72), Color.rgb(255, 205, 94));
        canvas.restoreToCount(save);

        drawCenteredText(canvas, "时间到", cx, cy + dp(54), dp(44), Color.rgb(238, 250, 246), true);
        drawText(canvas, "轻触屏幕关闭", cx, cy + dp(96), dp(15), Color.argb(170, 224, 242, 235), Paint.Align.CENTER, false);
    }

    private void drawTimerBellIcon(Canvas canvas, float cx, float cy, float size, int color) {
        int outline = Color.rgb(20, 34, 48);
        int keyline = Color.rgb(238, 250, 246);
        int fill = Color.rgb(252, 219, 122);
        int brim = Color.rgb(103, 205, 218);
        float stroke = size * 0.055f;

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        rect.set(cx - size * 0.11f, cy - size * 0.62f, cx + size * 0.11f, cy - size * 0.20f);
        paint.setStrokeWidth(stroke * 1.8f);
        paint.setColor(keyline);
        canvas.drawRoundRect(rect, size * 0.11f, size * 0.11f, paint);
        paint.setStrokeWidth(stroke);
        paint.setColor(outline);
        canvas.drawRoundRect(rect, size * 0.11f, size * 0.11f, paint);

        android.graphics.Path bell = new android.graphics.Path();
        bell.moveTo(cx - size * 0.42f, cy + size * 0.17f);
        bell.cubicTo(cx - size * 0.38f, cy - size * 0.30f, cx - size * 0.24f, cy - size * 0.50f, cx, cy - size * 0.50f);
        bell.cubicTo(cx + size * 0.24f, cy - size * 0.50f, cx + size * 0.38f, cy - size * 0.30f, cx + size * 0.42f, cy + size * 0.17f);
        bell.lineTo(cx + size * 0.49f, cy + size * 0.30f);
        bell.lineTo(cx - size * 0.49f, cy + size * 0.30f);
        bell.close();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(fill);
        canvas.drawPath(bell, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(stroke * 1.75f);
        paint.setColor(keyline);
        canvas.drawPath(bell, paint);
        paint.setStrokeWidth(stroke);
        paint.setColor(outline);
        canvas.drawPath(bell, paint);

        rect.set(cx - size * 0.55f, cy + size * 0.25f, cx + size * 0.55f, cy + size * 0.39f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(brim);
        canvas.drawRoundRect(rect, size * 0.07f, size * 0.07f, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(stroke * 1.75f);
        paint.setColor(keyline);
        canvas.drawRoundRect(rect, size * 0.07f, size * 0.07f, paint);
        paint.setStrokeWidth(stroke);
        paint.setColor(outline);
        canvas.drawRoundRect(rect, size * 0.07f, size * 0.07f, paint);

        rect.set(cx - size * 0.16f, cy + size * 0.34f, cx + size * 0.16f, cy + size * 0.66f);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(fill);
        canvas.drawOval(rect, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(stroke * 1.75f);
        paint.setColor(keyline);
        canvas.drawOval(rect, paint);
        paint.setStrokeWidth(stroke);
        paint.setColor(outline);
        canvas.drawOval(rect, paint);

        android.graphics.Path shine = new android.graphics.Path();
        shine.moveTo(cx - size * 0.29f, cy - size * 0.22f);
        shine.cubicTo(cx - size * 0.23f, cy - size * 0.36f, cx - size * 0.12f, cy - size * 0.42f, cx - size * 0.02f, cy - size * 0.43f);
        paint.setColor(Color.argb(215, 255, 255, 255));
        paint.setStrokeWidth(size * 0.045f);
        canvas.drawPath(shine, paint);
        canvas.drawLine(cx - size * 0.34f, cy - size * 0.08f, cx - size * 0.34f, cy + size * 0.02f, paint);

        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStyle(Paint.Style.FILL);
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
        drawSimpleRainIcon(canvas, x + w * 0.70f, weatherCenterY, dp(25), Color.rgb(104, 196, 255));
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

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(46, Color.red(color), Color.green(color), Color.blue(color)));
        canvas.drawPath(path, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeWidth(dp(2.2f));
        paint.setColor(Color.argb(230, Color.red(color), Color.green(color), Color.blue(color)));
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

    private void drawHumidityIcon(Canvas canvas, float cx, float cy, float size, int color) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(2f));
        paint.setColor(Color.argb(232, Color.red(color), Color.green(color), Color.blue(color)));
        canvas.drawLine(cx - size * 0.43f, cy - size * 0.36f, cx + size * 0.24f, cy - size * 0.36f, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(210, 238, 250, 246));
        float dotR = Math.max(dp(1.15f), size * 0.045f);
        float[][] dots = {
            { -0.32f, -0.12f }, { -0.10f, -0.12f }, { 0.10f, -0.10f },
            { -0.23f, 0.08f }, { -0.02f, 0.08f }, { 0.20f, 0.08f },
            { -0.34f, 0.27f }, { -0.12f, 0.27f }, { 0.08f, 0.27f }
        };
        for (float[] dot : dots) {
            canvas.drawCircle(cx + dot[0] * size, cy + dot[1] * size, dotR, paint);
        }

        android.graphics.Path drop = new android.graphics.Path();
        float dx = cx + size * 0.33f;
        float dy = cy + size * 0.14f;
        float ds = size * 0.60f;
        drop.moveTo(dx, dy - ds * 0.42f);
        drop.cubicTo(dx + ds * 0.28f, dy - ds * 0.10f, dx + ds * 0.38f, dy + ds * 0.12f, dx + ds * 0.23f, dy + ds * 0.32f);
        drop.cubicTo(dx + ds * 0.10f, dy + ds * 0.48f, dx - ds * 0.10f, dy + ds * 0.48f, dx - ds * 0.23f, dy + ds * 0.32f);
        drop.cubicTo(dx - ds * 0.38f, dy + ds * 0.12f, dx - ds * 0.28f, dy - ds * 0.10f, dx, dy - ds * 0.42f);
        drop.close();

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(44, Color.red(color), Color.green(color), Color.blue(color)));
        canvas.drawPath(drop, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeWidth(dp(1.8f));
        paint.setColor(Color.argb(232, Color.red(color), Color.green(color), Color.blue(color)));
        canvas.drawPath(drop, paint);

        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawUvIcon(Canvas canvas, float cx, float cy, float size, int color) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(1.8f));
        paint.setColor(Color.argb(228, Color.red(color), Color.green(color), Color.blue(color)));

        float rayInner = size * 0.31f;
        float rayOuter = size * 0.48f;
        for (int i = 0; i < 8; i++) {
            double angle = Math.toRadians(i * 45d);
            float sx = cx + (float) Math.cos(angle) * rayInner;
            float sy = cy + (float) Math.sin(angle) * rayInner;
            float ex = cx + (float) Math.cos(angle) * rayOuter;
            float ey = cy + (float) Math.sin(angle) * rayOuter;
            canvas.drawLine(sx, sy, ex, ey, paint);
        }

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(56, Color.red(color), Color.green(color), Color.blue(color)));
        canvas.drawCircle(cx, cy, size * 0.23f, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(2f));
        paint.setColor(Color.argb(235, Color.red(color), Color.green(color), Color.blue(color)));
        canvas.drawCircle(cx, cy, size * 0.23f, paint);

        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawWindIcon(Canvas canvas, float cx, float cy, float size, int color) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(dp(1.9f));
        paint.setColor(Color.argb(232, Color.red(color), Color.green(color), Color.blue(color)));

        canvas.drawLine(cx - size * 0.42f, cy - size * 0.18f, cx + size * 0.22f, cy - size * 0.18f, paint);
        canvas.drawArc(new RectF(cx + size * 0.14f, cy - size * 0.32f, cx + size * 0.43f, cy - size * 0.04f), -90f, 210f, false, paint);
        canvas.drawLine(cx - size * 0.34f, cy + size * 0.04f, cx + size * 0.34f, cy + size * 0.04f, paint);
        canvas.drawArc(new RectF(cx + size * 0.26f, cy - size * 0.08f, cx + size * 0.50f, cy + size * 0.17f), -80f, 190f, false, paint);
        canvas.drawLine(cx - size * 0.22f, cy + size * 0.25f, cx + size * 0.20f, cy + size * 0.25f, paint);

        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawTemperatureRangeIcon(Canvas canvas, float cx, float cy, float size, int color) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeWidth(dp(1.9f));
        paint.setColor(Color.argb(232, Color.red(color), Color.green(color), Color.blue(color)));

        float leftX = cx - size * 0.18f;
        canvas.drawLine(leftX, cy - size * 0.38f, leftX, cy + size * 0.18f, paint);
        canvas.drawCircle(leftX, cy + size * 0.28f, size * 0.13f, paint);
        canvas.drawLine(leftX, cy - size * 0.38f, leftX + size * 0.12f, cy - size * 0.38f, paint);
        canvas.drawLine(leftX, cy - size * 0.12f, leftX + size * 0.09f, cy - size * 0.12f, paint);

        android.graphics.Path arrow = new android.graphics.Path();
        arrow.moveTo(cx + size * 0.12f, cy + size * 0.25f);
        arrow.lineTo(cx + size * 0.38f, cy - size * 0.22f);
        arrow.lineTo(cx + size * 0.40f, cy + size * 0.03f);
        arrow.moveTo(cx + size * 0.38f, cy - size * 0.22f);
        arrow.lineTo(cx + size * 0.14f, cy - size * 0.18f);
        canvas.drawPath(arrow, paint);

        paint.setStrokeJoin(Paint.Join.MITER);
        paint.setStrokeCap(Paint.Cap.BUTT);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawAnalogClock(Canvas canvas, float cx, float cy, float radius) {
        syncTimerRunningState();
        Calendar now = Calendar.getInstance(Locale.CHINA);
        long nowMillis = System.currentTimeMillis();
        now.setTimeInMillis(nowMillis);

        drawAppleClockMarks(canvas, cx, cy, radius);
        drawTimerCountdownRings(canvas, cx, cy, radius, false);

        float timerAlpha = timerCountdownVisualAlpha();
        int numberAlpha = Math.round(248f * (1f - timerAlpha));
        for (int i = 1; i <= 12; i++) {
            double angle = Math.toRadians(i * 30 - 90);
            float numberSize = dp(20.5f);
            float tx = cx + (float) Math.cos(angle) * radius * 0.78f;
            float ty = cy + (float) Math.sin(angle) * radius * 0.78f + numberSize * 0.34f;
            if (numberAlpha > 0) {
                drawText(canvas, String.valueOf(i), tx, ty, numberSize, Color.argb(numberAlpha, 248, 248, 250), Paint.Align.CENTER, true);
            }
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
        float headerCenterY = y + dp(21);
        drawText(canvas, title, x + pad, headerCenterY + dp(5), dp(14), Color.argb(190, 224, 242, 235), Paint.Align.LEFT, true);
        drawPageDots(canvas, x + w - pad - dp(18), headerCenterY, dp(3.2f), dp(12));

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

        int refreshSave = canvas.save();
        canvas.translate(0f, weatherRefreshOffset(1));

        if (tomorrow == null) {
            drawText(canvas, weatherStatus == null || weatherStatus.isEmpty() ? "等待天气数据" : weatherStatus,
                x + w * 0.5f,
                y + h * 0.5f,
                dp(18),
                Color.rgb(238, 250, 246),
                Paint.Align.CENTER,
                true
            );
            canvas.restoreToCount(refreshSave);
            return;
        }

        float headCenterY = y + dp(36);
        drawCyclingColorWeatherIcon(canvas, x + dp(28), headCenterY, dp(42), tomorrow.code);
        drawText(canvas, tomorrow.description, x + dp(58), headCenterY + dp(6), dp(18), Color.WHITE, Paint.Align.LEFT, true);
        drawText(canvas, tomorrow.high + "°/" + tomorrow.low + "°", x + w - dp(12), headCenterY + dp(8), dp(22), Color.WHITE, Paint.Align.RIGHT, true);

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
        canvas.restoreToCount(refreshSave);
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

    private int blendColor(int from, int to, float amount) {
        float t = Math.max(0f, Math.min(1f, amount));
        int r = Math.round(Color.red(from) + (Color.red(to) - Color.red(from)) * t);
        int g = Math.round(Color.green(from) + (Color.green(to) - Color.green(from)) * t);
        int b = Math.round(Color.blue(from) + (Color.blue(to) - Color.blue(from)) * t);
        return Color.rgb(r, g, b);
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
        void onWeatherRefreshRequested();
    }
}
