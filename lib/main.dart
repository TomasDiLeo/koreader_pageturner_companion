import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool('is_dark_mode', newMode == ThemeMode.dark);
    setState(() {
      _themeMode = newMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Page Turner Companion',
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
  bool _isConnecting = false;
  RawDatagramSocket? _currentSocket;
  Timer? _currentTimeout;

  @override
  void initState() {
    super.initState();
    _portController.text = '8134';
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

  Future<void> _connect() async {
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

    setState(() {
      _isConnecting = true;
      _status =
          'Searching for device... (Make sure you pressed "Start Service" in KOReader)';
    });

    try {
      _currentSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final data = 'REQUEST'.codeUnits;
      _currentSocket!.send(data, InternetAddress(ip), port);

      bool receivedResponse = false;

      _currentTimeout = Timer(const Duration(seconds: 10), () {
        if (!receivedResponse) {
          _currentSocket?.close();
          _currentTimeout?.cancel();
          if (mounted) {
            setState(() {
              _status = 'Connection timeout - no response from KOReader device';
              _isConnecting = false;
            });
          }
        }
      });

      _currentSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final packet = _currentSocket!.receive();
          if (packet != null) {
            final response = String.fromCharCodes(packet.data).trim();

            if (!receivedResponse &&
                response != 'ACCEPTED' &&
                response != 'DENIED') {
              receivedResponse = true;
              if (mounted) {
                setState(() {
                  _status =
                      'Device found! Awaiting user confirmation on device...';
                });
              }
              return;
            }

            receivedResponse = true;
            _currentTimeout?.cancel();
            _currentSocket?.close();

            if (response == 'ACCEPTED') {
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
            } else if (response == 'DENIED') {
              if (mounted) {
                setState(() {
                  _status = 'Connection denied by user';
                  _isConnecting = false;
                });
              }
            } else if (response == 'REQUESTING') {
              if (mounted) {
                setState(() {
                  _status =
                      'Device found! Awaiting user confirmation on device...';
                });
              }
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          _isConnecting = false;
        });
      }
    }
  }

  void _cancelConnection() {
    _currentTimeout?.cancel();
    _currentSocket?.close();
    setState(() {
      _isConnecting = false;
      _status = 'Connection cancelled';
    });
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
                        //color: isDark ? Colors.white : null,
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
                    enabled: !_isConnecting,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                      hintText: '8134',
                      prefixIcon: Icon(Icons.settings_ethernet),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isConnecting,
                  ),
                  Text(
                    'Default port is 8134 unless changed in Page Turner plugin code.',
                    style: TextStyle(
                      fontSize: 12, 
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 40),
                  OutlinedButton(
                    onPressed: _isConnecting ? null : _connect,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      disabledBackgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                    child: _isConnecting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              color: Colors.grey,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'CONNECT',
                            style:
                                TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                  ),
                  if (_isConnecting) ...[
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: _cancelConnection,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(15),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
                        color: isDark ? Colors.grey[400] : const Color.fromARGB(255, 108, 108, 108),
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
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentTimeout?.cancel();
    _currentSocket?.close();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }
}

enum VolumeButtonAction {
  next,
  prev,
  // Future options can be added here:
  // bookmark,
  // menu,
  // custom,
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

  String get command {
    switch (this) {
      case VolumeButtonAction.next:
        return 'NEXT';
      case VolumeButtonAction.prev:
        return 'PREV';
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

  static const MethodChannel _channel = MethodChannel('volume_buttons');

  @override
  void initState() {
    super.initState();
    _loadVolumeButtonSettings();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUp') {
        _sendCommand(_volumeUpAction.command);
      } else if (call.method == 'volumeDown') {
        _sendCommand(_volumeDownAction.command);
      }
    });
  }

  Future<void> _loadVolumeButtonSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final upIndex = prefs.getInt('volume_up_action') ?? VolumeButtonAction.next.index;
    final downIndex = prefs.getInt('volume_down_action') ?? VolumeButtonAction.prev.index;
    
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
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[700],
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    'SAVE',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendCommand(String command) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final data = command.codeUnits;
      socket.send(data, InternetAddress(widget.ip), widget.port);

      setState(() {
        _status = 'Sent: $command';
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final packet = socket.receive();
          if (packet != null) {
            final response = String.fromCharCodes(packet.data);
            setState(() {
              _status = response;
            });
          }
        }
      });

      Future.delayed(const Duration(seconds: 1), () {
        socket.close();
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
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
              'Back to Connection',
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
                icon: const Icon(Icons.settings),
                onPressed: _showSettingsDialog,
                tooltip: 'Volume Button Settings',
              ),
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: widget.onToggleTheme,
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Use the volume buttons to turn pages!',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Vol Up: ${_volumeUpAction.displayName} | Vol Down: ${_volumeDownAction.displayName}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Connected to: ${widget.ip}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _sendCommand('PREV'),
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
                    onPressed: () => _sendCommand('NEXT'),
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
            const SizedBox(height: 60),
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
                  color: isDark ? Colors.grey[400] : const Color.fromARGB(255, 108, 108, 108),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}