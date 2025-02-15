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

  static String get _notpixelshotDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return path.join(home, '.notpixelshot');
  }

  static String get _databasePath {
    return path.join(_notpixelshotDir, 'db', 'screenshots.db');
  }

  static String get _indexPath {
    return path.join(_notpixelshotDir, 'index');
  }

  static Future<void> initialize() async {
    try {
      print('IndexService: Initializing...');

      // Create required directories
      for (var dir in [
        _notpixelshotDir,
        path.dirname(_databasePath),
        _indexPath
      ]) {
        final directory = Directory(dir);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          print('IndexService: Created directory $dir');
        }
      }

      // Initialize SQLite database
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        print('IndexService: sqflite FFI initialized');
      }

      database = await databaseFactoryFfi.openDatabase(
        _databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            print('IndexService: Creating database table...');
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
            print('IndexService: Database table created');
          },
        ),
      );
      print('IndexService: Database opened successfully');

      // Initialize total screenshots count
      await _updateTotalScreenshotsCount();

      print('IndexService: Initialization complete');
    } catch (e, stackTrace) {
      print('IndexService: Error during initialization: $e');
      print('IndexService: Stack trace: $stackTrace');
    }
  }

  static Future<void> _updateTotalScreenshotsCount() async {
    try {
      final directory = Directory(screenshotDirectory);
      if (!await directory.exists()) {
        print('IndexService: Screenshot directory does not exist');
        totalScreenshotsNotifier.value = 0;
        return;
      }

      final files = await directory
          .list()
          .where((f) =>
              f.path.toLowerCase().endsWith('.png') ||
              f.path.toLowerCase().endsWith('.jpg'))
          .toList();

      totalScreenshotsNotifier.value = files.length;
      print('IndexService: Total screenshots count updated: ${files.length}');
    } catch (e, stackTrace) {
      print('IndexService: Error updating total screenshots count: $e');
      print('IndexService: Stack trace: $stackTrace');
    }
  }

  static Future<void> _startProcessing() async {
    try {
      final directoryPath = screenshotDirectory;
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        print(
            'IndexService: Screenshot directory does not exist: $directoryPath');
        progressNotifier.value =
            IndexProgress(total: 0, processed: 0, current: '');
        return;
      }

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
    } catch (e, stackTrace) {
      print('IndexService: Error during screenshot processing: $e');
      print('IndexService: Stack trace: $stackTrace');
    }
  }

  static Future<void> startProcessing() async {
    await _updateTotalScreenshotsCount();
    await _startProcessing();
  }

  static Future<bool> _isAlreadyIndexed(String filePath) async {
    try {
      final result = await database.query(
        'screenshots',
        where: 'path = ?',
        whereArgs: [filePath],
      );
      return result.isNotEmpty;
    } catch (e, stackTrace) {
      print('IndexService: Error checking if file is indexed: $e');
      print('IndexService: Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getIndexedFiles() async {
    try {
      return await database.query('screenshots');
    } catch (e, stackTrace) {
      print('IndexService: Error getting indexed files: $e');
      print('IndexService: Stack trace: $stackTrace');
      return [];
    }
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
