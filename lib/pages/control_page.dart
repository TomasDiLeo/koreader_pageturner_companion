import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pageturner_app/pages/reading_mode_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/volume_button_action.dart';
import '../services/koreader_service.dart';
import '../services/volume_button_service.dart';
import 'connection_page.dart';
import 'text_editor_page.dart';

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
  late final KOReaderService _koreaderService;
  late final VolumeButtonService _volumeButtonService;

  VolumeButtonAction _volumeUpAction = VolumeButtonAction.next;
  VolumeButtonAction _volumeDownAction = VolumeButtonAction.prev;

  String _status = "Connected";

  int _frontLight = 0;
  int _auxFrontLight = 0;
  bool isFrontLightDisabled = false;
  int _warmLight = 0;
  int _auxWarmLight = 0;
  bool isWarmLightDisabled = false;

  // Profile names - support up to 5 profiles
  final List<String> _profileNames = List.filled(5, '', growable: false);

  @override
  void initState() {
    super.initState();
    _koreaderService = KOReaderService(
      ip: widget.ip,
      port: widget.port,
      onStatusUpdate: (status) {
        if (mounted) {
          setState(() {
            _status = status;
          });
        }
      },
    );

    _volumeButtonService = VolumeButtonService(
      onVolumeUp: () => _turnPage(_volumeUpAction.command),
      onVolumeDown: () => _turnPage(_volumeDownAction.command),
    );

    _loadVolumeButtonSettings();
    _loadProfileNames();

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted) {
        _loadDisplayLights();
      }

      if (await _koreaderService.isConnected()) {
        setState(() {
          _status = "Device Connected";
        });
      } else {
        setState(() {
          _status = "No device found";
        });
      }
    });
  }

  @override
  void dispose() {
    _volumeButtonService.dispose();
    super.dispose();
  }

  Future<void> _loadProfileNames() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultNames = ['1', '2', '3', '4', '5'];

    setState(() {
      for (int i = 0; i < 5; i++) {
        _profileNames[i] =
            prefs.getString('profile_${i}_name') ?? defaultNames[i];
      }
    });
  }

  Future<void> _saveProfileName(int index, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_${index}_name', name);
  }

  void _showEditProfileDialog(int profileIndex) {
    final currentName = _profileNames[profileIndex];
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Edit Profile ${profileIndex + 1}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Profile Name',
              hintText: 'Enter profile name',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _updateProfileName(profileIndex, value.trim());
                Navigator.of(context).pop();
              }
            },
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
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  _updateProfileName(profileIndex, newName);
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Profile renamed to "$newName"'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(
                'SAVE',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateProfileName(int index, String name) {
    setState(() {
      _profileNames[index] = name;
    });
    _saveProfileName(index, name);
  }

  void _executeProfile(int index) {
    _koreaderService.executeProfile(_profileNames[index]);
  }

  Future<void> _loadDisplayLights() async {
    final frontLight = await _koreaderService.getFlIntensity();
    final warmLight = await _koreaderService.getFlWarmth();

    if (mounted) {
      setState(() {
        _frontLight = frontLight;
        _warmLight = warmLight;
      });
    }
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

  Future<void> _turnPage(int direction) async {
    await _koreaderService.turnPage(direction);
  }

  Future<void> _toggleFrontLight() async {
    if (!isFrontLightDisabled) {
      setState(() {
        _auxFrontLight = _frontLight;
        _frontLight = 0;
      });
      await _koreaderService.toggleFrontlight();
      isFrontLightDisabled = true;
    } else {
      setState(() {
        _frontLight = _auxFrontLight;
      });
      await _koreaderService.setFrontLightIntensity(_frontLight);
      isFrontLightDisabled = false;
    }
  }

  Future<void> _toggleWarmth() async {
    if (!isWarmLightDisabled) {
      setState(() {
        _auxWarmLight = _warmLight;
        _warmLight = 0;
      });
      await _koreaderService.setWarmth(0);
      isWarmLightDisabled = true;
    } else {
      setState(() {
        _warmLight = _auxWarmLight;
      });
      await _koreaderService.setWarmth(_warmLight);
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
                icon: const Icon(Icons.auto_stories),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => ReadingModePage(
                        ip: widget.ip,
                        port: widget.port,
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                      reverseTransitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
                tooltip: 'Reading Mode',
              ),
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
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: () async {
                      await _toggleFrontLight();
                    },
                    tooltip: "Toggle Front",
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
                      await _koreaderService
                          .setFrontLightIntensity(newValue.toInt());
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
                    tooltip: "Toggle Warmth",
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
                      await _koreaderService.setWarmth(newValue.toInt());
                      setState(() {
                        _warmLight = newValue.toInt();
                      });
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 10, thickness: .2, indent: 50, endIndent: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                    icon: const Icon(
                      Icons.settings_brightness,
                    ),
                    onPressed: () async {
                      await _koreaderService.toggleNightMode();
                    },
                    tooltip: 'Toggle Night Mode in KoReader'),
                IconButton(
                    icon: const Icon(
                      Icons.refresh,
                    ),
                    onPressed: () async {
                      await _koreaderService.refreshScreen();
                    },
                    tooltip: 'Refresh Screen in KoReader'),
              ],
            ),
            const Divider(height: 10, thickness: .5, indent: 0, endIndent: 0),
            // Additional profiles row
            Text(
              'Custom Profiles (Long press to edit)',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const Divider(height: 10, thickness: .2, indent: 0, endIndent: 0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < 5; i++)
                  GestureDetector(
                    onLongPress: () => _showEditProfileDialog(i),
                    child: OutlinedButton(
                      onPressed: () => _executeProfile(i),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        _profileNames[i],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 10, thickness: .5, indent: 0, endIndent: 0),
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
            const SizedBox(height: 2),
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
                        _koreaderService.goBackLink();
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Icon(Icons.link),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    _koreaderService.back();
                  },
                  icon: const Icon(Icons.restart_alt),
                ),
                Row(
                  children: [
                    const Icon(Icons.link),
                    IconButton(
                      onPressed: () {
                        _koreaderService.goForwardLink();
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
                    _status,
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
