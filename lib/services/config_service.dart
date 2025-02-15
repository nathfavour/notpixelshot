import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for ValueNotifier
import 'package:flutter/material.dart'; // for debugPrint
import '../main.dart'; // Import for navigatorKey
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

    if (Platform.isAndroid || Platform.isIOS) {
      // Wait for app to be ready before requesting permissions
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _requestPermissions();
        await _syncConfigFromServer();
      });
    }

    configNotifier.value = configData;
  }

  static Future<void> _requestPermissions() async {
    try {
      if (navigatorKey.currentContext == null) {
        print('No context available for permission dialog');
        return;
      }

      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await showPermissionDialog(navigatorKey.currentContext!);
        if (result == true) {
          await Permission.manageExternalStorage.request();
          await Permission.storage.request();
          print('Storage permissions requested successfully');
        }
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  static Future<void> _syncConfigFromServer() async {
    try {
      // First try localhost for emulator
      String host = '10.0.2.2';

      // If that fails, try local network
      var response = await http
          .get(Uri.parse('http://$host:9876/api/config'))
          .timeout(const Duration(seconds: 2))
          .catchError((_) async {
        host = await NetworkService.findServer() ?? '0.0.0.0';
        return await http.get(Uri.parse('http://$host:9876/api/config'));
      });

      if (response.statusCode == 200) {
        final syncedConfig = jsonDecode(response.body);
        configData.addAll(syncedConfig);
        configNotifier.value = configData;
        print('Config synced from server: $configData');
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
