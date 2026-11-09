package com.leandrodenison.organizador_financeiro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.leandrodenison.organizador_financeiro/notification_listener"
    private var methodChannel: MethodChannel? = null

    private val notificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == FinancialNotificationListener.ACTION_NOTIFICATION_POSTED) {
                val pkg = intent.getStringExtra(FinancialNotificationListener.EXTRA_PACKAGE) ?: ""
                val title = intent.getStringExtra(FinancialNotificationListener.EXTRA_TITLE) ?: ""
                val text = intent.getStringExtra(FinancialNotificationListener.EXTRA_TEXT) ?: ""
                val timestamp = intent.getLongExtra(FinancialNotificationListener.EXTRA_TIMESTAMP, System.currentTimeMillis())

                val data = mapOf(
                    "package" to pkg,
                    "title" to title,
                    "text" to text,
                    "timestamp" to timestamp
                )
                methodChannel?.invokeMethod("onNotificationReceived", data)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    val isGranted = isNotificationServiceEnabled()
                    result.success(isGranted)
                }
                "requestPermission" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Register BroadcastReceiver for notifications
        val filter = IntentFilter(FinancialNotificationListener.ACTION_NOTIFICATION_POSTED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(notificationReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(notificationReceiver)
        } catch (_: Exception) {
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(this)
        return enabledPackages.contains(packageName)
    }
}
