import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'config_service.dart';

class NetworkService {
  static Future<void> initialize() async {
    // Only desktop platforms should start a server
    if (Platform.isAndroid || Platform.isIOS) {
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

        print('Server started on port $port');
      } catch (e) {
        print('Failed to bind port $port: $e');
        port++;
      }
    }
  }

  static void _handleRequest(HttpRequest request, int port) async {
    print('Request received on port $port: ${request.uri.path}');

    switch (request.uri.path) {
      case '/api/config':
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.set('Content-Type', 'application/json')
          ..write(jsonEncode(ConfigService.configData))
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
  }

  static Future<String?> findServer() async {
    final timeout = ConfigService.configData['serverTimeout'] ?? 5000;

    for (int port = 9876; port <= 9900; port++) {
      try {
        final response = await http
            .get(Uri.parse('http://0.0.0.0:$port/api/status'))
            .timeout(Duration(milliseconds: timeout));

        if (response.statusCode == 200) {
          return '0.0.0.0:$port';
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
