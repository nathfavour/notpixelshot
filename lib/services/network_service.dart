import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:async';
import 'config_service.dart';

class NetworkService {
  static final _info = NetworkInfo();
  static const int defaultPort = 9876;
  static List<String> _discoveredHosts = [];

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

    // Get local IP address and subnet
    final wifiIP = await _info.getWifiIP();
    if (wifiIP == null) {
      print('Could not determine local IP address');
      return null;
    }

    // Extract subnet (e.g., "192.168.1" from "192.168.1.100")
    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    _discoveredHosts = [];

    // Create UDP socket for discovery
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    // Send discovery packet to all possible hosts
    for (int i = 1; i < 255; i++) {
      final host = '$subnet.$i';
      try {
        final response = await http
            .get(Uri.parse('http://$host:$defaultPort/api/status'))
            .timeout(Duration(milliseconds: timeout));

        if (response.statusCode == 200) {
          print('Found server at $host:$defaultPort');
          _discoveredHosts.add(host);
        }
      } catch (e) {
        // Skip failed connections
        continue;
      }
    }

    socket.close();

    // Return the first discovered host, if any
    if (_discoveredHosts.isNotEmpty) {
      return _discoveredHosts.first;
    }

    print('No servers found on network');
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
