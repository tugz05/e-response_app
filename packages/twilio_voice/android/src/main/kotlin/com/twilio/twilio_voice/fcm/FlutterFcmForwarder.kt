package com.twilio.twilio_voice.fcm

import android.content.Context
import android.content.Intent
import android.os.Parcel
import android.util.Log
import com.google.firebase.messaging.RemoteMessage

/**
 * Forwards non-Twilio FCM payloads to the FlutterFire [firebase_messaging] plugin.
 *
 * The host app removes [io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService]
 * so Twilio owns [MESSAGING_EVENT]; general notifications must be delegated here when
 * [com.twilio.voice.Voice.handleMessage] returns false.
 *
 * Uses reflection so the Twilio plugin AAR does not need a compile dependency on FlutterFire.
 */
object FlutterFcmForwarder {
    private const val TAG = "FlutterFcmForwarder"

    private const val FLUTTER_FIREBASE_UTILS =
        "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingUtils"
    private const val FLUTTER_REMOTE_MESSAGE_LIVE_DATA =
        "io.flutter.plugins.firebase.messaging.FlutterFirebaseRemoteMessageLiveData"
    private const val FLUTTER_BACKGROUND_SERVICE =
        "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService"

    @JvmStatic
    fun forwardToFlutterPlugin(context: Context, remoteMessage: RemoteMessage): Boolean {
        return try {
            val utilsClass = Class.forName(FLUTTER_FIREBASE_UTILS)
            val isForeground = utilsClass
                .getMethod("isApplicationForeground", Context::class.java)
                .invoke(null, context) as Boolean

            if (isForeground) {
                val ldc = Class.forName(FLUTTER_REMOTE_MESSAGE_LIVE_DATA)
                val instance = ldc.getMethod("getInstance").invoke(null)
                ldc.getMethod("postRemoteMessage", RemoteMessage::class.java)
                    .invoke(instance, remoteMessage)
                Log.d(TAG, "Forwarded to Flutter (foreground LiveData)")
            } else {
                val extraField = utilsClass.getDeclaredField("EXTRA_REMOTE_MESSAGE")
                extraField.isAccessible = true
                val extraKey = extraField.get(null) as String

                val bgClass = Class.forName(FLUTTER_BACKGROUND_SERVICE)
                @Suppress("UNCHECKED_CAST")
                val intent = Intent(context, bgClass as Class<*>)
                val parcel = Parcel.obtain()
                try {
                    remoteMessage.writeToParcel(parcel, 0)
                    intent.putExtra(extraKey, parcel.marshall())
                } finally {
                    parcel.recycle()
                }

                val highPriority =
                    remoteMessage.originalPriority == RemoteMessage.PRIORITY_HIGH
                val enqueue = bgClass.getMethod(
                    "enqueueMessageProcessing",
                    Context::class.java,
                    Intent::class.java,
                    Boolean::class.javaPrimitiveType,
                )
                enqueue.invoke(null, context, intent, highPriority)
                Log.d(TAG, "Forwarded to Flutter (background JobIntentService)")
            }
            true
        } catch (e: Throwable) {
            Log.w(TAG, "Forward to Flutter firebase_messaging failed: ${e.message}")
            false
        }
    }
}
