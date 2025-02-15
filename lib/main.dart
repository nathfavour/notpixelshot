import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/config_service.dart';
import 'services/network_service.dart';
import 'services/index_service.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

export 'main.dart' show navigatorKey;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp()); // Show UI first

  // Start services in the background
  unawaited(_initializeServices());
}

Future<void> _initializeServices() async {
  try {
    print('Initializing services in background...');
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await Future.wait([
      ConfigService.initialize(),
      if (!Platform.isAndroid && !Platform.isIOS) NetworkService.initialize(),
      IndexService.initialize(),
    ]);
    print('All services initialized in background');

    // Start processing automatically without blocking the UI
    await IndexService.startProcessing();
  } catch (e, stackTrace) {
    print('Error during service initialization: $e');
    print('Stack trace: $stackTrace');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'NotPixelShot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SearchScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
