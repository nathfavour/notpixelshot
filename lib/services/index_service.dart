import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../services/config_service.dart';

class IndexService {
  static late Database database;
  static final ValueNotifier<IndexProgress> progressNotifier = ValueNotifier(
    IndexProgress(total: 0, processed: 0, current: ''),
  );

  static Future<void> initialize() async {
    // Initialize SQLite database
    database = await openDatabase(
      join(await getDatabasesPath(), 'notpixelshot.db'),
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
      version: 1,
    );

    // Start processing screenshots immediately
    _startProcessing();
  }

  static Future<void> _startProcessing() async {
    final directory = Directory(ConfigService
        .configData['defaultScreenshotDirectory'][Platform.operatingSystem]);

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
