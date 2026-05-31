package com.example.e_response_app_nemsu

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.twilio/phone_account"

    override fun configureFlutterEngine(
        flutterEngine: io.flutter.embedding.engine.FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openPhoneAccountSettings" -> {
                    try {
                        val intent = Intent("android.settings.MANAGE_ALL_PHONE_ACCOUNTS_SETTINGS")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not launch phone account settings.", null)
                    }
                }

                "openPermissionSettings" -> {
                    // On Android 11+ (API 30), "android.settings.MANAGE_APP_PERMISSIONS" goes
                    // directly to the per-app Permissions screen.  It is not a public SDK symbol
                    // so we pass the action as a plain string to avoid compilation errors.
                    // On older versions we fall back to the documented App-Info page where
                    // "Permissions" is listed at the top.
                    val opened = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        tryStart(
                            Intent("android.settings.MANAGE_APP_PERMISSIONS").apply {
                                putExtra("android.intent.extra.PACKAGE_NAME", packageName)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        )
                    } else false

                    if (!opened) {
                        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        if (tryStart(fallback)) {
                            result.success(null)
                        } else {
                            result.error("UNAVAILABLE", "Could not launch permission settings.", null)
                        }
                    } else {
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /** Attempts to start [intent]; returns true on success, false if the activity was not found. */
    private fun tryStart(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
