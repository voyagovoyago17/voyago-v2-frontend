package com.voyagooo.voyagooo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * Canaux des notifications push (mêmes identifiants que le backend).
     * Le son d'un canal ne peut plus changer une fois créé : le son signature a donc son propre canal.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        // Son signature Voyagooo : itinéraire prêt, plan B pluie, départ demain, baisse de prix…
        val signatureSound = Uri.parse("android.resource://$packageName/raw/voyagooo")
        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        manager.createNotificationChannel(
            NotificationChannel("voyagooo_signature", "Alertes Voyagooo", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Itinéraires prêts, plan B pluie, départs, baisses de prix… avec le son Voyagooo"
                setSound(signatureSound, audio)
                enableVibration(true)
            },
        )

        // Vibration seule (réglage du voyageur)
        manager.createNotificationChannel(
            NotificationChannel("voyagooo_vibrate", "Alertes en vibration", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Tes alertes de voyage avec vibration, sans son"
                setSound(null, null)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 180, 120, 180)
            },
        )

        // Sans son : heures calmes et interactions sociales en rafale
        manager.createNotificationChannel(
            NotificationChannel("voyagooo_quiet", "Notifications discrètes", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Heures calmes et commentaires groupés, sans son"
                setSound(null, null)
                enableVibration(false)
            },
        )

        // Canal historique (anciennes versions du serveur)
        manager.createNotificationChannel(
            NotificationChannel("voyagooo_alerts", "Activité Voyagooo", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Itinéraires prêts, commentaires, votes de tribu…"
            },
        )
    }
}
