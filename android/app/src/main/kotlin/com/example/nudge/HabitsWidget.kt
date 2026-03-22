package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class HabitsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp      = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val done    = sp.getString("habits_done", "0") ?: "0"
        val total   = sp.getString("habits_total", "/ 0 habits") ?: "/ 0 habits"
        val percent = sp.getInt("habits_percent", 0)
        val label   = sp.getString("habits_label", "completed today") ?: "completed today"

        val intent  = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_habits)
            views.setTextViewText(R.id.habits_done, done)
            views.setTextViewText(R.id.habits_total, total)
            views.setProgressBar(R.id.habits_progress, 100, percent.coerceIn(0, 100), false)
            views.setTextViewText(R.id.habits_label, label)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
