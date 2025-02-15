import 'dart:io';
import 'dart:convert';
import 'config_service.dart';

class NetworkService {
  static Future<void> initialize() async {
    int port = 9876;
    bool serverRunning = false;
    HttpServer? server;

    // Check if a server is already running
    if (await _isServerRunning(port)) {
      print('Server already running on port $port. Skipping server start.');
      return;
    }

    while (!serverRunning && port <= 9900) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, port);
        serverRunning = true;

        server.listen((HttpRequest request) {
          print('Request received on port $port: ${request.uri.path}');
          if (request.uri.path == '/config') {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.set('Content-Type', 'application/json')
              ..write(jsonEncode(ConfigService.configData))
              ..close();
          } else {
            request.response
              ..statusCode = HttpStatus.notFound
              ..write('Not Found')
              ..close();
          }
        });

        print('Server started on port $port');
      } catch (e) {
        print('Failed to bind port $port: $e');
        port++;
      }
    }

    if (!serverRunning) {
      print('Failed to start server on any port between 9876 and 9900.');
    }
  }

  static Future<bool> _isServerRunning(int port) async {
    try {
      final socket = await Socket.connect('localhost', port)
          .timeout(const Duration(milliseconds: 500));
      socket.close();
      print('Server is running on port $port');
      return true;
    } catch (e) {
      print('Server is not running on port $port');
      return false;
    }
  }
}
