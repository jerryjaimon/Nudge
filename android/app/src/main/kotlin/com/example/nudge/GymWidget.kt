package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class GymWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val streak = sp.getString("gym_streak", "0") ?: "0"
        val last   = sp.getString("gym_last", "—") ?: "—"
        val week   = sp.getString("gym_week", "0 sessions this week") ?: "0 sessions this week"

        val intent  = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_gym)
            views.setTextViewText(R.id.gym_streak, streak)
            views.setTextViewText(R.id.gym_last, last)
            views.setTextViewText(R.id.gym_week, week)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
