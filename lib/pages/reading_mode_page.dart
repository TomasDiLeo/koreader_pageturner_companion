import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pageturner_app/utils/screen_utils.dart';

class ReadingModePage extends StatefulWidget {
  final String ip;
  final int port;

  const ReadingModePage({
    super.key,
    required this.ip,
    required this.port,
  });

  @override
  State<ReadingModePage> createState() => _ReadingModePageState();
}

class _ReadingModePageState extends State<ReadingModePage> {
  bool _showIndicators = true;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _enterReadingMode();
  }

  Future<void> _enterReadingMode() async {
    await ScreenUtils.enableImmersiveMode();
    await ScreenUtils.keepScreenOn();
    
    // Hide indicators after 5 seconds and lower brightness
    _indicatorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showIndicators = false;
        });
        ScreenUtils.setBrightness(0.01); // Very dim but visible
      }
    });
  }

  Future<void> _exitReadingMode() async {
    await ScreenUtils.disableImmersiveMode();
    await ScreenUtils.allowScreenOff();
    await ScreenUtils.resetBrightness();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    // Ensure we clean up if the widget is disposed unexpectedly
    ScreenUtils.disableImmersiveMode();
    ScreenUtils.allowScreenOff();
    ScreenUtils.resetBrightness();
    super.dispose();
  }

  Future<void> _sendCommand(String command) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final data = command.codeUnits;
      socket.send(data, InternetAddress(widget.ip), widget.port);
      socket.close();
    } catch (e) {
      debugPrint('Error sending command: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _exitReadingMode();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Double tap detector (lowest priority in visual stack but catches strictly double taps)
            // We place it at the root but visually it might interfere if not handled carefully.
            // Actually, we want it to detect double tap ANYWHERE.
            GestureDetector(
              onDoubleTap: _exitReadingMode,
              behavior: HitTestBehavior.translucent, // Allow clicks to pass through if needed, but here it's the background
              child: SizedBox.expand(
                child: Container(color: Colors.transparent),
              ),
            ),
            
            // Top Zone (Next)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _sendCommand('NEXT'),
                  onDoubleTap: _exitReadingMode, // Pass through double tap
                  splashColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.05),
                  child: Container(),
                ),
              ),
            ),

            // Bottom Zone (Prev)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _sendCommand('PREV'),
                  onDoubleTap: _exitReadingMode, // Pass through double tap
                  splashColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.05),
                  child: Container(),
                ),
              ),
            ),

            // Indicators
            IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _showIndicators ? 1.0 : 0.0,
                child: Stack(
                  children: [
                    // Top Hint
                    Positioned(
                      top: 40,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: const [
                          Icon(Icons.arrow_upward, color: Colors.white54, size: 24),
                          SizedBox(height: 4),
                          Text('Tap to Next', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                    // Bottom Hint
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: const [
                          Text('Tap to Prev', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          SizedBox(height: 4),
                          Icon(Icons.arrow_downward, color: Colors.white54, size: 24),
                        ],
                      ),
                    ),
                    // Center Hint
                    Center(
                      child: Text(
                        'Double tap to exit',
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
