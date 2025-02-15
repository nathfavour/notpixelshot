import 'package:flutter/material.dart';
import 'dart:async';
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
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadAllScreenshots();
  }

  Future<void> _loadAllScreenshots() async {
    print('SearchScreen: Loading all screenshots...');
    setState(() {
      _searchResultsFuture = IndexService.getIndexedFiles();
    });
  }

  void _onSearch(String query) {
    print('SearchScreen: Search query received: "$query"');
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        if (query.trim().isEmpty) {
          print('SearchScreen: Empty query, loading all screenshots');
          _searchResultsFuture = IndexService.getIndexedFiles();
        } else {
          print('SearchScreen: Searching for: "$query"');
          _searchResultsFuture = IndexService.searchScreenshots(query);
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
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
                  print(
                      'SearchScreen: Error loading results: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (snapshot.hasData) {
                  final searchResults = snapshot.data!;
                  print(
                      'SearchScreen: Displaying ${searchResults.length} results');
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ScreenshotGrid(
                      searchQuery: _searchQuery,
                      searchResults: searchResults,
                    ),
                  );
                } else {
                  print('SearchScreen: No results found');
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
