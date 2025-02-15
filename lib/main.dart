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
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('WidgetsFlutterBinding initialized');

    // Initialize FFI for sqflite on desktop platforms
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      print('sqflite FFI initialized');
    }

    print('Initializing ConfigService...');
    await ConfigService.initialize();
    print('ConfigService initialized');

    if (!Platform.isAndroid && !Platform.isIOS) {
      print('Initializing NetworkService...');
      await NetworkService.initialize();
      print('NetworkService initialized');
    }

    print('Initializing IndexService...');
    await IndexService.initialize();
    print('IndexService initialized');

    print('Running MyApp...');
    runApp(const MyApp());
    print('MyApp is running');
  } catch (e, stackTrace) {
    print('Error during initialization: $e');
    print('Stack trace: $stackTrace');
    rethrow;
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
