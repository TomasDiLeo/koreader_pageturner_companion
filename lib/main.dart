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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Page Turner Companion',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black,
          onSecondary: Colors.white,
          error: Colors.red, // keep cancel red
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
      home: const ConnectionPage(),
    );
  }
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

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
                    builder: (context) => ControlPage(ip: ip, port: port),
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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Image(
                  image: AssetImage('assets/icons/koreader.png'),
                  height: 80,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 16),
                Text(
                  'Page Turner App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 1.2,
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
            const Text(
              'Default port is 8134 unless changed in Page Turner plugin code.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: _isConnecting ? null : _connect,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3), // <-- square
                ),
                disabledBackgroundColor: Colors.white,
              ),
              child: _isConnecting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        backgroundColor: Colors.white,
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
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Color.fromARGB(255, 108, 108, 108)),
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

class ControlPage extends StatefulWidget {
  final String ip;
  final int port;

  const ControlPage({super.key, required this.ip, required this.port});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  String _status = 'Connected';

  static const MethodChannel _channel =
      MethodChannel('volume_buttons');

  @override
  void initState() {
    super.initState();

    _channel.setMethodCallHandler((call) async {
      setState(() {
        if (call.method == 'volumeUp') {
          _sendCommand("NEXT");
        } else if (call.method == 'volumeDown') {
          _sendCommand("PREV");
        }
      });
    });
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
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.black, width: 1),
            ),
          ),
          child: AppBar(
            title: const Text(
              'Back to Connection',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/chevron.left.svg',
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ConnectionPage()),
                );
              },
            ),
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
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/chevron.left.svg',
                        ),
                        SizedBox(height: 10),
                        Text(
                          'PREVIOUS',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/chevron.right.svg',
                        ),
                        SizedBox(height: 10),
                        Text(
                          'NEXT',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Color.fromARGB(255, 108, 108, 108)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
