package com.taiwanmate.chinesemate

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.taiwanmate.chinesemate/process_text"
    private var methodChannel: MethodChannel? = null
    private var pendingText: String? = null
    private var pendingEmergency: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getProcessText" -> {
                    result.success(pendingText)
                    pendingText = null
                }
                "getPendingEmergency" -> {
                    result.success(pendingEmergency)
                    pendingEmergency = false
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_PROCESS_TEXT && intent.type == "text/plain") {
            val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            if (!text.isNullOrEmpty()) {
                pendingText = text
                methodChannel?.invokeMethod("onProcessText", text)
            }
        }

        if (intent?.action == "OPEN_EMERGENCY") {
            pendingEmergency = true
            methodChannel?.invokeMethod("onOpenEmergency", null)
        }
    }
}