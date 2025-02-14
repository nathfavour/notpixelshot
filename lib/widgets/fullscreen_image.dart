import 'package:flutter/material.dart';
import 'dart:io';

class FullScreenImage extends StatelessWidget {
  final File imageFile;
  const FullScreenImage({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Image.file(imageFile),
        ),
      ),
    );
  }
}
