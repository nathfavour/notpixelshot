import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/index_service.dart';

class ScreenshotGrid extends StatefulWidget {
  final String searchQuery;
  final List<Map<String, dynamic>>? searchResults;

  const ScreenshotGrid(
      {Key? key, required this.searchQuery, this.searchResults})
      : super(key: key);

  @override
  State<ScreenshotGrid> createState() => _ScreenshotGridState();
}

class _ScreenshotGridState extends State<ScreenshotGrid> {
  // Remove _files and related logic
  // List<FileSystemEntity> _files = [];
  Set<String> _indexedFiles = {};

  @override
  void initState() {
    super.initState();
    // Remove _loadFiles()
    _loadIndexedFiles();
    _startMonitoring();
  }

  @override
  void dispose() {
    IndexService.totalScreenshotsNotifier.removeListener(
        // Remove _loadFiles
        null);
    super.dispose();
  }

  // Remove _loadFiles()
  // Future<void> _loadFiles() async {
  //   try {
  //     final directoryPath = _getScreenshotDirectory();
  //     final directory = Directory(directoryPath);
  //     print('ScreenshotGrid: Loading files from directory: $directoryPath');
  //     if (!await directory.exists()) {
  //       print('ScreenshotGrid: Directory does not exist: $directoryPath');
  //       return;
  //     }
  //     final files = await directory
  //         .list()
  //         .where((f) =>
  //             f.path.toLowerCase().endsWith('.png') ||
  //             f.path.toLowerCase().endsWith('.jpg'))
  //         .toList();
  //     print('ScreenshotGrid: Found ${files.length} files.');
  //     setState(() {
  //       _files = files;
  //     });
  //   } catch (e) {
  //     print('ScreenshotGrid: Error loading files: $e');
  //   }
  // }

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
        // Remove _loadFiles()
        // await _loadFiles();
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
    // Use the search results if available
    final filesToShow = widget.searchResults;

    return ValueListenableBuilder<int>(
      valueListenable: IndexService.totalScreenshotsNotifier,
      builder: (context, totalScreenshots, child) {
        if (totalScreenshots == 0) {
          final dirPath = _getScreenshotDirectory();
          return Center(
            child: Text('No screenshots found in:\n$dirPath',
                textAlign: TextAlign.center),
          );
        }
        return GridView.builder(
          itemCount: filesToShow?.length ?? 0,
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final file = filesToShow![index];
            final filePath = file['path'] as String;
            final isIndexed = _indexedFiles.contains(filePath);
            final isHighlighted = widget.searchQuery.isNotEmpty &&
                filePath
                    .toLowerCase()
                    .contains(widget.searchQuery.toLowerCase());

            return GestureDetector(
              onTap: () {
                // Show fullscreen preview
              },
              child: Card(
                color: isHighlighted ? Colors.yellow[100] : null,
                child: Stack(
                  children: [
                    Image.file(
                      File(filePath),
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
