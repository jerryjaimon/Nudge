package com.example.nudge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.ceil
import kotlin.math.max

class DayTrackerWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val sp = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonStr = sp.getString("trackers_list_json", "[]") ?: "[]"
        val trackers = JSONArray(jsonStr)

        val intent = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in ids) {
            val trackerIndex = sp.getInt("widget_${id}_tracker_index", 0)
            
            var t: JSONObject? = null
            if (trackerIndex >= 0 && trackerIndex < trackers.length()) {
                t = trackers.getJSONObject(trackerIndex)
            } else if (trackers.length() > 0) {
                t = trackers.getJSONObject(0)
            }

            val views = RemoteViews(context.packageName, R.layout.widget_day_tracker)
            views.setOnClickPendingIntent(R.id.widget_root, pending)

            if (t == null) {
                views.setTextViewText(R.id.tracker_title, "No Tracker")
                views.setTextViewText(R.id.tracker_rem, "Create a tracker in app first.")
                manager.updateAppWidget(id, views)
                continue
            }

            val opts = manager.getAppWidgetOptions(id)
            val minW = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
            val maxH = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110)
            val density = context.resources.displayMetrics.density
            val widthPx = (minW * density).toInt().coerceAtLeast((110f * density).toInt())
            // Subtract approximate vertical padding and fixed text sizes (padding + title + progress + text = ~86dp)
            val maxDotHeightPx = ((maxH - 86f) * density).toInt().coerceAtLeast((20f * density).toInt())

            val title = t.getString("title")
            val current = t.getInt("current")
            val total = t.getInt("total")
            val colorInt = t.getInt("color")
            val pctInt = t.getInt("pct_int")
            val remaining = (total - current).coerceAtLeast(0)

            val stats = "$current / $total"
            val remLabel = "$remaining days left · $pctInt%"

            val bitmap = buildDotGrid(widthPx, maxDotHeightPx, total, current, colorInt, density)

            views.setTextViewText(R.id.tracker_title, title)
            views.setTextViewText(R.id.tracker_stats, stats)
            views.setTextViewText(R.id.tracker_rem, remLabel)
            views.setImageViewBitmap(R.id.tracker_dots, bitmap)
            views.setProgressBar(R.id.tracker_progress, 100, pctInt.coerceIn(0, 100), false)

            manager.updateAppWidget(id, views)
        }
    }

    private fun buildDotGrid(
        widthPx: Int,
        maxH: Int,
        total: Int,
        current: Int,
        colorInt: Int,
        density: Float,
    ): Bitmap {
        // Calculate a visually pleasant grid pattern filling all boundaries
        val minCellPx = 14f * density 
        val cols = (widthPx / minCellPx).toInt().coerceAtLeast(1)
        val rows = (maxH / minCellPx).toInt().coerceAtLeast(1)
        
        val capacity = cols * rows

        val pct = if (total > 0) (current.toDouble() / total.toDouble()).coerceIn(0.0, 1.0) else 0.0
        val dotsToColor = (pct * capacity).toInt()

        val cellW = widthPx.toFloat() / cols
        val cellH = maxH.toFloat() / rows
        val cellPx = Math.min(cellW, cellH)

        val actualWidth = (cols * cellPx).toInt()
        val actualHeight = (rows * cellPx).toInt().coerceAtLeast(1)

        val bmp = Bitmap.createBitmap(Math.max(actualWidth, 1), actualHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)

        // 70% of cell is dot, 30% gap
        val dotPx = cellPx * 0.70f 
        val gapPx = cellPx * 0.30f

        val pastPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(190, 255, 255, 255) }
        val futurePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(25, 255, 255, 255) }
        val todayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colorInt }
        val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            val r = (colorInt shr 16) and 0xFF
            val g = (colorInt shr 8) and 0xFF
            val b = colorInt and 0xFF
            color = Color.argb(64, r, g, b)
        }

        val radius = dotPx / 2f

        for (i in 0 until capacity) {
            val col = i % cols
            val row = i / cols
            val cx  = col * cellPx + (cellPx / 2f)
            val cy  = row * cellPx + (cellPx / 2f)
            when {
                i < dotsToColor  -> canvas.drawCircle(cx, cy, radius, pastPaint)
                i == dotsToColor -> {
                    canvas.drawCircle(cx, cy, radius + (gapPx / 2f), glowPaint)
                    canvas.drawCircle(cx, cy, radius, todayPaint)
                }
                else               -> canvas.drawCircle(cx, cy, radius, futurePaint)
            }
        }

        return bmp
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val sp = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = sp.edit()
        for (id in appWidgetIds) {
            editor.remove("widget_${id}_tracker_index")
        }
        editor.apply()
        super.onDeleted(context, appWidgetIds)
    }
}
