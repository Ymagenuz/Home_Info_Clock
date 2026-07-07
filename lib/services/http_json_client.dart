import 'dart:convert';

import 'package:http/http.dart' as http;

class JsonHttpClient {
  const JsonHttpClient({this.client});

  final http.Client? client;

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final activeClient = client ?? http.Client();
    try {
      final response = await activeClient.get(
        uri,
        headers: {'Accept': 'application/json', ...headers},
      );
      _throwForStatus('GET', uri, response.statusCode);
      return _decodeObject(response.body);
    } finally {
      if (client == null) {
        activeClient.close();
      }
    }
  }

  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) async {
    final activeClient = client ?? http.Client();
    try {
      final response = await activeClient.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
          ...headers,
        },
        body: jsonEncode(body),
      );
      _throwForStatus('POST', uri, response.statusCode);
      return _decodeObject(response.body);
    } finally {
      if (client == null) {
        activeClient.close();
      }
    }
  }

  static void _throwForStatus(String method, Uri uri, int statusCode) {
    if (statusCode < 200 || statusCode >= 300) {
      throw StateError(
        '$method ${uri.host}${uri.path} failed: HTTP $statusCode',
      );
    }
  }

  static Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Expected top-level JSON object');
  }
}
