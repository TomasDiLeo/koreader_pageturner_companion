import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'control_page.dart';

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