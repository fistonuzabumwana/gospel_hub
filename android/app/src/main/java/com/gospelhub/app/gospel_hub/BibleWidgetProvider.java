package com.gospelhub.app.gospel_hub;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.widget.RemoteViews;

public class BibleWidgetProvider extends AppWidgetProvider {

    private static final String TAG = "BibleWidgetProvider";

    public static final String ACTION_PREV_VERSE = "com.gospelhub.app.ACTION_PREV_VERSE";
    public static final String ACTION_NEXT_VERSE = "com.gospelhub.app.ACTION_NEXT_VERSE";

    private static final int PI_REQUEST_PREV = 1;
    private static final int PI_REQUEST_NEXT = 2;
    private static final int PI_REQUEST_OPEN_APP = 3;

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, true);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (AppWidgetManager.ACTION_APPWIDGET_UPDATE.equals(action)) {
            PendingResult pendingResult = goAsync();
            new Thread(() -> {
                try {
                    super.onReceive(context, intent);
                } catch (Exception e) {
                    Log.e(TAG, "APPWIDGET_UPDATE failed", e);
                } finally {
                    pendingResult.finish();
                }
            }).start();
            return;
        }

        super.onReceive(context, intent);

        if (ACTION_PREV_VERSE.equals(action) || ACTION_NEXT_VERSE.equals(action)) {
            SharedPreferences sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            long count = getSafeLong(sp, "flutter.widget_verses_count", 0L);
            if (count > 0) {
                long currentIndex = getSafeLong(sp, "flutter.widget_verse_index", 0L);
                if (ACTION_PREV_VERSE.equals(action)) {
                    currentIndex = (currentIndex - 1 + count) % count;
                } else {
                    currentIndex = (currentIndex + 1) % count;
                }
                sp.edit().putInt("flutter.widget_verse_index", (int) currentIndex).apply();
            }

            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
            int[] appWidgetIds = appWidgetManager.getAppWidgetIds(new ComponentName(context, BibleWidgetProvider.class));
            onUpdate(context, appWidgetManager, appWidgetIds);
        }
    }

    @Override
    public void onAppWidgetOptionsChanged(
            Context context,
            AppWidgetManager appWidgetManager,
            int appWidgetId,
            Bundle newOptions) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions);
        updateAppWidget(context, appWidgetManager, appWidgetId, false);
    }

    private static void updateAppWidget(
            Context context,
            AppWidgetManager appWidgetManager,
            int appWidgetId,
            boolean syncGridHeight) {
        try {
            RemoteViews views = buildRemoteViews(context, appWidgetManager, appWidgetId, syncGridHeight);
            appWidgetManager.updateAppWidget(appWidgetId, views);
        } catch (Exception e) {
            Log.e(TAG, "updateAppWidget failed for id " + appWidgetId, e);
            try {
                RemoteViews fallback = new RemoteViews(context.getPackageName(), R.layout.bible_widget);
                appWidgetManager.updateAppWidget(appWidgetId, fallback);
            } catch (Exception fallbackError) {
                Log.e(TAG, "fallback update failed", fallbackError);
            }
        }
    }

    private static RemoteViews buildRemoteViews(
            Context context,
            AppWidgetManager appWidgetManager,
            int appWidgetId,
            boolean syncGridHeight) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.bible_widget);

        SharedPreferences sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);

        String lang = getSafeString(sp, "flutter.widget_language", "rw");
        long count = getSafeLong(sp, "flutter.widget_verses_count", 0L);
        long index = getSafeLong(sp, "flutter.widget_verse_index", 0L);

        String ref = "";
        String text = "";

        if (count > 0 && index >= 0 && index < count) {
            ref = getSafeString(sp, "flutter.widget_verse_ref_" + lang + "_" + index, "");
            text = getSafeString(sp, "flutter.widget_verse_text_" + lang + "_" + index, "");
        }

        if (ref.isEmpty() || text.isEmpty()) {
            if ("en".equals(lang)) {
                ref = "John 3:16";
                text = "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.";
            } else {
                ref = "Yohana 3:16";
                text = "Kuko Imana yakunze abari mu isi cyane, ikabasaba Umwana wayo w'ikinege ngo umwizera wese atarimbuka, ahubwo ahabwe ubugingo buhoraho.";
            }
        }

        applyBackgroundOpacity(views, getSafeFloat(sp, "flutter.widget_opacity", 1.0f));

        String fontStyle = getSafeString(sp, "flutter.widget_font_style", "serif");
        float fontSize = getSafeFloat(sp, "flutter.widget_font_size", 14.5f);

        int activeTextId;
        int inactiveId1;
        int inactiveId2;

        if ("sans".equals(fontStyle)) {
            activeTextId = R.id.widget_verse_text_sans;
            inactiveId1 = R.id.widget_verse_text_serif;
            inactiveId2 = R.id.widget_verse_text_mono;
        } else if ("mono".equals(fontStyle)) {
            activeTextId = R.id.widget_verse_text_mono;
            inactiveId1 = R.id.widget_verse_text_sans;
            inactiveId2 = R.id.widget_verse_text_serif;
        } else {
            activeTextId = R.id.widget_verse_text_serif;
            inactiveId1 = R.id.widget_verse_text_sans;
            inactiveId2 = R.id.widget_verse_text_mono;
        }

        views.setViewVisibility(activeTextId, View.VISIBLE);
        views.setViewVisibility(inactiveId1, View.GONE);
        views.setViewVisibility(inactiveId2, View.GONE);

        views.setTextViewText(activeTextId, text);
        views.setTextViewTextSize(activeTextId, TypedValue.COMPLEX_UNIT_SP, fontSize);
        views.setTextViewText(R.id.widget_verse_ref, ref);

        int heightDp = estimateWidgetHeightDp(appWidgetManager, appWidgetId, text, fontSize);
        applyWidgetHeight(views, heightDp);
        if (syncGridHeight) {
            requestWidgetHeight(appWidgetManager, appWidgetId, heightDp);
        }

        Intent intentPrev = new Intent(context, BibleWidgetProvider.class);
        intentPrev.setAction(ACTION_PREV_VERSE);
        PendingIntent piPrev = PendingIntent.getBroadcast(context, PI_REQUEST_PREV, intentPrev,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_btn_prev, piPrev);

        Intent intentNext = new Intent(context, BibleWidgetProvider.class);
        intentNext.setAction(ACTION_NEXT_VERSE);
        PendingIntent piNext = PendingIntent.getBroadcast(context, PI_REQUEST_NEXT, intentNext,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_btn_next, piNext);

        Intent intentApp = new Intent(context, MainActivity.class);
        PendingIntent piApp = PendingIntent.getActivity(context, PI_REQUEST_OPEN_APP, intentApp,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_card, piApp);

        return views;
    }

    private static final int WIDGET_BG_RGB = 0x001A1C1A;

    /** Padding + header row + gap above verse (dp). */
    private static final int WIDGET_CHROME_HEIGHT_DP = 12 + 10 + 38 + 8;

    private static int estimateWidgetHeightDp(
            AppWidgetManager appWidgetManager,
            int appWidgetId,
            String text,
            float fontSizeSp) {
        Bundle opts = appWidgetManager.getAppWidgetOptions(appWidgetId);
        int widthDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250);
        if (widthDp <= 0) {
            widthDp = 250;
        }

        int charsPerLine = Math.max(12, (int) (widthDp / (fontSizeSp * 0.52f)));
        int lines = 1;
        if (text != null && !text.isEmpty()) {
            lines = (int) Math.ceil((double) text.length() / (double) charsPerLine);
        }
        lines = Math.max(1, Math.min(4, lines));

        int lineHeightDp = Math.max(16, Math.round(fontSizeSp * 1.32f));
        int height = WIDGET_CHROME_HEIGHT_DP + (lines * lineHeightDp) + 2;
        return Math.max(72, Math.min(height, 220));
    }

    private static void requestWidgetHeight(
            AppWidgetManager appWidgetManager,
            int appWidgetId,
            int heightDp) {
        try {
            Bundle opts = appWidgetManager.getAppWidgetOptions(appWidgetId);
            int currentMin = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, -1);
            int currentMax = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, -1);
            if (currentMin == heightDp && currentMax == heightDp) {
                return;
            }
            Bundle options = new Bundle();
            options.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, heightDp);
            options.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, heightDp);
            appWidgetManager.updateAppWidgetOptions(appWidgetId, options);
        } catch (Exception e) {
            Log.w(TAG, "updateAppWidgetOptions height failed", e);
        }
    }

    private static void applyWidgetHeight(RemoteViews views, int heightDp) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return;
        }
        try {
            views.setViewLayoutHeight(
                    R.id.widget_root,
                    heightDp,
                    TypedValue.COMPLEX_UNIT_DIP);
            views.setViewLayoutHeight(
                    R.id.widget_card,
                    heightDp,
                    TypedValue.COMPLEX_UNIT_DIP);
        } catch (Exception e) {
            Log.w(TAG, "setViewLayoutHeight failed", e);
        }
    }

    private static void applyBackgroundOpacity(RemoteViews views, float opacity) {
        float clamped = Math.max(0.1f, Math.min(1.0f, opacity));
        int alpha = Math.round(clamped * 255f);
        int color = (alpha << 24) | (WIDGET_BG_RGB & 0x00FFFFFF);
        try {
            views.setInt(R.id.widget_background_img, "setBackgroundColor", color);
        } catch (Exception e) {
            Log.w(TAG, "setBackgroundColor failed", e);
        }
    }

    private static String getSafeString(SharedPreferences sp, String key, String defaultValue) {
        try {
            String value = sp.getString(key, defaultValue);
            return value != null ? value : defaultValue;
        } catch (ClassCastException e) {
            try {
                Object raw = sp.getAll().get(key);
                if (raw != null) {
                    return String.valueOf(raw);
                }
            } catch (Exception ignored) {
            }
        }
        return defaultValue;
    }

    private static float getSafeFloat(SharedPreferences sp, String key, float defaultValue) {
        try {
            Object raw = sp.getAll().get(key);
            if (raw instanceof Double) {
                return ((Double) raw).floatValue();
            }
            if (raw instanceof Float) {
                return (Float) raw;
            }
            if (raw instanceof Integer) {
                return ((Integer) raw).floatValue();
            }
            if (raw instanceof Long) {
                return ((Long) raw).floatValue();
            }
            if (raw instanceof String) {
                return Float.parseFloat((String) raw);
            }
        } catch (Exception ignored) {
        }
        try {
            String valStr = sp.getString(key, null);
            if (valStr != null) {
                return Float.parseFloat(valStr);
            }
        } catch (ClassCastException e) {
            try {
                return sp.getFloat(key, defaultValue);
            } catch (Exception ignored) {
            }
        } catch (Exception ignored) {
        }
        return defaultValue;
    }

    private static long getSafeLong(SharedPreferences sp, String key, long defaultValue) {
        try {
            return sp.getLong(key, defaultValue);
        } catch (ClassCastException e) {
            try {
                return sp.getInt(key, (int) defaultValue);
            } catch (ClassCastException ex) {
                try {
                    String valStr = sp.getString(key, null);
                    if (valStr != null) {
                        return Long.parseLong(valStr);
                    }
                } catch (Exception ignored) {
                }
            }
        }
        return defaultValue;
    }
}
