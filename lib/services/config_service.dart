import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for ValueNotifier
import 'package:flutter/material.dart'; // for debugPrint
import 'package:permission_handler/permission_handler.dart'; // for requesting file permissions on mobile
import 'package:http/http.dart' as http;

class ConfigService {
  static late Map<String, dynamic> configData;
  static final ValueNotifier<Map<String, dynamic>> configNotifier =
      ValueNotifier({}); // live sync notifier

  static Future<void> initialize() async {
    // Request storage permission only on Android and iOS
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          print('Storage permission not granted on mobile.');
          // Optionally show a dialog to the user explaining why the permission is needed
        }
      } catch (e) {
        // Handle the exception, e.g., log it or show an error message
        debugPrint('Error requesting storage permission: $e');
      }

      // Sync config from server
      await _syncConfigFromServer();
    } else {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      final filePath = '$home/.notpixelshot.json';
      final file = File(filePath);

      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          configData = jsonDecode(content);
          print('Config loaded from $filePath');
        } catch (e) {
          print('Failed to load config: $e');
          configData = _getDefaultConfig();
          await _saveConfig(file, configData);
        }
      } else {
        configData = _getDefaultConfig();
        await _saveConfig(file, configData);
        print('Default config created at $filePath');
      }
    }
    configNotifier.value = configData; // update live notifier
  }

  static Future<void> _syncConfigFromServer() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:9876/config'));
      if (response.statusCode == 200) {
        configData = jsonDecode(response.body);
        print('Config synced from server: $configData');
      } else {
        print('Failed to sync config from server. Status code: ${response.statusCode}');
        configData = _getDefaultConfig(); // Use default config if sync fails
      }
    } catch (e) {
      print('Error syncing config from server: $e');
      configData = _getDefaultConfig(); // Use default config if sync fails
    }
  }

  static void updateConfig(Map<String, dynamic> newConfig) {
    configData.addAll(newConfig);
    configNotifier.value = configData; // live update notifier on change
    if (!Platform.isAndroid && !Platform.isIOS) {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      final filePath = '$home/.notpixelshot.json';
      _saveConfig(File(filePath), configData);
    }
  }

  static Future<void> _saveConfig(
      File file, Map<String, dynamic> config) async {
    try {
      await file.writeAsString(jsonEncode(config));
      print('Config saved to ${file.path}');
    } catch (e) {
      print('Failed to save config: $e');
    }
  }

  static Map<String, dynamic> _getDefaultConfig() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return {
      'defaultScreenshotDirectory': {
        'windows': '%USERPROFILE%\\Pictures\\Screenshots',
        'linux': '$home/Pictures/Screenshots',
        'macos': '$home/Pictures/Screenshots',
        'android': '/storage/emulated/0/Pictures/Screenshots',
        'ios': 'Not supported yet'
      },
      'ollamaModelName': 'tinyllama',
      'ollamaPrompt': 'Explain this image in detail.',
      'serverPort': 9876,
      'configFilePath': '$home/.notpixelshot.json'
    };
  }
}
