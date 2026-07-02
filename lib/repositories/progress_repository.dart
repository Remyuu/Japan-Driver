import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_store.dart';

typedef IdTokenProvider = Future<String> Function({bool forceRefresh});

class ProgressRepositoryException implements Exception {
  const ProgressRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProgressRepository {
  ProgressRepository({
    required this.idTokenProvider,
    http.Client? client,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _apiBaseUrl = apiBaseUrl ?? defaultApiBaseUrl;

  static const defaultApiBaseUrl = String.fromEnvironment(
    'JP_DRIVER_API_BASE_URL',
    defaultValue: 'https://remoooo.com/jp-driver-api/v1',
  );
  static const legacyStorageKey = 'japan_driver_progress_v1';

  final IdTokenProvider idTokenProvider;
  final http.Client _client;
  final String _apiBaseUrl;

  Uri _uri(String path) =>
      Uri.parse('${_apiBaseUrl.replaceAll(RegExp(r'/$'), '')}/$path');

  Future<ProgressStore> load(String userId) async {
    final response = await _sendAuthorized('GET', _uri('progress'));
    if (response.statusCode == 200) {
      return _decodeResponse(response);
    }
    if (response.statusCode == 404) {
      final local = await _loadLegacyLocal(userId);
      await save(userId, local);
      await _removeLegacyLocal(userId);
      return local;
    }
    throw _responseException(response);
  }

  Future<void> save(String userId, ProgressStore store) async {
    final response = await _sendAuthorized(
      'PUT',
      _uri('progress'),
      body: jsonEncode({'data': store.toJson()}),
    );
    if (response.statusCode != 200) {
      throw _responseException(response);
    }
  }

  Future<http.Response> _sendAuthorized(
    String method,
    Uri uri, {
    String? body,
  }) async {
    var token = await idTokenProvider(forceRefresh: false);
    var response = await _send(method, uri, token: token, body: body);
    if (response.statusCode == 401) {
      token = await idTokenProvider(forceRefresh: true);
      response = await _send(method, uri, token: token, body: body);
    }
    return response;
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    required String token,
    String? body,
  }) {
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    return switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'PUT' => _client.put(uri, headers: headers, body: body),
      _ => throw ArgumentError.value(method, 'method'),
    };
  }

  ProgressStore _decodeResponse(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const ProgressRepositoryException('サーバーのデータ形式が正しくありません。');
    }
    return ProgressStore.decode(jsonEncode(decoded['data']));
  }

  ProgressRepositoryException _responseException(http.Response response) {
    var message = 'ユーザーデータを同期できませんでした (${response.statusCode})。';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } catch (_) {
      // Keep the status-based message for non-JSON server responses.
    }
    return ProgressRepositoryException(message);
  }

  Future<ProgressStore> _loadLegacyLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final source =
        prefs.getString('$legacyStorageKey:user:$userId') ??
        prefs.getString(legacyStorageKey);
    return ProgressStore.decode(source);
  }

  Future<void> _removeLegacyLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$legacyStorageKey:user:$userId');
    await prefs.remove(legacyStorageKey);
  }
}
