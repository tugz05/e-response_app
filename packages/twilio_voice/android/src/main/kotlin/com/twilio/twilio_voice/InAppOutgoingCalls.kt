package com.twilio.twilio_voice

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.twilio.twilio_voice.receivers.TVBroadcastReceiver
import com.twilio.twilio_voice.types.CallDirection
import com.twilio.twilio_voice.types.CallExceptionExtension.toBundle
import com.twilio.twilio_voice.types.TVNativeCallEvents
import com.twilio.voice.Call
import com.twilio.voice.CallException
import com.twilio.voice.ConnectOptions
import com.twilio.voice.Voice

/**
 * Outbound VoIP via [Voice.connect] only — no [android.telecom.TelecomManager.placeCall],
 * so the system Phone / default dialer is not used. Call UI stays in the Flutter app.
 *
 * Incoming calls still use [com.twilio.twilio_voice.service.TVConnectionService] / PhoneAccount.
 */
object InAppOutgoingCalls {
    private const val TAG = "InAppOutgoingCalls"

    @Volatile
    private var activeCall: Call? = null

    private var lastFrom: String = ""
    private var lastTo: String = ""

    fun isActive(): Boolean {
        val c = activeCall ?: return false
        return when (c.state) {
            Call.State.CONNECTING,
            Call.State.RINGING,
            Call.State.CONNECTED,
            Call.State.RECONNECTING,
            -> true
            else -> false
        }
    }

    fun getActiveSid(): String? = activeCall?.sid

    private fun appCtx(ctx: Context): Context = ctx.applicationContext

    private fun send(ctx: Context, action: String, extras: Bundle) {
        val intent = Intent(action)
        intent.putExtras(extras)
        LocalBroadcastManager.getInstance(appCtx(ctx)).sendBroadcast(intent)
    }

    private fun callExtras(call: Call, from: String, to: String): Bundle =
        Bundle().apply {
            putString(TVBroadcastReceiver.EXTRA_CALL_HANDLE, call.sid ?: "")
            putString(TVBroadcastReceiver.EXTRA_CALL_FROM, from)
            putString(TVBroadcastReceiver.EXTRA_CALL_TO, to)
            putInt(TVBroadcastReceiver.EXTRA_CALL_DIRECTION, CallDirection.OUTGOING.id)
        }

    fun start(
        ctx: Context,
        accessToken: String,
        from: String,
        to: String,
        params: Map<String, String>,
    ): Boolean {
        disconnectQuiet()
        lastFrom = from
        lastTo = to

        val connectParams = LinkedHashMap<String, String>()
        params.forEach { (k, v) -> connectParams[k] = v }
        connectParams["From"] = from
        connectParams["To"] = to

        val options = ConnectOptions.Builder(accessToken)
            .params(connectParams)
            .build()

        val listener = object : Call.Listener {
            override fun onConnectFailure(call: Call, callException: CallException) {
                Log.e(TAG, "onConnectFailure: ${callException.errorCode} ${callException.message}")
                send(ctx, TVNativeCallEvents.EVENT_CONNECT_FAILURE, callException.toBundle())
                if (activeCall === call) {
                    activeCall = null
                }
            }

            override fun onRinging(call: Call) {
                Log.d(TAG, "onRinging sid=${call.sid}")
                activeCall = call
                send(ctx, TVNativeCallEvents.EVENT_RINGING, callExtras(call, lastFrom, lastTo))
            }

            override fun onConnected(call: Call) {
                Log.d(TAG, "onConnected sid=${call.sid}")
                activeCall = call
                send(ctx, TVNativeCallEvents.EVENT_CONNECTED, callExtras(call, lastFrom, lastTo))
            }

            override fun onReconnecting(call: Call, callException: CallException) {
                val b = callExtras(call, lastFrom, lastTo)
                b.putAll(callException.toBundle())
                send(ctx, TVNativeCallEvents.EVENT_RECONNECTING, b)
            }

            override fun onReconnected(call: Call) {
                send(ctx, TVNativeCallEvents.EVENT_RECONNECTED, callExtras(call, lastFrom, lastTo))
            }

            override fun onDisconnected(call: Call, error: CallException?) {
                Log.d(TAG, "onDisconnected: ${error?.message}")
                val b = Bundle()
                error?.let { b.putAll(it.toBundle()) }
                send(ctx, TVNativeCallEvents.EVENT_DISCONNECTED_REMOTE, b)
                if (activeCall === call) {
                    activeCall = null
                }
            }
        }

        val c = Voice.connect(appCtx(ctx), options, listener)
        if (c == null) {
            Log.e(TAG, "Voice.connect returned null")
            return false
        }
        activeCall = c
        Log.d(TAG, "Voice.connect returned call state=${c.state}")
        return true
    }

    private fun disconnectQuiet() {
        try {
            activeCall?.disconnect()
        } catch (_: Throwable) {
            // ignore
        }
        activeCall = null
    }

    fun hangUp(): Boolean {
        val c = activeCall ?: return false
        try {
            c.disconnect()
        } catch (_: Throwable) {
            // ignore
        }
        activeCall = null
        return true
    }

    fun setMute(mute: Boolean): Boolean {
        val c = activeCall ?: return false
        c.mute(mute)
        return true
    }

    @Suppress("DEPRECATION")
    fun setSpeaker(ctx: Context, on: Boolean): Boolean {
        if (activeCall == null) return false
        val am = appCtx(ctx).getSystemService(Context.AUDIO_SERVICE) as AudioManager
        am.mode = AudioManager.MODE_IN_COMMUNICATION
        am.isSpeakerphoneOn = on
        return true
    }

    fun setHold(hold: Boolean): Boolean {
        val c = activeCall ?: return false
        c.hold(hold)
        return true
    }

    fun sendDigits(digits: String): Boolean {
        val c = activeCall ?: return false
        c.sendDigits(digits)
        return true
    }

    fun setBluetooth(@Suppress("UNUSED_PARAMETER") ctx: Context, @Suppress("UNUSED_PARAMETER") on: Boolean): Boolean {
        return activeCall != null
    }
}
