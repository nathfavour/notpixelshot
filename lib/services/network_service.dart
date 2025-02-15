import 'dart:io';
import 'dart:convert';
import 'config_service.dart';

class NetworkService {
  static Future<void> initialize() async {
    int port = 9876;
    bool serverRunning = false;
    HttpServer? server;
    int timeout = ConfigService.configData['serverTimeout'] ??
        5000; // Default timeout 5 seconds

    // Check if a server is already running
    if (await _isServerRunning('0.0.0.0', port, timeout)) {
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

  static Future<bool> _isServerRunning(
      String host, int port, int timeout) async {
    try {
      final socket = await Socket.connect(host, port)
          .timeout(Duration(milliseconds: timeout));
      socket.close();
      print('Server is running on $host:$port');
      return true;
    } catch (e) {
      print('Server is not running on $host:$port');
      return false;
    }
  }
}
