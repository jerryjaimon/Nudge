package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class FinanceWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp        = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val spent     = sp.getString("finance_spent", "0") ?: "0"
        val budget    = sp.getString("finance_budget_label", "/ 0") ?: "/ 0"
        val percent   = sp.getInt("finance_percent", 0)
        val remaining = sp.getString("finance_remaining", "No budget set") ?: "No budget set"

        val intent  = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_finance)
            views.setTextViewText(R.id.finance_spent, spent)
            views.setTextViewText(R.id.finance_budget_label, budget)
            views.setProgressBar(R.id.finance_progress, 100, percent.coerceIn(0, 100), false)
            views.setTextViewText(R.id.finance_remaining, remaining)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
