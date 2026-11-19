package com.example.budget_app

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tally/system-colours")
            .setMethodCallHandler { call, result ->
                if (call.method != "getAccent") {
                    result.notImplemented()
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val accent = getColor(android.R.color.system_accent1_500).toLong() and 0xffffffffL
                    result.success(accent)
                } else {
                    result.success(null)
                }
            }
    }
}
