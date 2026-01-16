import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool('is_dark_mode', newMode == ThemeMode.dark);
    setState(() {
      _themeMode = newMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Page Turner App',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black,
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.black),
          prefixIconColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.white,
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white70),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
        ),
      ),
      home: ConnectionPage(onToggleTheme: _toggleTheme),
    );
  }
}

class ConnectionPage extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const ConnectionPage({super.key, required this.onToggleTheme});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  String _status = 'Enter KOReader device IP address';
  String _lastIpHint = '192.168.1.100';

  @override
  void initState() {
    super.initState();
    _portController.text = '8080';
    _loadLastIp();
  }

  Future<void> _loadLastIp() async {
    final prefs = await SharedPreferences.getInstance();
    final lastIp = prefs.getString('last_ip');
    setState(() {
      if (lastIp != null && lastIp.isNotEmpty) {
        _lastIpHint = lastIp;
        _ipController.text = lastIp;
      } else {
        _ipController.text = _lastIpHint;
      }
    });
  }

  Future<void> _saveLastIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_ip', ip);
  }

  void _connect() async {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();

    if (ip.isEmpty) {
      setState(() {
        _status = 'Please enter an IP address';
      });
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      setState(() {
        _status = 'Please enter a valid port (1-65535)';
      });
      return;
    }

    await _saveLastIp(ip);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ControlPage(
            ip: ip,
            port: port,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image(
                        image: const AssetImage('assets/icons/koreader.png'),
                        height: 80,
                        fit: BoxFit.contain,
                        colorBlendMode: isDark ? BlendMode.srcIn : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Page Turner App',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.normal,
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: 'KOReader device IP Address',
                      border: const OutlineInputBorder(),
                      hintText: _lastIpHint,
                      prefixIcon: const Icon(Icons.device_hub),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: true,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                      hintText: '8080',
                      prefixIcon: Icon(Icons.settings_ethernet),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: true,
                  ),
                  Text(
                    'Default port is 8080 unless changed in the HTTP Inspector settings on KOReader.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 40),
                  OutlinedButton(
                    onPressed: _connect,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      disabledBackgroundColor:
                          Theme.of(context).colorScheme.surface,
                    ),
                    child: const Text(
                      'CONNECT',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey,
                      ),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color.fromARGB(255, 108, 108, 108),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: widget.onToggleTheme,
                tooltip:
                    isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }
}

enum VolumeButtonAction {
  next,
  prev,
}

extension VolumeButtonActionExtension on VolumeButtonAction {
  String get displayName {
    switch (this) {
      case VolumeButtonAction.next:
        return 'Next Page';
      case VolumeButtonAction.prev:
        return 'Previous Page';
    }
  }

  int get command {
    switch (this) {
      case VolumeButtonAction.next:
        return 1;
      case VolumeButtonAction.prev:
        return -1;
    }
  }
}

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
  String _status = 'Connected';
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

    setState(() {
      _status = 'Sending command to ${widget.ip}...';
    });

    try {
      await http.get(uri);
      setState(() {
        _status = 'Command sent to ${widget.ip}';
      });
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

class TextEditorPage extends StatefulWidget {
  final String ip;
  final int port;
  final VoidCallback onToggleTheme;

  const TextEditorPage({
    super.key,
    required this.ip,
    required this.port,
    required this.onToggleTheme,
  });

  @override
  State<TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  String _status = 'Ready';

  @override
  void initState() {
    _getText();
    super.initState();
  }

  Future<void> _getText() async {
    setState(() {
      _isLoading = true;
      _status = 'Fetching text from KOReader...';
    });

    try {
      final uri = Uri.parse(
        'http://${widget.ip}:${widget.port}/koreader/UIManager/_window_stack/2/widget/_input_widget/getText?/',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        RegExp exp = RegExp(r'\["([^"]*)"\]');
        final decodedText = utf8.decode(response.bodyBytes);

        final match = exp.firstMatch(decodedText);

        setState(() {
          _textController.text = match != null ? match.group(1).toString() : "NO";
          _status = 'Text loaded successfully';
        });
      } else {
        setState(() {
          _status = 'Error: ${response.statusCode}';
          _textController.text = "";
        });
      }
    } catch (e) {
      if(mounted){
        setState(() {
          _status = 'Error: $e';
          _textController.text = "";
        });
      }
    } finally {
      if(mounted){  
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendText() async {
    final text = _textController.text;

    setState(() {
      _isLoading = true;
      _status = 'Sending text to KOReader...';
    });

    try {
      // First, delete all existing text
      await http.get(
        Uri.parse(
          'http://${widget.ip}:${widget.port}/koreader/UIManager/_window_stack/2/widget/_input_widget/delAll?/',
        ),
      );

      // // Then add the new text
      // final encodedText = Uri.encodeComponent(text);
      // //encodedText.replaceAll(r'"', "%22");
      // final uri = Uri.parse(
      //   'http://${widget.ip}:${widget.port}/koreader/UIManager/_window_stack/2/widget/_input_widget/addChars/ "${encodedText}"',
      // );

      final parts = text.split('/');
      print(parts);
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          await _sendChunk(parts[i]);
        }
        if (i < parts.length - 1) {
          await _sendChunk('/');
        }
      }

      setState(() {
        _status = 'Text sent successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendChunk(String chunk) async {
    if(chunk == "/"){
      chunk = '"$chunk"';
    }
    final encoded = Uri.encodeComponent(chunk);

    final uri = Uri.parse(
      'http://${widget.ip}:${widget.port}'
      '/koreader/UIManager/_window_stack/2/widget/_input_widget/addChars/$encoded',
    );

    await http.get(uri);
  }

  Future<void> _clearText() async {
    setState(() {
      _isLoading = true;
      _status = 'Clearing text on KOReader...';
    });

    try {
      final uri = Uri.parse(
        'http://${widget.ip}:${widget.port}/koreader/UIManager/_window_stack/2/widget/_input_widget/delAll?/',
      );

      await http.get(uri);

      setState(() {
        _textController.clear();
        _status = 'Text cleared';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
            title: Text(
              'Text Input',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
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
                Navigator.pop(context);
              },
            ),
            actions: [
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: 'Enter text to send to KOReader...',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  enabled: !_isLoading,
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _getText,
                    icon: const Icon(Icons.download),
                    label: const Text('GET TEXT'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(15),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _sendText,
                    icon: const Icon(Icons.upload),
                    label: const Text('SEND TEXT'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(15),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Clear Text?'),
                          content:
                              Text('This will clear all text in KOReader.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _clearText();
                              },
                              child: Text('CLEAR'),
                            ),
                          ],
                        ),
                      );
                    },
              icon: const Icon(Icons.delete_outline),
              label: const Text('CLEAR TEXT'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color.fromARGB(255, 108, 108, 108),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Open a text input field in KOReader before using this editor.',
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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
