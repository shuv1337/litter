package io.latitudes.shitter.android.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class ShitterFirebaseMessagingService : FirebaseMessagingService() {
    companion object {
        private const val CHANNEL_ID = "turn_status"
        private const val NOTIFICATION_ID = 9001
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        when (data["type"]) {
            "turn_keepalive" -> showOrUpdateTurnNotification(data)
            "turn_end" -> showTurnCompleteNotification(data)
        }
    }

    override fun onNewToken(token: String) {
        getSharedPreferences("shitter_push", MODE_PRIVATE)
            .edit()
            .putString("fcm_token", token)
            .apply()
    }

    private fun showOrUpdateTurnNotification(data: Map<String, String>) {
        ensureChannel()
        val phase = data["phase"] ?: "thinking"
        val elapsed = data["elapsedSeconds"]?.toLongOrNull() ?: 0
        val toolCount = data["toolCallCount"]?.toIntOrNull() ?: 0
        val minutes = elapsed / 60
        val seconds = elapsed % 60
        val text = buildString {
            append("Phase: $phase")
            append(" | ${minutes}m ${seconds}s")
            if (toolCount > 0) append(" | $toolCount tools")
        }
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("Codex turn in progress")
            .setContentText(text)
            .setOngoing(true)
            .setSilent(true)
            .build()
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun showTurnCompleteNotification(data: Map<String, String>) {
        ensureChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("Codex turn completed")
            .setContentText(data["summary"] ?: "Turn finished")
            .setOngoing(false)
            .build()
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, notification)
        mainHandler.postDelayed({ nm.cancel(NOTIFICATION_ID) }, 10_000)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Turn Status",
                NotificationManager.IMPORTANCE_LOW,
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
