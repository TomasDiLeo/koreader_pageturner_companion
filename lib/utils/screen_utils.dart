import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';


class ScreenUtils {
  /// Hides the system UI (immersive mode)
  static Future<void> enableImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  /// Restores the system UI
  static Future<void> disableImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge, 
    );
  }

  /// Prevents the screen from turning off automatically
  static Future<void> keepScreenOn() async {
    await WakelockPlus.enable();
  }

  /// Allows the screen to turn off automatically
  static Future<void> allowScreenOff() async {
    await WakelockPlus.disable();
  }

  /// Sets the screen brightness (0.0 to 1.0)
  static Future<void> setBrightness(double brightness) async {
    try {
      await ScreenBrightness().setScreenBrightness(brightness);
    } catch (e) {
      // Ignore errors if brightness control is not supported or fails
      print('Failed to set brightness: $e');
    }
  }

  /// Resets the screen brightness to system default
  static Future<void> resetBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (e) {
      print('Failed to reset brightness: $e');
    }
  }
}
