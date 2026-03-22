package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class FoodWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp        = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val calories  = sp.getString("food_calories", "0") ?: "0"
        val percent   = sp.getInt("food_percent", 0)
        val goalLabel = sp.getString("food_goal_label", "of 2000 kcal goal") ?: "of 2000 kcal goal"

        val intent  = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_food)
            views.setTextViewText(R.id.food_calories, calories)
            views.setProgressBar(R.id.food_progress, 100, percent.coerceIn(0, 100), false)
            views.setTextViewText(R.id.food_goal_label, goalLabel)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
