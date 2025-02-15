import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:async';
import 'config_service.dart';

class NetworkService {
  static final _info = NetworkInfo();

  // Use config for server settings
  static int get defaultPort => ConfigService.configData['server']['port'];
  static int get serverTimeout => ConfigService.configData['server']['timeout'];
  static List<String> _discoveredHosts = [];

  static Future<void> initialize() async {
    try {
      print('NetworkService: Initializing...');
      // Only desktop platforms should start a server
      if (Platform.isAndroid || Platform.isIOS) {
        print(
            'NetworkService: Running on mobile, skipping server initialization');
        return;
      }

      int port = 9876;
      bool serverRunning = false;
      HttpServer? server;

      while (!serverRunning && port <= 9900) {
        try {
          server = await HttpServer.bind(InternetAddress.anyIPv4, port);
          serverRunning = true;

          server.listen((HttpRequest request) {
            _handleRequest(request, port);
          });

          print('NetworkService: Server started on port $port');
        } catch (e, stackTrace) {
          print('NetworkService: Failed to bind port $port: $e');
          print('NetworkService: Stack trace: $stackTrace');
          port++;
        }
      }

      if (!serverRunning) {
        print(
            'NetworkService: Failed to start server on any port between 9876 and 9900.');
      }
      print('NetworkService: Initialization complete');
    } catch (e, stackTrace) {
      print('NetworkService: Error during initialization: $e');
      print('NetworkService: Stack trace: $stackTrace');
    }
  }

  static Future<void> _handleRequest(HttpRequest request, int port) async {
    try {
      print(
          'NetworkService: Request received on port $port: ${request.uri.path}');

      switch (request.uri.path) {
        case '/api/config':
          // Force reload config from file before sending
          await ConfigService.reloadConfigFromFile();
          final config = ConfigService.configData;
          print('NetworkService: Sending config data: $config');
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.set('Content-Type', 'application/json')
            ..headers.set('Access-Control-Allow-Origin', '*')
            ..write(jsonEncode(config))
            ..close();
          break;

        case '/api/status':
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.set('Content-Type', 'application/json')
            ..write(jsonEncode({'status': 'running', 'port': port}))
            ..close();
          break;

        default:
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found')
            ..close();
      }
    } catch (e, stackTrace) {
      print('NetworkService: Error handling request: $e');
      print('NetworkService: Stack trace: $stackTrace');
    }
  }

  static Future<String?> findServer() async {
    final timeout = ConfigService.configData['server']['timeout'];

    try {
      // Try common local network addresses first
      final hosts = [
        '192.168.1.', // Common home network
        '192.168.0.', // Common home network
        '10.0.2.', // Android emulator
        '172.16.', // Other private networks
        '172.17.',
        '172.18.',
        '172.19.',
        '172.20.'
      ];

      for (var subnet in hosts) {
        for (var i = 1; i < 255; i++) {
          final host = '$subnet$i';
          try {
            final response = await http
                .get(Uri.parse('http://$host:$defaultPort/api/status'))
                .timeout(Duration(milliseconds: timeout));

            if (response.statusCode == 200) {
              print('Found server at $host:$defaultPort');
              return host;
            }
          } catch (e) {
            continue;
          }
        }
      }
    } catch (e, stackTrace) {
      print('NetworkService: Error during server discovery: $e');
      print('NetworkService: Stack trace: $stackTrace');
    }

    print('NetworkService: No servers found on network');
    return null;
  }

  static List<String> get discoveredHosts => _discoveredHosts;

  static Future<bool> isServerRunning(String host, int port) async {
    try {
      final response = await http
          .get(Uri.parse('http://$host:$port/api/status'))
          .timeout(const Duration(milliseconds: 500));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
