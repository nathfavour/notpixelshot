import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import '../services/config_service.dart';

class IndexService {
  static late Database database;
  static final ValueNotifier<IndexProgress> progressNotifier = ValueNotifier(
    IndexProgress(total: 0, processed: 0, current: ''),
  );

  static final ValueNotifier<int> totalScreenshotsNotifier = ValueNotifier(0);

  static String get screenshotDirectoryWindows =>
      ConfigService.configData['defaultScreenshotDirectory']['windows'];

  static String get screenshotDirectoryMacOS =>
      ConfigService.configData['defaultScreenshotDirectory']['macos'];

  static String get screenshotDirectoryLinux =>
      ConfigService.configData['defaultScreenshotDirectory']['linux'];

  static String get screenshotDirectory =>
      ConfigService.configData['defaultScreenshotDirectory']
          [Platform.operatingSystem];

  static String get _databasePath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final dbDir = path.join(home, '.notpixelshot');
    return path.join(dbDir, 'screenshots.db');
  }

  static Future<void> initialize() async {
    // Ensure database directory exists
    final dbFile = File(_databasePath);
    if (!await dbFile.parent.exists()) {
      await dbFile.parent.create(recursive: true);
    }

    // Initialize SQLite database
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    database = await databaseFactoryFfi.openDatabase(
      _databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE screenshots(
              id TEXT PRIMARY KEY,
              path TEXT,
              extracted_text TEXT,
              ollama_description TEXT,
              platform TEXT,
              created_at INTEGER
            )
          ''');
        },
      ),
    );

    // Initialize total screenshots count
    await _updateTotalScreenshotsCount();

    // Start processing screenshots immediately
    await _startProcessing();
  }

  static Future<void> _updateTotalScreenshotsCount() async {
    final directory = Directory(screenshotDirectory);
    if (!await directory.exists()) return;

    final files = await directory
        .list()
        .where((f) =>
            f.path.toLowerCase().endsWith('.png') ||
            f.path.toLowerCase().endsWith('.jpg'))
        .toList();

    totalScreenshotsNotifier.value = files.length;
  }

  static Future<void> _startProcessing() async {
    final directory = Directory(screenshotDirectory);

    if (!await directory.exists()) return;

    final files = await directory
        .list()
        .where((f) =>
            f.path.toLowerCase().endsWith('.png') ||
            f.path.toLowerCase().endsWith('.jpg'))
        .toList();

    progressNotifier.value = IndexProgress(
      total: files.length,
      processed: 0,
      current: '',
    );

    for (var file in files) {
      if (await _isAlreadyIndexed(file.path)) {
        progressNotifier.value = progressNotifier.value.copyWith(
          processed: progressNotifier.value.processed + 1,
          current: file.path,
        );
        continue;
      }

      progressNotifier.value = progressNotifier.value.copyWith(
        current: file.path,
      );

      // Run tesseract
      final result = await Process.run('tesseract', [file.path, 'stdout']);
      final extractedText = result.stdout.toString();

      // Call Ollama
      final ollamaPrompt = ConfigService.configData['ollamaPrompt'];
      final ollamaModel = ConfigService.configData['ollamaModelName'];
      final ollamaResult = await Process.run('ollama', [
        'run',
        ollamaModel,
        '$ollamaPrompt\nExtracted text: $extractedText'
      ]);

      // Store in database
      await database.insert('screenshots', {
        'id': file.path,
        'path': file.path,
        'extracted_text': extractedText,
        'ollama_description': ollamaResult.stdout.toString(),
        'platform': Platform.operatingSystem,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      progressNotifier.value = progressNotifier.value.copyWith(
        processed: progressNotifier.value.processed + 1,
      );
    }
  }

  static Future<bool> _isAlreadyIndexed(String filePath) async {
    final result = await database.query(
      'screenshots',
      where: 'path = ?',
      whereArgs: [filePath],
    );
    return result.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getIndexedFiles() async {
    return await database.query('screenshots');
  }

  static void monitorDirectory(
      Directory directory, void Function(FileSystemEvent) onEvent) {
    directory.watch().listen((event) async {
      onEvent(event);
      await _updateTotalScreenshotsCount(); // Update total count on file changes
    });
  }

  static Future<void> scanAndIndexScreenshots() async {
    // Use Tesseract CLI to extract text from each screenshot
    // Call Ollama for explanations
    // Update local index (e.g., SQLite)
  }
}

class IndexProgress {
  final int total;
  final int processed;
  final String current;

  IndexProgress({
    required this.total,
    required this.processed,
    required this.current,
  });

  IndexProgress copyWith({
    int? total,
    int? processed,
    String? current,
  }) {
    return IndexProgress(
      total: total ?? this.total,
      processed: processed ?? this.processed,
      current: current ?? this.current,
    );
  }
}
