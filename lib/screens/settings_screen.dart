import 'package:flutter/material.dart';
import '../services/config_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Screenshot Directories'),
            subtitle: Text(ConfigService
                .configData['defaultScreenshotDirectory']
                .toString()),
            onTap: () {
              // Open directory selection dialog
            },
          ),
          ListTile(
            title: const Text('Ollama Model'),
            subtitle: Text(ConfigService.configData['ollamaModelName']),
            onTap: () {
              // Open model selection dialog
            },
          ),
          ListTile(
            title: const Text('Server Port'),
            subtitle: Text(ConfigService.configData['serverPort'].toString()),
            onTap: () {
              // Open port configuration dialog
            },
          ),
        ],
      ),
    );
  }
}
