package com.gospelhub.app.gospel_hub;

import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.gospelhub.app/widget";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("updateWidget")) {
                    persistWidgetPrefsFromCall(this, call.arguments);
                    updateWidget(this);
                    result.success(null);
                } else {
                    result.notImplemented();
                }
            });
    }

    private void persistWidgetPrefsFromCall(Context context, Object arguments) {
        if (!(arguments instanceof java.util.Map)) {
            return;
        }
        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> map = (java.util.Map<String, Object>) arguments;
        SharedPreferences.Editor editor =
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit();

        Object opacity = map.get("opacity");
        if (opacity instanceof Number) {
            editor.putString("flutter.widget_opacity", String.valueOf(((Number) opacity).doubleValue()));
        }
        Object fontSize = map.get("fontSize");
        if (fontSize instanceof Number) {
            editor.putString("flutter.widget_font_size", String.valueOf(((Number) fontSize).doubleValue()));
        }
        Object fontStyle = map.get("fontStyle");
        if (fontStyle instanceof String) {
            editor.putString("flutter.widget_font_style", (String) fontStyle);
        }
        Object language = map.get("language");
        if (language instanceof String) {
            editor.putString("flutter.widget_language", (String) language);
        }
        editor.commit();
    }

    private void updateWidget(Context context) {
        Intent intent = new Intent(context, BibleWidgetProvider.class);
        intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        int[] ids = AppWidgetManager.getInstance(context).getAppWidgetIds(
            new ComponentName(context, BibleWidgetProvider.class)
        );
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids);
        context.sendBroadcast(intent);
    }
}
