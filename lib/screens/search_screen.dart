import 'package:flutter/material.dart';
import '../widgets/search_bar.dart';
import '../widgets/screenshot_grid.dart';
import '../widgets/fullscreen_image.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = '';
  bool _isLoading = false;

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _isLoading = true;
    });
    // Trigger search in IndexService
    // Update UI when results are available
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NotPixelShot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          CustomSearchBar(onSearch: _onSearch),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ScreenshotGrid(searchQuery: _searchQuery),
          ),
        ],
      ),
    );
  }
}
