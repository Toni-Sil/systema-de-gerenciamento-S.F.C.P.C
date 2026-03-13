// ApiService — singleton HTTP com JWT interceptor e baseUrl configurável
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _baseUrlKey = 'api_base_url';
  static const _tokenKey = 'jwt_token';
  static const _defaultBase = 'http://localhost:8000';

  String _baseUrl = _defaultBase;
  String? _token;

  /// Carrega baseUrl e token salvos
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBase;
    _token = prefs.getString(_tokenKey);
  }

  /// Atualiza a URL base da API (salva no SharedPreferences)
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  String get baseUrl => _baseUrl;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Salva o JWT após login
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Limpa o JWT (logout)
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Headers padrão com Authorization Bearer
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
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode,
        (jsonDecode(res.body) as Map?)?['detail']?.toString() ?? res.body);
  }

  List<dynamic> _parseList(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body);
      return body is List ? body : (body['items'] as List? ?? []);
    }
    throw ApiException(res.statusCode,
        (jsonDecode(res.body) as Map?)?['detail']?.toString() ?? res.body);
  }

  // ─── INVENTORY ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getInventory({String? category, String? search}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await http.get(_uri('/api/v1/inventory', params), headers: _headers);
    return _parseList(res);
  }

  Future<Map<String, dynamic>> addInventoryItem(Map<String, dynamic> item) async {
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
    final res =
        await http.delete(_uri('/api/v1/inventory/$code'), headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException(res.statusCode, 'Falha ao deletar item');
    }
  }

  // ─── AGENT ─────────────────────────────────────────────────────────────────

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

  // ─── FINANCIAL ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFinancialSummary() async {
    final res =
        await http.get(_uri('/api/v1/financial/summary'), headers: _headers);
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

  // ─── AUTH ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await http.post(
      _uri('/api/v1/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  // ─── FORECAST ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getForecast(String itemCode) async {
    final res = await http.get(
        _uri('/api/v1/forecast/$itemCode'), headers: _headers);
    return _parse(res);
  }
}
