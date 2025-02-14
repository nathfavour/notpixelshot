import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/index_service.dart';

class ScreenshotGrid extends StatefulWidget {
  final String searchQuery;

  const ScreenshotGrid({super.key, required this.searchQuery});

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

  Future<void> _loadFiles() async {
    final directoryPath = IndexService.screenshotDirectory;
    final directory = Directory(directoryPath);

    if (!await directory.exists()) return;

    final files = await directory
        .list()
        .where((f) =>
            f.path.toLowerCase().endsWith('.png') ||
            f.path.toLowerCase().endsWith('.jpg'))
        .toList();

    setState(() {
      _files = files;
    });
  }

  Future<void> _loadIndexedFiles() async {
    final indexed = await IndexService.getIndexedFiles();
    setState(() {
      _indexedFiles = indexed.map((e) => e['path'] as String).toSet();
    });
  }

  void _startMonitoring() {
    final directoryPath = IndexService.screenshotDirectory;
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

  @override
  Widget build(BuildContext context) {
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
  }
}
