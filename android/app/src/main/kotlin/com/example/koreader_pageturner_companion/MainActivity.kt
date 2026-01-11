// android/app/src/main/kotlin/com/example/koreader_pageturner_companion/MainActivity.kt
package com.example.koreader_pageturner_companion

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "volume_buttons"
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                channel.invokeMethod("volumeUp", null)
                return true // consume event
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                channel.invokeMethod("volumeDown", null)
                return true // consume event
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
