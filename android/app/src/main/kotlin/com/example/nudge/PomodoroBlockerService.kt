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
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class PomodoroBlockerService : Service() {

    private val CHANNEL_ID = "PomodoroBlockerServiceChannel"
    private var handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var blockedApps: List<String> = emptyList()

    // DND state
    private var previousDndFilter = NotificationManager.INTERRUPTION_FILTER_UNKNOWN

    // ── Motivating messages ───────────────────────────────────────────────────
    private val motivatingMessages = listOf(
        "Your future self is watching. Don't disappoint them. 👀",
        "That app will still be there after your focus time. The Wi-Fi hasn't gone anywhere.",
        "Every minute you resist is a minute you're winning. Keep winning.",
        "Your brain is a garden. Stop feeding it junk food right now.",
        "Somewhere out there, a version of you is focused and thriving. Be that version.",
        "This is the sign you've been looking for. Get back to work. 🚀",
        "Fun fact: you will not miss anything important in the next 25 minutes.",
        "The dopamine hit isn't worth it. The *finish* hit is way better.",
        "Deep work is a superpower. You are literally becoming superhuman right now.",
        "Distraction is just boredom in a trench coat. Don't let it fool you.",
        "Your goals don't take days off. Neither do you. Not right now.",
        "Imagine telling your future self you gave up because a notification looked interesting.",
        "Hard things done consistently become easy things. Stay in the hard part.",
        "You blocked this app for a reason. Past-you was wise. Honor past-you.",
        "The world's best athletes train without distraction. You're training your mind. Go.",
        "This blocker is your personal bouncer. You hired it. Respect the decision.",
        "Five minutes of this app will cost you 20 minutes of focus. Not worth it. 🧠",
        "You're not missing out. You're opting IN — to the life you actually want.",
        "Busy is easy. Focused is rare. Be rare.",
        "The best creative work happens past the point where most people check their phone.",
        "Your focus is a limited resource. Spend it on something that compounds. 📈",
        "This session is a promise to yourself. Don't break it over a scroll.",
        "You already did the hard part of *starting*. Don't quit now.",
        "Boredom is the doorway to creativity. Sit in it for a minute. Open the door.",
        "The app will be here later. The moment won't be. Choose the moment.",
        "Your future self says: thank you for staying. 💪",
        "Champions do the work even when no one is watching. Especially then.",
        "Plot twist: the most interesting thing right now is what you're supposed to be doing.",
        "Every great thing you've built started with one focused session. This is that session.",
        "You are literally one focus block away from momentum. Don't stop."
    )

    // ── Scolding messages ─────────────────────────────────────────────────────
    private val scoldingMessages = listOf(
        "Oh wow. You really did that. You opened the BLOCKED app. Bold choice. Go back.",
        "This app is blocked. You did that. You made the right call and now you're undoing it. Stop.",
        "Excuse me??? You JUST started your session. Put. It. Down.",
        "You set this up yourself. You knew this moment would come. Don't you dare.",
        "Really? AGAIN? The app will still be there in 25 minutes. Go.",
        "Your future self is shaking their head right now. Don't make them cry.",
        "You blocked this app on purpose. What part of that was unclear?",
        "I can't believe you. Actually I can. That's worse. Go back to work.",
        "The audacity. The absolute audacity. Close this. Now.",
        "This is embarrassing. Not for me — for you. We both know it.",
        "You literally scheduled this blocker. That was smart-you. Don't let dumb-you win.",
        "No. Absolutely not. This is a hard no. Go back to whatever you were doing.",
        "Sir/Ma'am/Buddy — this is a NO from me. And from you, technically. Past-you said so.",
        "Every time you open a blocked app, a focus session dies. You did this.",
        "Oh sure, just one quick scroll. That's what everyone says. Three hours later...",
        "Your goals are literally sitting there waiting while you do THIS. Shame.",
        "I'm not mad. I'm disappointed. Okay I'm a little mad.",
        "You set up this blocker at a moment of clarity. Trust that version of you.",
        "This is the third time today. I've been counting. We need to talk.",
        "The whole point of a blocker is that it BLOCKS. Work WITH it, not against it.",
        "You're going to finish this session and feel amazing. But first: CLOSE THIS APP.",
        "Did you forget why you started? Because I didn't. Go finish it.",
        "Cool. Very cool. Now go back to the thing that actually matters. Now.",
        "You are one distraction away from mediocrity. Don't be mediocre.",
        "If you close this and go back to work, I'll pretend this never happened. Deal?",
        "Breaking news: person opens the exact app they blocked. More at 11.",
        "Listen. I believe in you. I really do. Which is why I'm telling you to STOP.",
        "Scrolling is not a reward. It's an ambush. You walked straight into it.",
        "Past-you trusted present-you to get the work done. Don't let them down.",
        "Okay fine. Take a breath. Close the app. Go back. You've got this. But seriously, GO."
    )

    private var currentTone = "motivating"
    private var currentMessage = motivatingMessages.random()

    private val checkAppsRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, 1000)
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
        currentTone = intent?.getStringExtra("blocker_tone") ?: "motivating"
        Log.d("PomoBlocker", "Started blocking: $blockedApps tone=$currentTone")

        enableDnd()

        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Nudge Focus Mode")
            .setContentText("Focus session is active. Distracting apps are blocked.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .build()

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
        val beginTime = endTime - 10000

        var currentApp = ""
        val usageEvents = usageStatsManager.queryEvents(beginTime, endTime)
        val event = UsageEvents.Event()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            ) {
                currentApp = event.packageName
            }
        }

        if (currentApp.isNotEmpty()) {
            if (blockedApps.contains(currentApp)) {
                showOverlay()
            } else if (currentApp != packageName && overlayView != null) {
                removeOverlay()
            }
        }
    }

    private fun showOverlay() {
        if (overlayView != null) return

        // Pick a fresh random message each time the overlay is shown
        val pool = if (currentTone == "scolding") scoldingMessages else motivatingMessages
        currentMessage = pool.random()

        Log.d("PomoBlocker", "Drawing Block Overlay: $currentMessage")

        val container = android.widget.LinearLayout(this).apply {
            setBackgroundColor(Color.parseColor("#050A0D"))
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(72, 72, 72, 72)
        }

        // Lock icon top
        val lockIcon = TextView(this).apply {
            text = "🔒"
            textSize = 44f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 32)
        }

        val title = TextView(this).apply {
            text = "Focus Mode Active"
            textSize = 24f
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }

        // Motivational message card
        val msgCard = android.widget.LinearLayout(this@PomodoroBlockerService).apply {
            setBackgroundColor(Color.parseColor("#0C1317"))
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(40, 36, 40, 36)
            // Rounded corners via a background drawable would require XML — skip for simplicity
        }

        val msgText = TextView(this).apply {
            text = currentMessage
            textSize = 16f
            setTextColor(Color.parseColor("#B0C4CF"))
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.4f)
        }

        msgCard.addView(msgText)

        val spacer = android.widget.Space(this).apply {
            minimumHeight = 56
        }

        val homeBtn = Button(this).apply {
            text = "← Go Back"
            textSize = 14f
            setBackgroundColor(Color.parseColor("#1A2A32"))
            setTextColor(Color.parseColor("#5AC8FA"))
            setTypeface(typeface, Typeface.BOLD)
            setPadding(48, 24, 48, 24)
            setOnClickListener {
                goToHomeScreen()
                removeOverlay()
            }
        }

        container.addView(lockIcon)
        container.addView(title)
        container.addView(msgCard)
        container.addView(spacer)
        container.addView(homeBtn)

        overlayView = container

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER
        windowManager?.addView(overlayView, params)
    }

    private fun removeOverlay() {
        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (e: Exception) {
                Log.w("PomoBlocker", "removeOverlay: ${e.message}")
            }
            overlayView = null
        }
    }

    private fun goToHomeScreen() {
        val startMain = Intent(Intent.ACTION_MAIN)
        startMain.addCategory(Intent.CATEGORY_HOME)
        startMain.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(startMain)
    }

    // ── Do Not Disturb ────────────────────────────────────────────────────────

    private fun enableDnd() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.isNotificationPolicyAccessGranted) {
            previousDndFilter = nm.currentInterruptionFilter
            // INTERRUPTION_FILTER_ALARMS: allows alarms, blocks other notification pop-ups
            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALARMS)
            Log.d("PomoBlocker", "DND enabled (prev=$previousDndFilter)")
        }
    }

    private fun disableDnd() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.isNotificationPolicyAccessGranted &&
            previousDndFilter != NotificationManager.INTERRUPTION_FILTER_UNKNOWN
        ) {
            nm.setInterruptionFilter(previousDndFilter)
            Log.d("PomoBlocker", "DND restored to $previousDndFilter")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(checkAppsRunnable)
        removeOverlay()
        disableDnd()
        Log.d("PomoBlocker", "Blocker Service Destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

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
