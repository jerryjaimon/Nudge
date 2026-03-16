package com.example.nudge

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class PomodoroBlockerService : Service() {

    private val CHANNEL_ID = "PomodoroBlockerServiceChannel"
    private var handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    
    // Store array of blocked apps properly
    private var blockedApps: List<String> = emptyList()

    private val checkAppsRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, 1000) // check every 1 sec
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val appsExtra = intent?.getStringArrayExtra("blocked_apps")
        blockedApps = appsExtra?.toList() ?: emptyList()
        Log.d("PomoBlocker", "Started blocking: $blockedApps")

        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Nudge Focus Mode")
            .setContentText("Focus session is active. Tracking apps are blocked.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .build()
            
        // Provide the specialUse type for Android 14+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }

        handler.post(checkAppsRunnable)
        return START_STICKY
    }

    private fun checkForegroundApp() {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val beginTime = endTime - 10000 // last 10 seconds

        var currentApp = ""
        val usageEvents = usageStatsManager.queryEvents(beginTime, endTime)
        val event = UsageEvents.Event()
        
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED || event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                currentApp = event.packageName
            }
        }

        if (currentApp.isNotEmpty()) {
            if (blockedApps.contains(currentApp)) {
                showOverlay()
            } else if (currentApp != packageName && overlayView != null) {
                // If we switched to a non-blocked app that isn't Nudge, but overlay is still up, remove it.
                // Normally the Home button closes everything, but this is a fallback.
                removeOverlay()
            }
        }
    }

    private fun showOverlay() {
        if (overlayView != null) return // Already showing

        Log.d("PomoBlocker", "Drawing Block Overlay!")
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        overlayView = inflater.inflate(android.R.layout.simple_list_item_1, null).apply {
            setBackgroundColor(Color.parseColor("#04120B")) // Nudge Dark theme
        }
        
        // We'll construct a simple view programmatically to avoid needing xml resources
        val container = android.widget.LinearLayout(this).apply {
            setBackgroundColor(Color.parseColor("#04120B"))
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(60, 60, 60, 60)
        }
        
        val title = TextView(this).apply {
            text = "Focus Mode Active"
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 40)
        }
        
        val subtitle = TextView(this).apply {
            text = "This app is blocked until your Pomodoro session finishes."
            textSize = 16f
            setTextColor(Color.LTGRAY)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 80)
        }
        
        val homeBtn = Button(this).apply {
            text = "Back to Safety (Home)"
            setBackgroundColor(Color.parseColor("#FF453A")) // Red Button
            setTextColor(Color.WHITE)
            setOnClickListener {
                goToHomeScreen()
                removeOverlay()
            }
        }

        container.addView(title)
        container.addView(subtitle)
        container.addView(homeBtn)

        overlayView = container

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER
        windowManager?.addView(overlayView, params)
    }

    private fun removeOverlay() {
        if (overlayView != null) {
            windowManager?.removeView(overlayView)
            overlayView = null
        }
    }

    private fun goToHomeScreen() {
        val startMain = Intent(Intent.ACTION_MAIN)
        startMain.addCategory(Intent.CATEGORY_HOME)
        startMain.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(startMain)
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(checkAppsRunnable)
        removeOverlay()
        Log.d("PomoBlocker", "Blocker Service Destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Pomodoro Blocker Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }
}
