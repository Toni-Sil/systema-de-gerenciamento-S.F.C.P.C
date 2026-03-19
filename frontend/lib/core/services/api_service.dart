// SEC #3: _defaultBase usa https; warn no console se URL não for HTTPS em modo release
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Exceção específica para erros de autenticação (SEC #5)
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _baseUrlKey = 'api_base_url';
  // SEC #3: default agora é https
  static const _defaultBase = 'https://localhost:8000';

  String _baseUrl = _defaultBase;
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBase;
    // SEC #1: token lido do secure storage
    _token = await SecureStorageService.instance.readToken();
    _warnInsecureUrl(_baseUrl);
  }

  Future<void> setBaseUrl(String url) async {
    final normalized =
        url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _warnInsecureUrl(normalized);
    _baseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  /// SEC #3: avisa no console se URL não usar HTTPS em release
  void _warnInsecureUrl(String url) {
    if (!kDebugMode && url.startsWith('http://')) {
      debugPrint(
          '[ApiService] ⚠️ SECURITY WARNING: URL não usa HTTPS: $url\n'
          'Dados tráfegam sem criptografia. Configure HTTPS no VPS.');
    }
  }

  String get baseUrl => _baseUrl;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  // SEC #1: token salvo no secure storage
  Future<void> setToken(String token) async {
    _token = token;
    await SecureStorageService.instance.writeToken(token);
  }

  Future<void> clearToken() async {
    _token = null;
    await SecureStorageService.instance.deleteToken();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('$_baseUrl$path');
    return params != null ? uri.replace(queryParameters: params) : uri;
  }

  Map<String, dynamic> _parse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        return {}; // fallback for success with empty/non-json body
      }
    }
    // SEC #5: 401/403 lançam AuthException para UI distinguir
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const AuthException('Credenciais inválidas ou sessão expirada.');
    }
    try {
      final decoded = jsonDecode(res.body) as Map?;
      throw ApiException(res.statusCode, decoded?['detail']?.toString() ?? 'Erro desconhecido');
    } catch (_) {
      throw ApiException(res.statusCode, 'Erro no servidor: ${res.statusCode}');
    }
  }

  List<dynamic> _parseList(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final body = jsonDecode(res.body);
        return body is List ? body : (body['items'] as List? ?? []);
      } catch (e) {
        return [];
      }
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const AuthException('Sessão expirada. Faça login novamente.');
    }
    try {
      final decoded = jsonDecode(res.body) as Map?;
      throw ApiException(res.statusCode, decoded?['detail']?.toString() ?? 'Erro desconhecido');
    } catch (_) {
      throw ApiException(res.statusCode, 'Erro no servidor: ${res.statusCode}');
    }
  }

  // ─── INVENTORY ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getInventory(
      {String? category, String? search}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await http.get(_uri('/api/v1/inventory', params),
        headers: _headers);
    return _parseList(res);
  }

  Future<Map<String, dynamic>> addInventoryItem(
      Map<String, dynamic> item) async {
    final res = await http.post(_uri('/api/v1/inventory'),
        headers: _headers, body: jsonEncode(item));
    return _parse(res);
  }

  Future<Map<String, dynamic>> updateInventoryBalance(
      String code, double delta, String reason) async {
    final res = await http.patch(
      _uri('/api/v1/inventory/$code/balance'),
      headers: _headers,
      body: jsonEncode({'delta': delta, 'reason': reason}),
    );
    return _parse(res);
  }

  Future<void> deleteInventoryItem(String code) async {
    final res = await http.delete(
        _uri('/api/v1/inventory/$code'),
        headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException(res.statusCode, 'Falha ao deletar item');
    }
  }

  // ─── AGENT ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendAgentMessage(String message,
      {String? context}) async {
    final res = await http.post(
      _uri('/api/v1/agent/chat'),
      headers: _headers,
      body: jsonEncode({
        'message': message,
        if (context != null) 'context': context,
      }),
    );
    return _parse(res);
  }

  // ─── FINANCIAL ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFinancialSummary() async {
    final res = await http.get(
        _uri('/api/v1/financial/summary'), headers: _headers);
    return _parse(res);
  }

  Future<List<dynamic>> getTransactions(
      {String? period, int page = 1}) async {
    final res = await http.get(
      _uri('/api/v1/financial/transactions',
          {'period': period ?? '30d', 'page': page.toString()}),
      headers: _headers,
    );
    return _parseList(res);
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await http.post(
      _uri('/api/v1/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  // ─── FORECAST ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getForecast(String itemCode) async {
    final res = await http.get(
        _uri('/api/v1/forecast/$itemCode'), headers: _headers);
    return _parse(res);
  }
}
