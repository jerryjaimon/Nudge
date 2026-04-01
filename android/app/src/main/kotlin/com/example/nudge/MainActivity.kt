package com.example.nudge

import android.Manifest
import android.app.AlarmManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity: FlutterFragmentActivity() {
    private val FINANCE_CHANNEL = "com.example.nudge/finance"
    private val POMODORO_CHANNEL = "com.example.nudge/pomodoro"
    private val UPDATE_CHANNEL  = "com.example.nudge/update"
    private val BACKUP_CHANNEL  = "com.example.nudge/backup"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FINANCE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "requestPermission" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "getPendingExpenses" -> {
                    RevolutNotificationService.instance?.scanActiveNotifications()
                    
                    val prefs = getSharedPreferences("NudgeFinance", Context.MODE_PRIVATE)
                    val out = prefs.getString("pending_expenses", "[]")
                    prefs.edit().remove("pending_expenses").apply()
                    result.success(out)
                }
                "getRawNotifications" -> {
                    val prefs = getSharedPreferences("NudgeFinance", Context.MODE_PRIVATE)
                    val out = prefs.getString("raw_notifications", "[]")
                    result.success(out)
                }
                "clearFinanceData" -> {
                    val prefs = getSharedPreferences("NudgeFinance", Context.MODE_PRIVATE)
                    prefs.edit().putString("pending_expenses", "[]").putString("raw_notifications", "[]").apply()
                    result.success(true)
                }
                "checkSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> {
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS), 1002)
                    result.success(true)
                }
                "getSmsTransactions" -> {
                    try {
                        val lookbackDays = call.argument<Int>("lookbackDays") ?: 30
                        val cutoffMs = System.currentTimeMillis() - (lookbackDays.toLong() * 24 * 60 * 60 * 1000L)
                        val uri = android.net.Uri.parse("content://sms/inbox")
                        val cursor = contentResolver.query(
                            uri,
                            arrayOf("_id", "address", "body", "date"),
                            "date > ?",
                            arrayOf(cutoffMs.toString()),
                            "date DESC"
                        )
                        val jsonArray = JSONArray()
                        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                        cursor?.use {
                            val bodyIdx = it.getColumnIndex("body")
                            val addrIdx = it.getColumnIndex("address")
                            val dateIdx = it.getColumnIndex("date")
                            while (it.moveToNext()) {
                                val body = if (bodyIdx >= 0) it.getString(bodyIdx) else continue
                                val sender = if (addrIdx >= 0) it.getString(addrIdx) else ""
                                val dateMs = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()
                                val obj = JSONObject()
                                obj.put("sender", sender ?: "")
                                obj.put("body", body ?: "")
                                obj.put("timestamp", sdf.format(Date(dateMs)))
                                jsonArray.put(obj)
                            }
                        }
                        result.success(jsonArray.toString())
                    } catch (e: Exception) {
                        result.success("[]")
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, POMODORO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivityForResult(intent, 1001)
                    }
                    result.success(true)
                }
                "startBlocker" -> {
                    val apps = call.argument<List<String>>("apps")?.toTypedArray() ?: emptyArray()
                    val tone = call.argument<String>("tone") ?: "motivating"
                    val serviceIntent = Intent(this, PomodoroBlockerService::class.java)
                    serviceIntent.putExtra("blocked_apps", apps)
                    serviceIntent.putExtra("blocker_tone", tone)
                    
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }
                "stopBlocker" -> {
                    val serviceIntent = Intent(this, PomodoroBlockerService::class.java)
                    stopService(serviceIntent)
                    result.success(true)
                }
                "getNextAlarm" -> {
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val nextAlarm = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                        alarmManager.nextAlarmClock?.triggerTime ?: 0L
                    } else {
                        0L
                    }
                    result.success(nextAlarm)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARG", "path is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val apkFile = java.io.File(path)
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this,
                            "${packageName}.fileprovider",
                            apkFile
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryOptimizationDisabled" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "openBatteryOptimizationSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!TextUtils.isEmpty(flat)) {
            val names = flat.split(":")
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && TextUtils.equals(pkgName, cn.packageName)) {
                    return true
                }
            }
        }
        return false
    }
}
