import 'package:flutter/material.dart';
import '../services/config_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

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
          return ListView(
            children: config.entries.map((entry) {
              final key = entry.key;
              final value = entry.value;

              return ListTile(
                title: Text(key),
                subtitle: _buildSubtitle(value),
                onTap: () => _editSetting(context, key, value),
              );
            }).toList(),
          );
        },
      ),
    );
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
}
