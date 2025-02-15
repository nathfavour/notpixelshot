import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/index_service.dart';

class ScreenshotGrid extends StatefulWidget {
  final String searchQuery;

  const ScreenshotGrid({Key? key, required this.searchQuery}) : super(key: key);

  @override
  State<ScreenshotGrid> createState() => _ScreenshotGridState();
}

class _ScreenshotGridState extends State<ScreenshotGrid> {
  List<FileSystemEntity> _files = [];
  Set<String> _indexedFiles = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadIndexedFiles();
    _startMonitoring();
  }

  @override
  void dispose() {
    IndexService.totalScreenshotsNotifier.removeListener(_loadFiles);
    super.dispose();
  }

  Future<void> _loadFiles() async {
    try {
      final directoryPath = _getScreenshotDirectory();
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        print('Screenshot directory does not exist: $directoryPath');
        return;
      }

      final files = await directory
          .list()
          .where((f) =>
              f.path.toLowerCase().endsWith('.png') ||
              f.path.toLowerCase().endsWith('.jpg'))
          .toList();

      setState(() {
        _files = files;
      });
    } catch (e) {
      print('Error loading files: $e');
    }
  }

  Future<void> _loadIndexedFiles() async {
    try {
      final indexed = await IndexService.getIndexedFiles();
      setState(() {
        _indexedFiles = indexed.map((e) => e['path'] as String).toSet();
      });
    } catch (e) {
      print('Error loading indexed files: $e');
    }
  }

  void _startMonitoring() {
    final directoryPath = _getScreenshotDirectory();
    final directory = Directory(directoryPath);

    if (!directory.existsSync()) return;

    IndexService.monitorDirectory(directory, (FileSystemEvent event) async {
      if (event.type == FileSystemEvent.create ||
          event.type == FileSystemEvent.delete) {
        await _loadFiles();
        await _loadIndexedFiles();
      }
    });
  }

  String _getScreenshotDirectory() {
    if (Platform.isWindows) {
      return IndexService.screenshotDirectoryWindows;
    } else if (Platform.isMacOS) {
      return IndexService.screenshotDirectoryMacOS;
    } else if (Platform.isLinux) {
      return IndexService.screenshotDirectoryLinux;
    } else {
      return IndexService.screenshotDirectory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: IndexService.totalScreenshotsNotifier,
      builder: (context, totalScreenshots, child) {
        if (_files.isEmpty) {
          return const Center(
            child: Text('No screenshots found.'),
          );
        }
        return GridView.builder(
          itemCount: _files.length,
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final file = _files[index];
            final isIndexed = _indexedFiles.contains(file.path);

            return GestureDetector(
              onTap: () {
                // Show fullscreen preview
              },
              child: Card(
                child: Stack(
                  children: [
                    Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.error)),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: () {
                          // Open file in system explorer
                        },
                      ),
                    ),
                    if (isIndexed)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
