import 'package:flutter/material.dart';
import '../widgets/search_bar.dart';
import '../widgets/screenshot_grid.dart';
import '../widgets/processing_status.dart';
import '../services/index_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = '';
  Future<List<Map<String, dynamic>>>? _searchResultsFuture;

  @override
  void initState() {
    super.initState();
    // Initialize with all screenshots
    _loadAllScreenshots();
  }

  Future<void> _loadAllScreenshots() async {
    _searchResultsFuture = IndexService.getIndexedFiles();
    setState(() {}); // Trigger rebuild with loaded screenshots
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        // Load all screenshots when search is empty
        _searchResultsFuture = IndexService.getIndexedFiles();
      } else {
        _searchResultsFuture = IndexService.searchScreenshots(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NotPixelShot'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: CustomSearchBar(onSearch: _onSearch),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const ProcessingStatus(),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _searchResultsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (snapshot.hasData) {
                  final searchResults = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ScreenshotGrid(
                      searchQuery: _searchQuery,
                      searchResults: searchResults,
                    ),
                  );
                } else {
                  return const Center(child: Text('No results found.'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
