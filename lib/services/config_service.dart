import 'dart:io';
import 'dart:convert';

class ConfigService {
  static late Map<String, dynamic> configData;

  static Future<void> initialize() async {
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

  static void updateConfig(Map<String, dynamic> newConfig) {
    configData.addAll(newConfig);
    _saveConfig(File(configData['configFilePath']), configData);
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
      'ollamaModelName': 'llama2',
      'ollamaPrompt': 'Explain this image in detail.',
      'serverPort': 9876,
      'configFilePath': '$home/.notpixelshot.json'
    };
  }
}
