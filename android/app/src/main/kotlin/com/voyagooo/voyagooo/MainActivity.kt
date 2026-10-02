package com.voyagooo.voyagooo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /** Canal des notifications push (même identifiant que le backend) : importance haute = bannière + son. */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "voyagooo_alerts",
            "Activité Voyagooo",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Itinéraires prêts, commentaires, votes de tribu…"
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }
}
