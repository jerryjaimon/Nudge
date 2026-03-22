package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class PomodoroWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp       = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val time     = sp.getString("pomo_time", "0m") ?: "0m"
        val sessions = sp.getString("pomo_sessions", "0 sessions") ?: "0 sessions"

        val intent  = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_pomodoro)
            views.setTextViewText(R.id.pomo_time, time)
            views.setTextViewText(R.id.pomo_sessions, sessions)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
