import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service for communicating with KOReader HTTP Inspector API
class KOReaderService {
  final String ip;
  final int port;
  final Function(String)? onStatusUpdate;

  KOReaderService({
    required this.ip,
    required this.port,
    this.onStatusUpdate,
  });

  String get baseUrl => 'http://$ip:$port/koreader';

  /// Generic Command Method
  Future<void> _sendCommand(String command, [String params = '']) async {
    String fullCommand = command;
    if (params.isNotEmpty) {
      fullCommand += '/$params';
    }

    final uri = Uri.parse('$baseUrl/event/$fullCommand');

    _updateStatus('Sending command to $ip...');

    try {
      await http.get(uri);
      _updateStatus('Command sent to $ip');
    } catch (e) {
      debugPrint('HTTP error: $e');
      _updateStatus('Error: No Device Found');
    }
  }

  void _updateStatus(String status) {
    onStatusUpdate?.call(status);
  }

  //Navigation Methods

  Future<void> turnPage(int direction) async {
    await _sendCommand("GotoViewRel", direction.toString());
  }

  Future<void> goBackLink() async {
    await _sendCommand("GoBackLink", "true");
  }

  Future<void> goForwardLink() async {
    await _sendCommand("GoForwardLink", "true");
  }

  Future<void> back() async {
    await _sendCommand("Back");
  }

  //Display Methods

  Future<void> refreshScreen() async {
    await _sendCommand("FullRefresh");
  }

  Future<void> toggleFrontlight() async {
    await _sendCommand("ToggleFrontlight");
  }

  Future<void> setFrontLightIntensity(int intensity) async {
    await _sendCommand("SetFlIntensity", intensity.toString());
  }

  Future<void> setWarmth(int warmth) async {
    await _sendCommand("SetFlWarmth", warmth.toString());
  }

  Future<void> toggleNightMode() async {
    await _sendCommand("ToggleNightMode");
  }

  Future<void> executeProfile(String profileName) async {
    await _sendCommand("ProfileExecute", profileName);
  }

  Future<int> getFlIntensity() async {
    try {
      final uri = Uri.parse(
        '$baseUrl/device/powerd/fl_intensity',
      );

      _updateStatus('Fetching fl_intensity from KOReader...');
      final response = await http.get(uri);

      final int flIntensity = int.parse(response.body.trim());
      debugPrint('FL Intensity: $flIntensity');
      return flIntensity;
    } catch (e) {
      _updateStatus("Error: Can't fetch Front Light");
      return 0;
    }
  }

  Future<int> getFlWarmth() async {
    try {
      final uri = Uri.parse(
        '$baseUrl/device/powerd/fl_warmth',
      );

      _updateStatus('Fetching flWarmth from KOReader...');
      final response = await http.get(uri);
      final int flWarmth = int.parse(response.body.trim());
      debugPrint('FL Warmth: $flWarmth');
      return flWarmth;
    } catch (e) {
      _updateStatus("Error: Can't fetch Warmth");
      return 0;
    }
  }

  //Input Text Methods

  Future<String?> getText() async {
    try {
      final uri = Uri.parse(
        '$baseUrl/UIManager/_window_stack/2/widget/_input_widget/getText?/',
      );

      _updateStatus('Fetching text from KOReader...');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        RegExp exp = RegExp(r'\["([^"]*)"\]');
        final decodedText = utf8.decode(response.bodyBytes);
        final match = exp.firstMatch(decodedText);

        _updateStatus('Text loaded successfully');
        return match?.group(1);
      } else {
        _updateStatus('Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching text: $e');
      _updateStatus("Error Fetching the text. Make sure there is an Input Box opened");
      return null;
    }
  }

  Future<void> deleteAllText() async {
    try {
      final uri = Uri.parse(
        '$baseUrl/UIManager/_window_stack/2/widget/_input_widget/delAll?/',
      );
      await http.get(uri);
      _updateStatus('Text cleared');
    } catch (e) {
      debugPrint('Error clearing text: $e');
      _updateStatus("Error clearing the text. Make sure there is an Input Box opened");
    }
  }

  Future<void> addChars(String text) async {
    try {
      final encoded = Uri.encodeComponent(text);
      final uri = Uri.parse(
        '$baseUrl/UIManager/_window_stack/2/widget/_input_widget/addChars/$encoded',
      );
      await http.get(uri);
    } catch (e) {
      debugPrint('Error adding chars: $e');
      _updateStatus('Error writtin to KoReader. Make sure there is an Input Box opened');
    }
  }

  Future<void> sendText(String text) async {
    try {
      _updateStatus('Sending text to KOReader...');

      await deleteAllText();

      final parts = text.split('/');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          await addChars(parts[i]);
        }
        if (i < parts.length - 1) {
          await addChars('"/"');
        }
      }

      _updateStatus('Text sent successfully');
    } catch (e) {
      debugPrint('Error sending text: $e');
      _updateStatus('Error Sending text to KoReader. Make sure there is an Input Box opened');
    }
  }

  //Conection

  Future<bool> isConnected() async {
    try {
      final uri = Uri.parse(
        baseUrl,
      );

      final response = await http.get(uri);
      if(response.body != ""){
        return true;
      }else{
        throw("No body");
      }
    } catch (e) {
      _updateStatus('No Device Found');
      return false;
    }
  }
}
