package com.example.e_response_app_nemsu
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.twilio/phone_account"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "openPhoneAccountSettings") {
                try {
                    val intent = Intent("android.settings.MANAGE_ALL_PHONE_ACCOUNTS_SETTINGS")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Could not launch phone account settings.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
