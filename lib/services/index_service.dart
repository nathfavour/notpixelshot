import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:fuzzy/fuzzy.dart';
import '../services/config_service.dart';

class IndexService {
  static late Database database;
  static final ValueNotifier<IndexProgress> progressNotifier = ValueNotifier(
    IndexProgress(total: 0, processed: 0, current: ''),
  );

  static final ValueNotifier<int> totalScreenshotsNotifier = ValueNotifier(0);

  static String get screenshotDirectory => ConfigService.getScreenshotPath();
  static String get _databasePath => ConfigService.getDatabasePath();

  static Future<void> initialize() async {
    try {
      print('IndexService: Initializing...');

      // Create required directories from config
      final paths = [
        path.dirname(ConfigService.getDatabasePath()),
        ConfigService.getIndexPath(),
      ];

      for (var dir in paths) {
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

      // Initialize total screenshots count and progress
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

      // Get the count of indexed files
      final List<Map<String, dynamic>> result =
          await database.rawQuery('SELECT COUNT(*) as count FROM screenshots');
      final indexedCount = result.first['count'] as int? ?? 0;

      totalScreenshotsNotifier.value = files.length;
      progressNotifier.value = progressNotifier.value.copyWith(
        total: files.length,
        processed: indexedCount,
      );

      print(
          'IndexService: Total screenshots: ${files.length}, Indexed: $indexedCount');
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

      int processedCount = 0;
      for (var file in files) {
        if (await _isAlreadyIndexed(file.path)) {
          print('IndexService: Already indexed: ${file.path}');
          processedCount++;
          progressNotifier.value = progressNotifier.value.copyWith(
            processed: processedCount,
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

        // Call Ollama with proper config path and null safety
        final ollamaConfig =
            ConfigService.configData['ollama'] as Map<String, dynamic>? ?? {};
        final ollamaPrompt =
            ollamaConfig['prompt'] as String? ?? 'Describe this screenshot:';
        final ollamaModel = ollamaConfig['model'] as String? ?? 'llama2';

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

        processedCount++;
        progressNotifier.value = progressNotifier.value.copyWith(
          processed: processedCount,
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
      print('IndexService: Getting all indexed files...');
      final List<Map<String, dynamic>> allFiles = [];

      // Get files from directory first
      final directory = Directory(screenshotDirectory);
      if (await directory.exists()) {
        final directoryFiles = await directory
            .list()
            .where((f) =>
                f.path.toLowerCase().endsWith('.png') ||
                f.path.toLowerCase().endsWith('.jpg'))
            .map((f) => {
                  'path': f.path,
                  'platform': Platform.operatingSystem,
                  'created_at': DateTime.now().millisecondsSinceEpoch,
                })
            .toList();

        allFiles.addAll(directoryFiles);
        print(
            'IndexService: Found ${directoryFiles.length} files in directory');
      }

      // Then get any additional indexed files from database
      final List<Map<String, dynamic>> dbFiles =
          await database.query('screenshots');
      print('IndexService: Found ${dbFiles.length} files in database');

      // Add database files that aren't already in the list
      for (var dbFile in dbFiles) {
        if (!allFiles.any((f) => f['path'] == dbFile['path'])) {
          allFiles.add(dbFile);
        }
      }

      print('IndexService: Returning ${allFiles.length} total files');
      totalScreenshotsNotifier.value = allFiles.length;
      return allFiles;
    } catch (e, stackTrace) {
      print('IndexService: Error getting indexed files: $e');
      print('IndexService: Stack trace: $stackTrace');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchScreenshots(
      String query) async {
    try {
      print('IndexService: Searching screenshots for query: "$query"');

      if (query.trim().isEmpty) {
        print('IndexService: Empty query, returning all files');
        return await getIndexedFiles();
      }

      final List<Map<String, dynamic>> allScreenshots =
          await database.query('screenshots');
      print(
          'IndexService: Found ${allScreenshots.length} total screenshots to search through');

      if (allScreenshots.isEmpty) {
        print('IndexService: No screenshots in database, returning all files');
        return await getIndexedFiles();
      }

      final List<Map<String, dynamic>> results = [];

      for (var screenshot in allScreenshots) {
        final extractedText = screenshot['extracted_text'] as String? ?? '';
        final ollamaDescription =
            screenshot['ollama_description'] as String? ?? '';
        final path = screenshot['path'] as String;
        final fileName = path.split(Platform.pathSeparator).last.toLowerCase();
        final searchTerm = query.toLowerCase();

        bool matches = false;
        double score = 0.0;

        // Check for matches in extracted text
        if (extractedText.toLowerCase().contains(searchTerm)) {
          matches = true;
          score += 3.0;
        }

        // Check for matches in Ollama description
        if (ollamaDescription.toLowerCase().contains(searchTerm)) {
          matches = true;
          score += 2.0;
        }

        // Check filename
        if (fileName.contains(searchTerm)) {
          matches = true;
          score += 1.0;
        }

        if (matches) {
          results.add({
            ...screenshot,
            'search_score': score,
          });
        }
      }

      print('IndexService: Found ${results.length} matching screenshots');

      // Sort by score
      results.sort((a, b) =>
          (b['search_score'] as double).compareTo(a['search_score'] as double));

      // Remove search score before returning
      final finalResults = results.map((r) {
        final map = Map<String, dynamic>.from(r);
        map.remove('search_score');
        return map;
      }).toList();

      print('IndexService: Returning ${finalResults.length} sorted results');
      return finalResults;
    } catch (e, stackTrace) {
      print('IndexService: Error during search: $e');
      print('IndexService: Stack trace: $stackTrace');
      return [];
    }
  }

  static void monitorDirectory(
      Directory directory, void Function(FileSystemEvent) onEvent) {
    directory.watch().listen((event) async {
      if (event.type == FileSystemEvent.create &&
          (event.path.toLowerCase().endsWith('.png') ||
              event.path.toLowerCase().endsWith('.jpg'))) {
        // Process new file immediately when detected
        await _processNewScreenshot(event.path);
      }
      onEvent(event);
      await _updateTotalScreenshotsCount();
    });
  }

  static Future<void> _processNewScreenshot(String filePath) async {
    try {
      // Add a small delay to ensure the file is fully written
      await Future.delayed(const Duration(milliseconds: 100));

      if (await _isAlreadyIndexed(filePath)) {
        print('IndexService: File already indexed: $filePath');
        return;
      }

      print('IndexService: Processing new screenshot: $filePath');

      // Run tesseract
      final result = await Process.run('tesseract', [filePath, 'stdout']);
      final extractedText = result.stdout.toString();

      // Call Ollama with proper config path and null safety
      final ollamaConfig =
          ConfigService.configData['ollama'] as Map<String, dynamic>? ?? {};
      final ollamaPrompt =
          ollamaConfig['prompt'] as String? ?? 'Describe this screenshot:';
      final ollamaModel = ollamaConfig['model'] as String? ?? 'llama2';

      final ollamaResult = await Process.run('ollama', [
        'run',
        ollamaModel,
        '$ollamaPrompt\nExtracted text: $extractedText'
      ]);

      // Store in database
      await database.insert('screenshots', {
        'id': filePath,
        'path': filePath,
        'extracted_text': extractedText,
        'ollama_description': ollamaResult.stdout.toString(),
        'platform': Platform.operatingSystem,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      print('IndexService: Successfully processed new screenshot: $filePath');

      // Update the progress notifier
      progressNotifier.value = progressNotifier.value.copyWith(
        processed: progressNotifier.value.processed + 1,
        current: filePath,
      );
    } catch (e, stackTrace) {
      print('IndexService: Error processing new screenshot: $e');
      print('IndexService: Stack trace: $stackTrace');
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
