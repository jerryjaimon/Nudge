package com.example.nudge

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONException

class DayTrackerConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        val intent = intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_day_tracker_config)

        val container = findViewById<LinearLayout>(R.id.config_list_container)

        val sp = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonStr = sp.getString("trackers_list_json", "[]") ?: "[]"

        var trackers: JSONArray
        try {
            trackers = JSONArray(jsonStr)
        } catch (e: JSONException) {
            trackers = JSONArray()
        }

        if (trackers.length() == 0) {
            val emptyTv = TextView(this)
            emptyTv.text = "No Day Trackers found. Create one in the app first."
            emptyTv.setTextColor(Color.parseColor("#B0C4CF"))
            container.addView(emptyTv)
            return
        }

        for (i in 0 until trackers.length()) {
            try {
                val t = trackers.getJSONObject(i)
                val title = t.getString("title")
                val total = t.getInt("total")
                val colorInt = t.getInt("color")

                val btn = TextView(this)
                btn.text = "$title ($total days)"
                btn.setTextColor(Color.WHITE)
                btn.textSize = 16f
                btn.setPadding(32, 40, 32, 40)
                btn.setBackgroundColor(Color.parseColor("#141A21"))
                
                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                params.setMargins(0, 0, 0, 16)
                btn.layoutParams = params

                btn.setOnClickListener {
                    // Save the choice
                    sp.edit().putInt("widget_${appWidgetId}_tracker_index", i).apply()

                    // Update the widget immediately
                    val appWidgetManager = AppWidgetManager.getInstance(this)
                    val provider = DayTrackerWidget()
                    provider.onUpdate(this, appWidgetManager, intArrayOf(appWidgetId))

                    val resultValue = Intent()
                    resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    setResult(RESULT_OK, resultValue)
                    finish()
                }

                container.addView(btn)
            } catch (e: Exception) { }
        }
    }
}
