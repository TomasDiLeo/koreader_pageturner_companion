import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;

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