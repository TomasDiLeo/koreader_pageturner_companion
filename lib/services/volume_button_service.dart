import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/volume_button_action.dart';

/// Service for handling volume button events and settings
class VolumeButtonService {
  static const MethodChannel _channel = MethodChannel('volume_buttons');

  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDown;

  VolumeButtonService({
    required this.onVolumeUp,
    required this.onVolumeDown,
  }) {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUp') {
        onVolumeUp();
      } else if (call.method == 'volumeDown') {
        onVolumeDown();
      }
    });
  }

  /// Load volume button settings from persistent storage
  static Future<VolumeButtonSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final upIndex =
        prefs.getInt('volume_up_action') ?? VolumeButtonAction.next.index;
    final downIndex =
        prefs.getInt('volume_down_action') ?? VolumeButtonAction.prev.index;

    return VolumeButtonSettings(
      volumeUpAction: VolumeButtonAction.values[upIndex],
      volumeDownAction: VolumeButtonAction.values[downIndex],
    );
  }

  /// Save volume button settings to persistent storage
  static Future<void> saveSettings(VolumeButtonSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('volume_up_action', settings.volumeUpAction.index);
    await prefs.setInt('volume_down_action', settings.volumeDownAction.index);
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}

/// Model class for volume button settings
class VolumeButtonSettings {
  final VolumeButtonAction volumeUpAction;
  final VolumeButtonAction volumeDownAction;

  VolumeButtonSettings({
    required this.volumeUpAction,
    required this.volumeDownAction,
  });
}