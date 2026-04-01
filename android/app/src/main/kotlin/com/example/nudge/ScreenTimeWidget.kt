package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import kotlin.math.min

class ScreenTimeWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonStr = sp.getString("screentime_json", "{}") ?: "{}"
        
        var totalMs = 0L
        var totalStr = "0m"
        var appsJson = org.json.JSONArray()
        
        try {
            val root = JSONObject(jsonStr)
            totalMs = root.optLong("totalMs", 0L)
            totalStr = root.optString("totalStr", "0m")
            appsJson = root.optJSONArray("apps") ?: org.json.JSONArray()
        } catch (e: Exception) {}

        val intent = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Configuration: Hardcoded 3 hour goal for limits
        val goalMs = 3 * 60 * 60 * 1000L 

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_screen_time)
            
            views.setTextViewText(R.id.screentime_total, totalStr)
            views.setTextViewText(R.id.screentime_card_total, totalStr)

            val diffMs = totalMs - goalMs
            val diffAbs = Math.abs(diffMs)
            val diffH = diffAbs / (60 * 60 * 1000)
            val diffM = (diffAbs % (60 * 60 * 1000)) / (60 * 1000)
            val diffStr = "${diffH}h ${diffM}m"
            
            val pct = (totalMs.toDouble() / goalMs.toDouble()).coerceIn(0.0, 1.0)
            val progressInt = (pct * 100).toInt()

            if (totalMs >= goalMs) {
                // EXCEEDED Configuration
                val redColor = Color.parseColor("#FFB6B0")
                views.setTextViewText(R.id.status_text, "EXCEEDED")
                views.setTextColor(R.id.status_text, redColor)
                views.setImageViewResource(R.id.status_icon, android.R.drawable.ic_dialog_alert)
                views.setInt(R.id.status_icon, "setColorFilter", redColor)
                views.setTextViewText(R.id.screentime_diff, "+$diffStr")
                
                views.setViewVisibility(R.id.screentime_progress_red, View.VISIBLE)
                views.setViewVisibility(R.id.screentime_progress_white, View.GONE)
                views.setProgressBar(R.id.screentime_progress_red, 100, progressInt, false)
            } else {
                // UNDER LIMIT Configuration
                val whiteColor = Color.WHITE
                views.setTextViewText(R.id.status_text, "UNDER LIMIT")
                views.setTextColor(R.id.status_text, whiteColor)
                views.setImageViewResource(R.id.status_icon, android.R.drawable.presence_online) // simple dot icon
                views.setInt(R.id.status_icon, "setColorFilter", whiteColor)
                views.setTextViewText(R.id.screentime_diff, "-$diffStr")
                
                views.setViewVisibility(R.id.screentime_progress_red, View.GONE)
                views.setViewVisibility(R.id.screentime_progress_white, View.VISIBLE)
                views.setProgressBar(R.id.screentime_progress_white, 100, progressInt, false)
            }

            // Populate top apps dynamically inside the subcard
            views.removeAllViews(R.id.screentime_apps_container)
            val maxRows = min(appsJson.length(), 4) // Show up to 4 apps
            
            for (i in 0 until maxRows) {
                val app = appsJson.optJSONObject(i) ?: continue
                val name = app.optString("name", "Unknown")
                val time = app.optString("timeStr", "0m")
                
                val rowViews = RemoteViews(context.packageName, R.layout.widget_screen_time_app_row)
                rowViews.setTextViewText(R.id.app_name, name)
                rowViews.setTextViewText(R.id.app_time, time)
                
                views.addView(R.id.screentime_apps_container, rowViews)
            }

            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
