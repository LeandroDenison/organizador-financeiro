package com.leandrodenison.organizador_financeiro

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class FinancialNotificationListener : NotificationListenerService() {

    companion object {
        const val TAG = "FinancialNotifListener"
        const val ACTION_NOTIFICATION_POSTED = "com.leandrodenison.organizador_financeiro.NOTIFICATION_POSTED"
        const val EXTRA_PACKAGE = "extra_package"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_TEXT = "extra_text"
        const val EXTRA_TIMESTAMP = "extra_timestamp"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val lowerPkg = packageName.lowercase()

        // Check if notification belongs to supported bank apps
        val isBankApp = lowerPkg.contains("nu.production") ||
                lowerPkg.contains("itau") ||
                lowerPkg.contains("mercadopago") ||
                lowerPkg.contains("bradesco") ||
                lowerPkg.contains("santander") ||
                lowerPkg.contains("inter")

        if (!isBankApp) return

        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""

        Log.d(TAG, "Captured notification from $packageName: $title - $text")

        // Broadcast to application / MainActivity
        val intent = Intent(ACTION_NOTIFICATION_POSTED).apply {
            setPackage(this@FinancialNotificationListener.packageName)
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_TEXT, text)
            putExtra(EXTRA_TIMESTAMP, sbn.postTime)
        }
        sendBroadcast(intent)
    }
}
