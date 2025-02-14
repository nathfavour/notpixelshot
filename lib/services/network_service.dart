import 'dart:io';

class NetworkService {
  static Future<void> initialize() async {
    int port = 9876;
    bool serverRunning = false;
    HttpServer? server;

    while (!serverRunning && port <= 9900) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, port);
        serverRunning = true;

        server.listen((HttpRequest request) {
          print('Request received on port $port');
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.set('Content-Type', 'text/plain')
            ..write('Hello, world! from port $port')
            ..close();
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
}
