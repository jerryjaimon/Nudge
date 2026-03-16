package com.example.nudge

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RevolutNotificationService : NotificationListenerService() {

    companion object {
        var instance: RevolutNotificationService? = null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        Log.d("RevolutNotif", "Listener Connected!")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        instance = null
        Log.d("RevolutNotif", "Listener Disconnected!")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        sbn?.let { processNotification(it, applicationContext) }
    }

    fun scanActiveNotifications() {
        Log.d("RevolutNotif", "Scanning active notifications...")
        try {
            val activeNotifs = activeNotifications
            if (activeNotifs != null) {
                for (sbn in activeNotifs) {
                    processNotification(sbn, applicationContext)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun processNotification(sbn: StatusBarNotification, context: Context) {
        val pkg = sbn.packageName ?: ""
        // Log.d("RevolutNotif", "checking pkg: $pkg")
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        
        val textLower = text.lowercase()
        val titleLower = title.lowercase()
        
        // Log EVERYTHING for debugging
        saveRawNotification(context, pkg, title, text)

        // UK + Indian banking apps
        val pkgLower = pkg.lowercase()
        val isBankingApp = pkgLower.contains("revolut") || pkgLower.contains("monzo") ||
            pkgLower.contains("starling") || pkgLower.contains("chase") ||
            pkgLower.contains("hsbc") || pkgLower.contains("barclays") ||
            pkgLower.contains("hdfc") || pkgLower.contains("icici") ||
            pkgLower.contains("sbi") || pkgLower.contains("axisbank") ||
            pkgLower.contains("kotak") || pkgLower.contains("yesbank") ||
            pkgLower.contains("idfcfirst") || pkgLower.contains("indusind") ||
            pkgLower.contains("federalbank") || pkgLower.contains("rbl") ||
            pkgLower.contains("paytm") || pkgLower.contains("phonepe") ||
            pkgLower.contains("gpay") || pkgLower.contains("amazonpay") ||
            titleLower.contains("hdfc") || titleLower.contains("icici") ||
            titleLower.contains("sbi") || titleLower.contains("revolut") ||
            titleLower.contains("monzo")

        val hasMonetaryKeyword = textLower.contains("spent") ||
            textLower.contains("payment") || textLower.contains("paid") ||
            textLower.contains("debited") || textLower.contains("credited") ||
            textLower.contains("£") || textLower.contains("$") ||
            textLower.contains("₹") || textLower.contains("inr") ||
            textLower.contains("rs.")

        if (isBankingApp && hasMonetaryKeyword) {
            savePendingExpense(context, title, text)
        }
    }

    private fun saveRawNotification(context: Context, pkg: String, title: String, text: String) {
        val prefs = context.getSharedPreferences("NudgeFinance", Context.MODE_PRIVATE)
        val currentJsonStr = prefs.getString("raw_notifications", "[]")
        try {
            val array = JSONArray(currentJsonStr)
            val obj = JSONObject()
            obj.put("pkg", pkg)
            obj.put("title", title)
            obj.put("text", text)
            val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
            obj.put("time", sdf.format(Date()))
            
            // Keep only the last 50 notifications to avoid blowing up storage
            if (array.length() >= 50) {
                array.remove(0)
            }
            array.put(obj)
            
            prefs.edit().putString("raw_notifications", array.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun savePendingExpense(context: Context, title: String, text: String) {
        val prefs = context.getSharedPreferences("NudgeFinance", Context.MODE_PRIVATE)
        
        // Prevent duplicates
        val lastSavedText = prefs.getString("last_saved_text", "")
        if (lastSavedText == text) return
        prefs.edit().putString("last_saved_text", text).apply()

        val currentJsonStr = prefs.getString("pending_expenses", "[]")
        try {
            val array = JSONArray(currentJsonStr)
            val obj = JSONObject()
            obj.put("title", title)
            obj.put("text", text)
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            obj.put("timestamp", sdf.format(Date()))
            array.put(obj)
            
            prefs.edit().putString("pending_expenses", array.toString()).apply()
            Log.d("RevolutNotif", "Saved pending expense!: $text")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
