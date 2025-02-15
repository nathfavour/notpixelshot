import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for ValueNotifier
import 'package:flutter/material.dart'; // for debugPrint
import '../main.dart'; // Import for navigatorKey
import 'package:notpixelshot/services/network_service.dart';
import 'package:notpixelshot/widgets/permission_dialog.dart';
import 'package:permission_handler/permission_handler.dart'; // for requesting file permissions on mobile
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class ConfigService {
  static late Map<String, dynamic> configData;
  static final ValueNotifier<Map<String, dynamic>> configNotifier =
      ValueNotifier({}); // live sync notifier
  static StreamSubscription? _configFileWatcher;
  static String get _configFilePath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return path.join(home, '.notpixelshot.json');
  }

  static Future<void> initialize() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile platforms sync from server
      await _syncConfigFromServer();
    } else {
      // Desktop platforms read from file and watch for changes
      await _loadConfigFromFile();
      _watchConfigFile();
    }
    configNotifier.value = configData;
  }

  static Future<void> _loadConfigFromFile() async {
    try {
      final file = File(_configFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        configData = jsonDecode(content);
        print('Loaded config from file: $configData');
      } else {
        configData = _getDefaultConfig();
        await _saveConfig(file, configData);
      }
    } catch (e) {
      print('Error loading config file: $e');
      configData = _getDefaultConfig();
    }
  }

  // Add public method to reload config
  static Future<void> reloadConfigFromFile() async {
    try {
      final file = File(_configFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        configData = jsonDecode(content);
        configNotifier.value = configData;
        print('Reloaded config from file: $configData');
      }
    } catch (e) {
      print('Error reloading config file: $e');
    }
  }

  static void _watchConfigFile() {
    _configFileWatcher?.cancel();
    final file = File(_configFilePath);
    _configFileWatcher = file.watch().listen((event) async {
      print('Config file changed, reloading...');
      await _loadConfigFromFile();
      configNotifier.value = configData;
    });
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
      final serverHost = await NetworkService.findServer();
      if (serverHost == null) {
        print('No server found on network');
        return;
      }

      final response = await http
          .get(Uri.parse(
              'http://$serverHost:${NetworkService.defaultPort}/api/config'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final syncedConfig = jsonDecode(response.body);
        configData.addAll(syncedConfig);
        configNotifier.value = configData;
        print('Config synced from server at $serverHost');
      }
    } catch (e) {
      print('Error syncing config: $e');
    }
  }

  static void updateConfig(Map<String, dynamic> newConfig) {
    configData.addAll(newConfig);
    configNotifier.value = configData; // live update notifier on change
    if (!Platform.isAndroid && !Platform.isIOS) {
      final configFile = File(_configFilePath);
      _saveConfig(configFile, configData);
    }
  }

  static Future<void> _saveConfig(
      File file, Map<String, dynamic> config) async {
    try {
      // Ensure parent directory exists
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      await file.writeAsString(jsonEncode(config), flush: true);
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
