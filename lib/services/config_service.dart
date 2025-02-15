import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for ValueNotifier
import 'package:flutter/material.dart'; // for debugPrint
import 'package:notpixelshot/services/network_service.dart';
import 'package:notpixelshot/widgets/permission_dialog.dart';
import 'package:permission_handler/permission_handler.dart'; // for requesting file permissions on mobile
import 'package:http/http.dart' as http;

class ConfigService {
  static late Map<String, dynamic> configData;
  static final ValueNotifier<Map<String, dynamic>> configNotifier =
      ValueNotifier({}); // live sync notifier

  static Future<void> initialize() async {
    // Initialize config data
    configData = _getDefaultConfig();

    // Request storage permission only on Android
    if (Platform.isAndroid) {
      try {
        final status = await Permission.storage.status;
        if (status.isDenied) {
          // Show permission dialog
          final result = await showPermissionDialog();
          if (result == true) {
            final newStatus = await Permission.storage.request();
            if (newStatus.isGranted) {
              print('Storage permission granted on mobile.');
            } else {
              print('Storage permission denied on mobile.');
            }
          }
        }
      } catch (e) {
        debugPrint('Error requesting storage permission: $e');
      }
    }

    // Only try to sync config from server on mobile
    if (Platform.isAndroid || Platform.isIOS) {
      await _syncConfigFromServer();
    }

    configNotifier.value = configData;
  }

  static Future<void> _syncConfigFromServer() async {
    try {
      // Try to discover server on network
      final serverAddress = await NetworkService.findServer();
      if (serverAddress == null) {
        print('No server found on network');
        return;
      }

      final response = await http
          .get(Uri.parse('http://$serverAddress/api/config'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final syncedConfig = jsonDecode(response.body);
        configData = syncedConfig;
        configNotifier.value = configData;
        print('Config synced from server: $configData');
      } else {
        print('Failed to sync config: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing config: $e');
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
      'configFilePath': '$home/.notpixelshot.json',
      'serverTimeout': 5000,
    };
  }
}
