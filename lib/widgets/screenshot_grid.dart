import 'package:flutter/material.dart';
import 'dart:io';
import '../services/index_service.dart';

class ScreenshotGrid extends StatelessWidget {
  final String searchQuery;

  const ScreenshotGrid({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            // Show fullscreen preview
          },
          child: Card(
            child: Stack(
              children: [
                // Replace with actual screenshot file path when available.
                Image.file(File('path/to/placeholder.png')),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
