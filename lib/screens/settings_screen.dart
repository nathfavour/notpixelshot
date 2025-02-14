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
      body: ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: ConfigService.configNotifier,
        builder: (context, config, child) {
          return ListView(
            children: [
              ListTile(
                title: const Text('Screenshot Directories'),
                subtitle: Text(config['defaultScreenshotDirectory'].toString()),
                onTap: () {
                  // Open directory selection dialog and then call
                  // ConfigService.updateConfig(newConfig)
                },
              ),
              ListTile(
                title: const Text('Ollama Model'),
                subtitle: Text(config['ollamaModelName']),
                onTap: () {
                  // Open model selection dialog and then call
                  // ConfigService.updateConfig(newConfig)
                },
              ),
              ListTile(
                title: const Text('Server Port'),
                subtitle: Text(config['serverPort'].toString()),
                onTap: () {
                  // Open port configuration dialog and then call
                  // ConfigService.updateConfig(newConfig)
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
