import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:notpixelshot/services/network_service.dart';
import 'package:notpixelshot/widgets/permission_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class ConfigService {
  static late Map<String, dynamic> configData;
  static final ValueNotifier<Map<String, dynamic>> configNotifier =
      ValueNotifier({});
  static StreamSubscription? _configFileWatcher;

  static String get _configFilePath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final configDir = path.join(home, '.notpixelshot');
    return path.join(configDir, 'config.json');
  }

  static Future<void> initialize() async {
    try {
      print('ConfigService: Initializing...');
      configData = _getDefaultConfig();
      print('ConfigService: Default config loaded');

      if (Platform.isAndroid || Platform.isIOS) {
        print('ConfigService: Running on mobile, syncing from server...');
        await _syncConfigFromServer();
      } else {
        print('ConfigService: Running on desktop, loading from file...');
        await _loadConfigFromFile();
        _watchConfigFile();
      }

      configNotifier.value = configData;
      print('ConfigService: Initialization complete');
    } catch (e, stackTrace) {
      print('ConfigService: Error during initialization: $e');
      print('ConfigService: Stack trace: $stackTrace');
      configNotifier.value =
          configData; // Ensure notifier is updated even on error
    }
  }

  static Future<void> _loadConfigFromFile() async {
    try {
      print('ConfigService: Loading config from file...');
      final file = File(_configFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        configData = jsonDecode(content);
        print('ConfigService: Loaded config from file: $configData');
      } else {
        print('ConfigService: Config file not found, creating default...');
        configData = _getDefaultConfig();
        await _saveConfig(file, configData);
        print('ConfigService: Default config created');
      }
    } catch (e, stackTrace) {
      print('ConfigService: Error loading config file: $e');
      print('ConfigService: Stack trace: $stackTrace');
    }
  }

  static Future<void> reloadConfigFromFile() async {
    try {
      print('ConfigService: Reloading config from file...');
      final file = File(_configFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        configData = jsonDecode(content);
        configNotifier.value = configData;
        print('ConfigService: Reloaded config from file: $configData');
      }
    } catch (e, stackTrace) {
      print('ConfigService: Error reloading config file: $e');
      print('ConfigService: Stack trace: $stackTrace');
    }
  }

  static void _watchConfigFile() {
    _configFileWatcher?.cancel();
    final file = File(_configFilePath);
    _configFileWatcher = file.watch().listen((event) async {
      print('ConfigService: Config file changed, reloading...');
      await _loadConfigFromFile();
      configNotifier.value = configData;
    });
  }

  static Future<void> _requestPermissions() async {
    try {
      if (navigatorKey.currentContext == null) {
        print('ConfigService: No context available for permission dialog');
        return;
      }

      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await showPermissionDialog(navigatorKey.currentContext!);
        if (result == true) {
          await Permission.manageExternalStorage.request();
          await Permission.storage.request();
          print('ConfigService: Storage permissions requested successfully');
        }
      }
    } catch (e, stackTrace) {
      print('ConfigService: Error requesting permissions: $e');
      print('ConfigService: Stack trace: $stackTrace');
    }
  }

  static Future<void> _syncConfigFromServer() async {
    try {
      print('ConfigService: Syncing config from server...');
      final serverHost = await NetworkService.findServer();
      if (serverHost == null) {
        print('ConfigService: No server found on network');
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
        print('ConfigService: Config synced from server at $serverHost');
      } else {
        print('ConfigService: Failed to sync config: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('ConfigService: Error syncing config: $e');
      print('ConfigService: Stack trace: $stackTrace');
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
      // Ensure config directory exists
      final configDir = file.parent;
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      await file.writeAsString(jsonEncode(config), flush: true);
      print('Config saved to ${file.path}');
    } catch (e, stackTrace) {
      print('ConfigService: Failed to save config: $e');
      print('ConfigService: Stack trace: $stackTrace');
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
