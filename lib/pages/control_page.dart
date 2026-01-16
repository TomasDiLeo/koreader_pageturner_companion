import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Models
import 'package:pageturner_app/models/volume_button_action.dart';
//Pages
import 'package:pageturner_app/pages/text_editor_page.dart';
import 'package:pageturner_app/pages/connection_page.dart';

//THEN RESOLVE TO KOREADER SERVICE
import 'package:http/http.dart' as http;

class ControlPage extends StatefulWidget {
  final String ip;
  final int port;
  final VoidCallback onToggleTheme;

  const ControlPage({
    super.key,
    required this.ip,
    required this.port,
    required this.onToggleTheme,
  });

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  VolumeButtonAction _volumeUpAction = VolumeButtonAction.next;
  VolumeButtonAction _volumeDownAction = VolumeButtonAction.prev;

  int _frontLight = 0;
  int _auxFrontLight = 0;
  bool isFrontLightDisabled = false;
  int _warmLight = 0;
  int _auxWarmLight = 0;
  bool isWarmLightDisabled = false;

  static const MethodChannel _channel = MethodChannel('volume_buttons');

  @override
  void initState() {
    super.initState();
    _loadVolumeButtonSettings();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUp') {
        _turnPage(_volumeUpAction.command);
      } else if (call.method == 'volumeDown') {
        _turnPage(_volumeDownAction.command);
      }
    });
  }

  Future<void> _loadVolumeButtonSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final upIndex =
        prefs.getInt('volume_up_action') ?? VolumeButtonAction.next.index;
    final downIndex =
        prefs.getInt('volume_down_action') ?? VolumeButtonAction.prev.index;

    setState(() {
      _volumeUpAction = VolumeButtonAction.values[upIndex];
      _volumeDownAction = VolumeButtonAction.values[downIndex];
    });
  }

  Future<void> _saveVolumeButtonSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('volume_up_action', _volumeUpAction.index);
    await prefs.setInt('volume_down_action', _volumeDownAction.index);
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        VolumeButtonAction tempVolumeUp = _volumeUpAction;
        VolumeButtonAction tempVolumeDown = _volumeDownAction;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                'Volume Button Settings',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Volume Up Button',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...VolumeButtonAction.values.map((action) {
                    return RadioListTile<VolumeButtonAction>(
                      title: Text(
                        action.displayName,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      value: action,
                      groupValue: tempVolumeUp,
                      activeColor: Theme.of(context).colorScheme.onSurface,
                      onChanged: (VolumeButtonAction? value) {
                        if (value != null) {
                          setDialogState(() {
                            tempVolumeUp = value;
                          });
                        }
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  Text(
                    'Volume Down Button',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...VolumeButtonAction.values.map((action) {
                    return RadioListTile<VolumeButtonAction>(
                      title: Text(
                        action.displayName,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      value: action,
                      groupValue: tempVolumeDown,
                      activeColor: Theme.of(context).colorScheme.onSurface,
                      onChanged: (VolumeButtonAction? value) {
                        if (value != null) {
                          setDialogState(() {
                            tempVolumeDown = value;
                          });
                        }
                      },
                    );
                  }).toList(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'CANCEL',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _volumeUpAction = tempVolumeUp;
                      _volumeDownAction = tempVolumeDown;
                    });
                    _saveVolumeButtonSettings();
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Settings saved'),
                        backgroundColor:
                            isDark ? Colors.grey[800] : Colors.grey[700],
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    'SAVE',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendCommand(String command, String param) async {
    if (param.isNotEmpty) {
      command += '/$param';
    }

    final uri = Uri.parse(
      'http://${widget.ip}:${widget.port}/koreader/event/$command',
    );

    try {
      await http.get(uri);
    } catch (e) {
      debugPrint('HTTP error: $e');
    }
  }

  Future<void> _turnPage(int direction) async {
    _sendCommand("GotoViewRel", direction.toString());
  }

  Future<void> _toggleFrontLight() async {
    if (!isFrontLightDisabled) {
      setState(() {
        _auxFrontLight = _frontLight;
        _frontLight = 0;
      });
      await _sendCommand("ToggleFrontlight", "");
      isFrontLightDisabled = true;
    } else {
      setState(() {
        _frontLight = _auxFrontLight;
      });
      await _sendCommand("SetFlIntensity", _frontLight.toString());
      isFrontLightDisabled = false;
    }
  }

  Future<void> _toggleWarmth() async {
    if (!isWarmLightDisabled) {
      setState(() {
        _auxWarmLight = _warmLight;
        _warmLight = 0;
      });
      await _sendCommand("SetFlWarmth", "0");
      isWarmLightDisabled = true;
    } else {
      setState(() {
        _warmLight = _auxWarmLight;
      });
      await _sendCommand("SetFlWarmth", _warmLight.toString());
      isWarmLightDisabled = false;
    }
  }

  void _openTextEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextEditorPage(
          ip: widget.ip,
          port: widget.port,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.onSurface,
                width: 1,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            leading: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/chevron.left.svg',
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConnectionPage(
                      onToggleTheme: widget.onToggleTheme,
                    ),
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.keyboard),
                onPressed: _openTextEditor,
                tooltip: 'Virtual Keyboard',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showSettingsDialog,
                tooltip: 'Volume Button Settings',
              ),
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: widget.onToggleTheme,
                tooltip:
                    isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('  Adjust Front Light and Warmth',
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 10, thickness: .2, indent: 0, endIndent: 0),
            Row(
              children: [
                IconButton(
                    onPressed: () async {
                      await _toggleFrontLight();
                    },
                    icon: Icon(_frontLight > 0
                        ? Icons.light_mode
                        : Icons.light_mode_outlined)),
                Expanded(
                  child: Slider(
                    value: _frontLight.toDouble(),
                    min: 0.0,
                    max: 24.0,
                    inactiveColor: Colors.teal.withValues(alpha: 0.3),
                    onChanged: (double newValue) async {
                      if (isFrontLightDisabled) {
                        await _toggleFrontLight();
                      }
                      _sendCommand(
                          "SetFlIntensity", newValue.toInt().toString());
                      setState(() {
                        _frontLight = newValue.toInt();
                      });
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                    onPressed: () async {
                      await _toggleWarmth();
                    },
                    icon: Icon(_warmLight == 0
                        ? Icons.wb_iridescent_outlined
                        : Icons.wb_iridescent_rounded)),
                Expanded(
                  child: Slider(
                    value: _warmLight.toDouble(),
                    min: 0.0,
                    max: 100.0,
                    inactiveColor: Colors.teal.withValues(alpha: 0.3),
                    onChanged: (double newValue) async {
                      if (isWarmLightDisabled) {
                        await _toggleWarmth();
                      }
                      _sendCommand("SetFlWarmth", newValue.toInt().toString());
                      setState(() {
                        _warmLight = newValue.toInt();
                      });
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 10, thickness: .2, indent: 0, endIndent: 0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                    onPressed: () {
                      _sendCommand("ProfileExecute", "Normal");
                    },
                    child: const Text('Normal')),
                IconButton(
                  icon: const Icon(
                    Icons.settings_brightness,
                  ),
                  onPressed: () async {
                    await _sendCommand("ToggleNightMode", "");
                  },
                  tooltip: isDark
                      ? 'Switch to Light Mode KOReader'
                      : 'Switch to Dark Mode KOReader',
                ),
                TextButton(
                    onPressed: () {
                      _sendCommand("ProfileExecute", "Sleep");
                    },
                    child: const Text('Sleep')),
              ],
            ),
            const Divider(height: 10, thickness: .2, indent: 0, endIndent: 0),
            const SizedBox(height: 5),
            Text(
              'Page Turning',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              'Use the volume buttons to turn pages!',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              'Vol Up: ${_volumeUpAction.displayName} | Vol Down: ${_volumeDownAction.displayName}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _turnPage(-1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/chevron.left.svg',
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'PREVIOUS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _turnPage(1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/chevron.right.svg',
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'NEXT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        _sendCommand("GoBackLink", "true");
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Icon(Icons.link),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    _sendCommand("Back", "");
                  },
                  icon: const Icon(Icons.restart_alt),
                ),
                Row(
                  children: [
                    const Icon(Icons.link),
                    IconButton(
                      onPressed: () {
                        _sendCommand("GoForwardLink", "true");
                      },
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Make sure KOReader is running and HTTP Inspector is enabled in settings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}