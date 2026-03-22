package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class BackupWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val lastLabel  = sp.getString("backup_last",   "Never")          ?: "Never"
        val statusLabel = sp.getString("backup_status", "Not backed up") ?: "Not backed up"
        val autoLabel   = sp.getString("backup_auto",  "OFF")            ?: "OFF"

        val intent  = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_backup)
            views.setTextViewText(R.id.backup_time,       lastLabel)
            views.setTextViewText(R.id.backup_status,     statusLabel)
            views.setTextViewText(R.id.backup_auto_label, "Auto: $autoLabel")
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
