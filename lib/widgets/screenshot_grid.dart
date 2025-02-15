import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/index_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Set<String> _indexedFiles = {};

  @override
  void initState() {
    super.initState();
    _loadIndexedFiles();
    _startMonitoring();
  }

  @override
  void dispose() {
    // Remove the listener correctly
    IndexService.totalScreenshotsNotifier.removeListener(_loadIndexedFiles);
    super.dispose();
  }

  Future<void> _loadIndexedFiles() async {
    try {
      final indexed = await IndexService.getIndexedFiles();
      setState(() {
        _indexedFiles = indexed.map((e) => e['path'] as String).toSet();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading indexed files: $e');
      }
    }
  }

  void _startMonitoring() {
    final directoryPath = _getScreenshotDirectory();
    final directory = Directory(directoryPath);

    if (!directory.existsSync()) return;

    IndexService.monitorDirectory(directory, (FileSystemEvent event) async {
      if (event.type == FileSystemEvent.create ||
          event.type == FileSystemEvent.delete) {
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

            return Card(
              color: isHighlighted ? Colors.yellow[100] : null,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () async {
                      // Open the image file with the system's default image viewer
                      final Uri imageFileUri = Uri.file(filePath);
                      if (await canLaunchUrl(imageFileUri)) {
                        await launchUrl(imageFileUri);
                      } else {
                        if (kDebugMode) {
                          print('Could not launch $imageFileUri');
                        }
                        // Optionally show an error message to the user
                      }
                    },
                    child: Image.file(
                      File(filePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.error)),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () async {
                        // Open the file in the system's file explorer
                        final Uri fileExplorerUri =
                            Uri.directory(File(filePath).parent.path);
                        if (await canLaunchUrl(fileExplorerUri)) {
                          await launchUrl(fileExplorerUri);
                        } else {
                          if (kDebugMode) {
                            print('Could not launch $fileExplorerUri');
                          }
                          // Optionally show an error message to the user
                        }
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
            );
          },
        );
      },
    );
  }
}
