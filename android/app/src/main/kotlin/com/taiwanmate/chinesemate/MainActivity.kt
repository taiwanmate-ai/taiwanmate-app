package com.taiwanmate.chinesemate

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.taiwanmate.chinesemate/process_text"
    private var methodChannel: MethodChannel? = null
    private var pendingText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Flutter gọi hàm này lúc khởi động để lấy text (trường hợp app đang đóng, mở mới từ PROCESS_TEXT)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getProcessText") {
                result.success(pendingText)
                pendingText = null
            } else {
                result.notImplemented()
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
                // Trường hợp app đang chạy nền (singleTop) → bắn thẳng sang Flutter ngay
                methodChannel?.invokeMethod("onProcessText", text)
            }
        }
    }
}