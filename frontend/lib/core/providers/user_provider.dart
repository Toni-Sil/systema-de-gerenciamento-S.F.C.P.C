// UserProvider refatorado — JWT claims + token lifecycle
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  UserModel _user = UserModel.guest();
  bool _isAuthenticated = false;

  UserModel get user => _user;
  bool get isAuthenticated => _isAuthenticated;

  // Compat com código existente
  String get adminName => _user.name;
  String get companyName => _user.company;
  String get profileImageUrl =>
      _user.profileImageUrl ??
      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_user.name)}&background=00BCD4&color=fff';
  String get tenantId => _user.tenantId;
  String get role => _user.role;

  /// Inicializa lendo token salvo do SharedPreferences
  Future<void> init() async {
    await ApiService.instance.init();
    if (ApiService.instance.hasToken) {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      if (userJson != null) {
        _user = UserModel.fromJwtClaims(
            jsonDecode(userJson) as Map<String, dynamic>);
        _isAuthenticated = true;
        notifyListeners();
      }
    }
  }

  /// Login via API
  Future<bool> login(String email, String password) async {
    try {
      final res = await ApiService.instance.login(email, password);
      final token = res['access_token'] as String;
      await ApiService.instance.setToken(token);

      // Decodifica payload do JWT (sem verificação — apenas claims)
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])));
        final claims = jsonDecode(payload) as Map<String, dynamic>;
        _user = UserModel.fromJwtClaims(claims);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(claims));
      }

      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Logout — limpa JWT e dados locais
  Future<void> logout() async {
    await ApiService.instance.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    _user = UserModel.guest();
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Atualização manual de perfil (Settings)
  Future<void> updateProfile(String name, String company,
      {String? imageUrl}) async {
    _user = UserModel(
      id: _user.id,
      name: name,
      company: company,
      role: _user.role,
      tenantId: _user.tenantId,
      profileImageUrl: imageUrl ?? _user.profileImageUrl,
    );
    notifyListeners();

    // Persiste localmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(_user.toJson()));
  }
}
