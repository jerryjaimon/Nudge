package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.widget.RemoteViews
import kotlin.math.ceil
import kotlin.math.max

class DayTrackerWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp      = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val title   = sp.getString("tracker_title", "Year") ?: "Year"
        val current = sp.getInt("tracker_current", 0)
        val total   = sp.getInt("tracker_total", 365)
        val colorInt = sp.getInt("tracker_color", 0xFF7C4DFF.toInt())
        val pctInt  = sp.getInt("tracker_pct_int", 0)
        val remaining = (total - current).coerceAtLeast(0)

        val stats    = "$current / $total days"
        val remLabel = "$remaining days left · $pctInt%"

        val intent  = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in ids) {
            val opts    = manager.getAppWidgetOptions(id)
            val minW    = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val density = context.resources.displayMetrics.density
            val widthPx = (minW * density).toInt().coerceAtLeast(200)
            val bitmap  = buildDotGrid(widthPx, total, current, colorInt, density)

            val views = RemoteViews(context.packageName, R.layout.widget_day_tracker)
            views.setTextViewText(R.id.tracker_title, title)
            views.setTextViewText(R.id.tracker_stats, stats)
            views.setTextViewText(R.id.tracker_rem, remLabel)
            views.setImageViewBitmap(R.id.tracker_dots, bitmap)
            views.setProgressBar(R.id.tracker_progress, 100, pctInt.coerceIn(0, 100), false)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }

    private fun buildDotGrid(
        widthPx: Int,
        total: Int,
        current: Int,
        colorInt: Int,
        density: Float,
    ): Bitmap {
        val dotPx = 7f * density
        val gapPx = 4f * density
        val cols  = max(1, (widthPx / (dotPx + gapPx)).toInt())
        val rows  = ceil(total.toDouble() / cols).toInt().coerceAtLeast(1)
        val h     = (rows * (dotPx + gapPx)).toInt().coerceAtLeast(1)

        val bmp    = Bitmap.createBitmap(widthPx, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)

        val pastPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(190, 255, 255, 255)   // white ~75%
        }
        val futurePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(25, 255, 255, 255)    // white ~10%
        }
        val todayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = colorInt
        }
        val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            val r = (colorInt shr 16) and 0xFF
            val g = (colorInt shr 8) and 0xFF
            val b = colorInt and 0xFF
            color = Color.argb(64, r, g, b)           // accent ~25% alpha
        }

        val radius = dotPx / 2f

        for (i in 0 until total) {
            val col = i % cols
            val row = i / cols
            val cx  = col * (dotPx + gapPx) + radius
            val cy  = row * (dotPx + gapPx) + radius
            when {
                i < current  -> canvas.drawCircle(cx, cy, radius, pastPaint)
                i == current -> {
                    canvas.drawCircle(cx, cy, radius + 2 * density, glowPaint)
                    canvas.drawCircle(cx, cy, radius, todayPaint)
                }
                else         -> canvas.drawCircle(cx, cy, radius, futurePaint)
            }
        }

        return bmp
    }
}
