package com.gospelhub.app.gospel_hub;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

public class BibleWidgetProvider extends AppWidgetProvider {

    public static final String ACTION_PREV_VERSE = "com.gospelhub.app.ACTION_PREV_VERSE";
    public static final String ACTION_NEXT_VERSE = "com.gospelhub.app.ACTION_NEXT_VERSE";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);

        String action = intent.getAction();
        if (ACTION_PREV_VERSE.equals(action) || ACTION_NEXT_VERSE.equals(action)) {
            SharedPreferences sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            long count = sp.getLong("flutter.widget_verses_count", 0L);
            if (count > 0) {
                long currentIndex = sp.getLong("flutter.widget_verse_index", 0L);
                if (ACTION_PREV_VERSE.equals(action)) {
                    currentIndex = (currentIndex - 1 + count) % count;
                } else {
                    currentIndex = (currentIndex + 1) % count;
                }
                sp.edit().putLong("flutter.widget_verse_index", currentIndex).apply();
            }

            // Force update all widgets
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
            int[] appWidgetIds = appWidgetManager.getAppWidgetIds(new ComponentName(context, BibleWidgetProvider.class));
            onUpdate(context, appWidgetManager, appWidgetIds);
        }
    }

    private static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.bible_widget);

        SharedPreferences sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
        
        String lang = sp.getString("flutter.widget_language", "rw");
        long count = sp.getLong("flutter.widget_verses_count", 0L);
        long index = sp.getLong("flutter.widget_verse_index", 0L);

        String ref = "";
        String text = "";

        if (count > 0 && index >= 0 && index < count) {
            ref = sp.getString("flutter.widget_verse_ref_" + lang + "_" + index, "");
            text = sp.getString("flutter.widget_verse_text_" + lang + "_" + index, "");
        }

        // Fallback if data is missing or empty
        if (ref == null || ref.isEmpty() || text == null || text.isEmpty()) {
            if ("en".equals(lang)) {
                ref = "John 3:16";
                text = "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.";
            } else {
                ref = "Yohana 3:16";
                text = "Kuko Imana yakunze abari mu isi cyane, ikabasaba Umwana wayo w'ikinege ngo umwizera wese atarimbuka, ahubwo ahabwe ubugingo buhoraho.";
            }
        }

        // Set layout text fields
        views.setTextViewText(R.id.widget_verse_ref, ref);
        views.setTextViewText(R.id.widget_verse_text, text);

        // Previous button PendingIntent
        Intent intentPrev = new Intent(context, BibleWidgetProvider.class);
        intentPrev.setAction(ACTION_PREV_VERSE);
        PendingIntent piPrev = PendingIntent.getBroadcast(context, 0, intentPrev, 
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_btn_prev, piPrev);

        // Next button PendingIntent
        Intent intentNext = new Intent(context, BibleWidgetProvider.class);
        intentNext.setAction(ACTION_NEXT_VERSE);
        PendingIntent piNext = PendingIntent.getBroadcast(context, 0, intentNext, 
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_btn_next, piNext);

        // Body Click to open MainActivity
        Intent intentApp = new Intent(context, MainActivity.class);
        PendingIntent piApp = PendingIntent.getActivity(context, 0, intentApp, 
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_container, piApp);

        // Instruct the widget manager to update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views);
    }
}
