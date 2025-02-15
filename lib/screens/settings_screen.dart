import 'package:flutter/material.dart';
import '../services/config_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: ConfigService.configNotifier,
        builder: (context, config, child) {
          if (config.isEmpty) {
            return const Center(child: Text('Loading settings...'));
          }

          final filteredConfig = Platform.isAndroid || Platform.isIOS
              ? _filterMobileSettings(config)
              : config;

          return ListView(
            children: filteredConfig.entries.map((entry) {
              final key = entry.key;
              final value = entry.value;

              if (Platform.isAndroid || Platform.isIOS) {
                // Show only relevant settings on mobile
                if (_isMobileRelevantSetting(key)) {
                  return _buildMobileSettingTile(key, value);
                }
                return const SizedBox.shrink();
              }

              return ListTile(
                title: Text(_formatSettingName(key)),
                subtitle: _buildSubtitle(value),
                onTap: () => _editSetting(context, key, value),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _filterMobileSettings(Map<String, dynamic> config) {
    final relevantKeys = [
      'defaultScreenshotDirectory',
      'serverTimeout',
      // Add other mobile-relevant keys
    ];

    return Map.fromEntries(
      config.entries.where((entry) => relevantKeys.contains(entry.key)),
    );
  }

  bool _isMobileRelevantSetting(String key) {
    return [
      'defaultScreenshotDirectory',
      'serverTimeout',
      // Add other mobile-relevant keys
    ].contains(key);
  }

  Widget _buildMobileSettingTile(String key, dynamic value) {
    return ListTile(
      title: Text(_formatSettingName(key)),
      subtitle: _buildMobileSubtitle(value),
      onTap: () => _editMobileSetting(context, key, value),
    );
  }

  String _formatSettingName(String key) {
    return key
        .replaceAll(RegExp(r'([A-Z])'), ' $1')
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildSubtitle(dynamic value) {
    if (value is Map) {
      return Text(value.toString());
    } else if (value is List) {
      return Text(value.join(', '));
    } else {
      return Text(value.toString());
    }
  }

  Future<void> _editSetting(
      BuildContext context, String key, dynamic value) async {
    if (value is bool) {
      _showBoolDialog(context, key, value);
    } else if (value is String) {
      _showStringDialog(context, key, value);
    } else if (value is int) {
      _showIntDialog(context, key, value);
    } else if (value is Map) {
      _showMapDialog(context, key, value);
    }
  }

  Future<void> _showBoolDialog(
      BuildContext context, String key, bool value) async {
    bool? newValue = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $key'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CheckboxListTile(
                title: Text(key),
                value: value,
                onChanged: (bool? newValue) {
                  setState(() {
                    value = newValue ?? false;
                  });
                },
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                ConfigService.updateConfig({key: value});
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showStringDialog(
      BuildContext context, String key, String value) async {
    final TextEditingController controller = TextEditingController(text: value);
    String? newValue = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $key'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new value for $key'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
            ),
          ],
        );
      },
    );

    if (newValue != null) {
      ConfigService.updateConfig({key: newValue});
    }
  }

  Future<void> _showIntDialog(
      BuildContext context, String key, int value) async {
    final TextEditingController controller =
        TextEditingController(text: value.toString());
    int? newValue = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $key'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Enter new value for $key'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                Navigator.of(context).pop(int.tryParse(controller.text));
              },
            ),
          ],
        );
      },
    );

    if (newValue != null) {
      ConfigService.updateConfig({key: newValue});
    }
  }

  Future<void> _showMapDialog(
      BuildContext context, String key, Map value) async {
    // For simplicity, just show the map as text for now
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $key'),
          content: Text(value.toString()),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileSubtitle(dynamic value) {
    if (value is Map) {
      if (value.containsKey(Platform.operatingSystem)) {
        // Show only the relevant path for the current platform
        return Text(value[Platform.operatingSystem].toString());
      }
      return Text(value.toString());
    } else if (value is List) {
      return Text(value.join(', '));
    } else {
      return Text(value.toString());
    }
  }

  Future<void> _editMobileSetting(
      BuildContext context, String key, dynamic value) async {
    if (key == 'defaultScreenshotDirectory') {
      await _editMobileScreenshotDirectory(context, value);
    } else if (value is int) {
      await _showIntDialog(context, key, value);
    } else if (value is String) {
      await _showStringDialog(context, key, value);
    }
  }

  Future<void> _editMobileScreenshotDirectory(
      BuildContext context, Map<String, dynamic> paths) async {
    final currentPath = paths[Platform.operatingSystem];
    final TextEditingController controller =
        TextEditingController(text: currentPath);

    String? newPath = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Screenshot Directory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                    labelText: 'Enter screenshot directory path'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newPath != null && newPath != currentPath) {
      final updatedPaths = Map<String, dynamic>.from(paths);
      updatedPaths[Platform.operatingSystem] = newPath;
      ConfigService.updateConfig({
        'defaultScreenshotDirectory': updatedPaths,
      });
    }
  }
}
