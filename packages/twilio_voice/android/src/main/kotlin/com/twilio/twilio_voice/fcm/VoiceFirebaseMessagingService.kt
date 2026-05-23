package com.twilio.twilio_voice.fcm

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telecom.*
import android.util.Log
import androidx.annotation.RequiresPermission
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.twilio.twilio_voice.receivers.TVBroadcastReceiver
import com.twilio.twilio_voice.service.TVConnectionService
import com.twilio.twilio_voice.storage.StorageImpl
import com.twilio.twilio_voice.types.TelecomManagerExtension.canReadPhoneNumbers
import com.twilio.voice.CallException
import com.twilio.voice.CallInvite
import com.twilio.voice.CancelledCallInvite
import com.twilio.voice.MessageListener
import com.twilio.voice.Voice
import com.twilio.twilio_voice.types.TelecomManagerExtension.canReadPhoneState
import com.twilio.twilio_voice.types.TelecomManagerExtension.hasCallCapableAccount

class VoiceFirebaseMessagingService : FirebaseMessagingService(), MessageListener {

    companion object {
        private const val TAG = "VoiceFirebaseMessagingService"

        // Second LocalBroadcast so Flutter can attach EventChannel / receiver if process cold-started.
        private const val FLUTTER_INCOMING_RETRY_MS = 750L

        /**
         * Action used with [EXTRA_TOKEN] to send the FCM token to the TwilioVoicePlugin
         */
        const val ACTION_NEW_TOKEN = "ACTION_NEW_TOKEN"

        /**
         * Extra used with [ACTION_NEW_TOKEN] to send the FCM token to the TwilioVoicePlugin
         */
        const val EXTRA_FCM_TOKEN = "token"

        /**
         * Extra used with [ACTION_NEW_TOKEN] to send the FCM token to the TwilioVoicePlugin
         */
        const val EXTRA_TOKEN = "token"

        /** Logcat filter: `adb logcat -s VoiceIncoming` */
        private const val LOG_VOICE_INCOMING = "VoiceIncoming"

        private const val INCOMING_CHANNEL_ID = "e_response_twilio_incoming_calls"
        private const val INCOMING_NOTIFICATION_ID = 92001
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private fun ensureIncomingNotificationChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (nm.getNotificationChannel(INCOMING_CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            INCOMING_CHANNEL_ID,
            "Incoming emergency calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Heads-up when a citizen VoIP call reaches this staff device (Twilio)."
            enableVibration(true)
        }
        nm.createNotificationChannel(ch)
    }

    /**
     * Staff/admin may miss the Flutter overlay when the app is backgrounded; mirror with a system notification.
     */
    private fun showIncomingCallNotification(callInvite: CallInvite) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            ensureIncomingNotificationChannel(nm)
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            launch?.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            val piFlags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            val pi = PendingIntent.getActivity(
                this,
                INCOMING_NOTIFICATION_ID,
                launch,
                piFlags,
            )
            val fromLine = callInvite.from?.trim()?.takeIf { it.isNotEmpty() } ?: "Citizen caller"
            val body = "Tap to open the app and answer.\nCallSid: ${callInvite.callSid}"
            val notification = NotificationCompat.Builder(this, INCOMING_CHANNEL_ID)
                .setSmallIcon(com.twilio.twilio_voice.R.drawable.ic_microphone)
                .setContentTitle("Incoming emergency call")
                .setContentText(fromLine)
                .setStyle(NotificationCompat.BigTextStyle().bigText("$fromLine\n$body"))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(pi)
                .setAutoCancel(true)
                .build()
            nm.notify(INCOMING_NOTIFICATION_ID, notification)
            Log.i(LOG_VOICE_INCOMING, "notification posted sid=${callInvite.callSid} from=$fromLine")
        } catch (e: Exception) {
            Log.e(LOG_VOICE_INCOMING, "showIncomingCallNotification failed", e)
        }
    }

    private fun cancelIncomingCallNotification() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(INCOMING_NOTIFICATION_ID)
            Log.i(LOG_VOICE_INCOMING, "notification cancelled")
        } catch (_: Exception) {
        }
    }

    /**
     * Brings task to foreground so FlutterEngine registers TwilioVoicePlugin's LocalBroadcastReceiver.
     */
    private fun bringActivityToFront() {
        mainHandler.post {
            try {
                val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return@post
                launch.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                )
                startActivity(launch)
            } catch (e: Exception) {
                Log.w(TAG, "bringActivityToFront: $e")
            }
        }
    }

    /**
     * Implicit action-only intents match dynamically registered [TVBroadcastReceiver] filters reliably.
     * Retries once after [FLUTTER_INCOMING_RETRY_MS] for cold start (engine not attached on first send).
     */
    private fun notifyFlutterIncomingCall(callInvite: CallInvite) {
        val intent = Intent(TVBroadcastReceiver.ACTION_INCOMING_CALL).apply {
            putExtra(TVBroadcastReceiver.EXTRA_CALL_INVITE, callInvite)
            putExtra(TVBroadcastReceiver.EXTRA_CALL_HANDLE, callInvite.callSid)
        }
        val lbm = LocalBroadcastManager.getInstance(applicationContext)
        lbm.sendBroadcast(intent)
        Log.i(LOG_VOICE_INCOMING, "LocalBroadcast ACTION_INCOMING_CALL sid=${callInvite.callSid}")
        mainHandler.postDelayed({
            Log.d(TAG, "notifyFlutterIncomingCall: delayed retry (cold start / engine attach)")
            lbm.sendBroadcast(intent)
            Log.i(LOG_VOICE_INCOMING, "LocalBroadcast ACTION_INCOMING_CALL (retry) sid=${callInvite.callSid}")
        }, FLUTTER_INCOMING_RETRY_MS)
    }

    override fun onNewToken(token: String) {
        val intent = Intent(ACTION_NEW_TOKEN).also {
            it.putExtra(EXTRA_FCM_TOKEN, token)
        }
        sendBroadcast(intent)
    }

    /**
     * Called when message is received.
     *
     * @param remoteMessage Object representing the message received from Firebase Cloud Messaging.
     */
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "Received onMessageReceived()")
        Log.d(TAG, "Bundle data: " + remoteMessage.data)
        Log.d(TAG, "From: " + remoteMessage.from)
        Log.i(LOG_VOICE_INCOMING, "FCM data keys=${remoteMessage.data.keys}")
        // If application is running in the foreground use local broadcast to handle message.
        // Otherwise use the background isolate to handle message.
        if (remoteMessage.data.isNotEmpty()) {
            val valid = Voice.handleMessage(this, remoteMessage.data, this)
            if (!valid) {
                Log.w(LOG_VOICE_INCOMING, "Not a Twilio Voice payload — forwarding to Flutter FCM")
                FlutterFcmForwarder.forwardToFlutterPlugin(applicationContext, remoteMessage)
            } else {
                Log.i(LOG_VOICE_INCOMING, "Twilio Voice SDK accepted FCM data (incoming call flow)")
            }
        } else if (remoteMessage.notification != null) {
            // Notification-only messages are never Twilio Voice control payloads.
            Log.i(LOG_VOICE_INCOMING, "Notification-only FCM — forwarding to Flutter FCM")
            FlutterFcmForwarder.forwardToFlutterPlugin(applicationContext, remoteMessage)
        }
    }

    //region MessageListener
    @RequiresPermission(allOf = [Manifest.permission.RECORD_AUDIO, Manifest.permission.READ_PHONE_STATE, Manifest.permission.READ_PHONE_NUMBERS])
    @SuppressLint("MissingPermission")
    override fun onCallInvite(callInvite: CallInvite) {
        Log.d(
            TAG,
            "onCallInvite: {\n\t" +
                    "CallSid: ${callInvite.callSid}, \n\t" +
                    "From: ${callInvite.from}, \n\t" +
                    "To: ${callInvite.to}, \n\t" +
                    "Parameters: ${callInvite.customParameters.entries.joinToString { "${it.key}:${it.value}" }},\n\t" +
                    "}"
        )
        bringActivityToFront()
        showIncomingCallNotification(callInvite)
        Log.i(LOG_VOICE_INCOMING, "onCallInvite sid=${callInvite.callSid} from=${callInvite.from} to=${callInvite.to}")

        // Get TelecomManager instance
        val tm = applicationContext.getSystemService(Context.TELECOM_SERVICE) as TelecomManager

        val shouldRejectOnNoPermissions: Boolean = StorageImpl(applicationContext).rejectOnNoPermissions
        var missingPermissions: Array<String> = emptyArray()

        // Check permission READ_PHONE_STATE
        if (!tm.canReadPhoneState(applicationContext)) {
            missingPermissions += "No `READ_PHONE_STATE` permission, cannot check if phone account is registered. Request this with `requestReadPhoneStatePermission()`"
        }

        // Check permission READ_PHONE_NUMBERS
        if (!tm.canReadPhoneNumbers(applicationContext)) {
            missingPermissions += "No `READ_PHONE_NUMBERS` permission, cannot communicate with ConnectionService if not granted. Request this with `requestReadPhoneNumbersPermission()`"
        }

        // NOTE(cybex-dev): Foreground services requiring privacy permission e.g. microphone or
        // camera are required to be started in the foreground. Since we're using the Telecom's
        // PhoneAccount, we don't directly require microphone access. Further, microphone access
        // is always denied if the app requiring microphone access via a Foreground service
        // is in the background (by design).
//        // Check permission RECORD_AUDIO
//        if (!applicationContext.hasMicrophoneAccess()) {
//            shouldRejectCall = true
//            requiredPermissions += "No `RECORD_AUDIO` permission, VoiceSDK requires this permission. Request this with `requestMicPermission()`"
//        }

        if(!tm.hasCallCapableAccount(applicationContext, TVConnectionService::class.java.name)) {
            missingPermissions += "No call capable phone account registered. Request this with `registerPhoneAccount()`"
        }

        // If we have missingPermissions, then we cannot proceed with answering the call.
        if (missingPermissions.isNotEmpty()) {
            missingPermissions.forEach { Log.e(TAG, it) }

            // If we're not rejecting on no permissions, still notify Flutter so in-app UI can ring.
            // Previously this path returned silently — staff never saw StaffVoiceBridge / incoming UI.
            if (!shouldRejectOnNoPermissions) {
                Log.w(
                    TAG,
                    "onCallInvite: Flutter-only path (Telecom skipped). Missing: " +
                            missingPermissions.joinToString("; ")
                )
                notifyFlutterIncomingCall(callInvite)
                return
            }

            Log.e(TAG, "onCallInvite: Rejecting incoming call\nSID: ${callInvite.callSid}")
            // send broadcast to TVBroadcastReceiver, we notify Flutter about incoming call
            Intent(TVBroadcastReceiver.ACTION_INCOMING_CALL_IGNORED).apply {
                putExtra(TVBroadcastReceiver.EXTRA_INCOMING_CALL_IGNORED_REASON, missingPermissions)
                putExtra(TVBroadcastReceiver.EXTRA_CALL_HANDLE, callInvite.callSid)
                LocalBroadcastManager.getInstance(applicationContext).sendBroadcast(this)
            }

            // Reject incoming call
            Log.d(TAG, "onCallInvite: Rejecting incoming call")
            callInvite.reject(applicationContext)

            return
        }

        // send broadcast to TVConnectionService, we notify the TelecomManager about incoming call
        Intent(applicationContext, TVConnectionService::class.java).apply {
            action = TVConnectionService.ACTION_INCOMING_CALL
            putExtra(TVConnectionService.EXTRA_INCOMING_CALL_INVITE, callInvite)
            applicationContext.startService(this)
        }

        notifyFlutterIncomingCall(callInvite)
    }

    override fun onCancelledCallInvite(cancelledCallInvite: CancelledCallInvite, callException: CallException?) {
        Log.d(TAG, "onCancelledCallInvite: ", callException)
        cancelIncomingCallNotification()
        Log.i(LOG_VOICE_INCOMING, "onCancelledCallInvite sid=${cancelledCallInvite.callSid}")
        Intent(applicationContext, TVConnectionService::class.java).apply {
            action = TVConnectionService.ACTION_CANCEL_CALL_INVITE
            putExtra(TVConnectionService.EXTRA_CANCEL_CALL_INVITE, cancelledCallInvite)
//            applicationContext.startService(this)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(this) // Ensure it's started as a foreground service
            } else {
                applicationContext.startService(this)
            }
        }
    }
    //endregion
}