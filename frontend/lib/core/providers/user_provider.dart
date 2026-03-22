// SEC #1: JWT e user_data via SecureStorageService (AES-256 Keystore)
// SEC #2: valida campo 'exp' do JWT antes de autenticar
// SEC #5: login distingue AuthException de erros de rede
// SEC #6: updateProfile só executa se _isAuthenticated
// FIX #2: logout chama OfflineSyncService.clearAll() para limpar dados Hive do usuário
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../services/offline_sync_service.dart';

enum LoginError { none, invalidCredentials, networkError, sessionExpired }

class UserProvider with ChangeNotifier {
  UserModel _user = UserModel.guest();
  bool _isAuthenticated = false;
  LoginError _lastLoginError = LoginError.none;

  UserModel get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  LoginError get lastLoginError => _lastLoginError;

  String get adminName => _user.name;
  String get companyName => _user.company;
  String get profileImageUrl =>
      _user.profileImageUrl ??
      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_user.name)}&background=00BCD4&color=fff';
  String get tenantId => _user.tenantId;
  String get role => _user.role;

  Future<void> init() async {
    await ApiService.instance.init();
    final userJson = await SecureStorageService.instance.readUserData();
    if (userJson != null && ApiService.instance.hasToken) {
      try {
        final claims = jsonDecode(userJson) as Map<String, dynamic>;
        if (!_isTokenExpired(claims)) {
          _user = UserModel.fromJwtClaims(claims);
          _isAuthenticated = true;
          notifyListeners();
        } else {
          debugPrint('[UserProvider] Token expirado no init — forçando logout');
          await _clearSession();
        }
      } catch (e) {
        debugPrint('[UserProvider] init parse error: $e');
        await _clearSession();
      }
    } else {
      await identify(
        name: 'Equipe',
        role: 'operator',
      );
    }
  }

  Future<bool> login(String email, String password) async {
    _lastLoginError = LoginError.none;
    try {
      final res = await ApiService.instance.login(email, password);
      final token = res['access_token'] as String;
      await ApiService.instance.setToken(token);

      final parts = token.split('.');
      if (parts.length == 3) {
        final payload =
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final claims = jsonDecode(payload) as Map<String, dynamic>;

        if (_isTokenExpired(claims)) {
          _lastLoginError = LoginError.sessionExpired;
          return false;
        }

        _user = UserModel.fromJwtClaims(claims);
        await SecureStorageService.instance.writeUserData(jsonEncode(claims));
      }

      _isAuthenticated = true;
      _lastLoginError = LoginError.none;
      notifyListeners();
      return true;
    } on AuthException {
      _lastLoginError = LoginError.invalidCredentials;
      notifyListeners();
      return false;
    } catch (e) {
      _lastLoginError = LoginError.networkError;
      debugPrint('[UserProvider] login network error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> identify({
    required String name,
    required String role,
    String? company,
  }) async {
    _lastLoginError = LoginError.none;
    try {
      final res = await ApiService.instance.identify(
        name: name,
        role: role,
        company: company,
      );
      final token = res['access_token'] as String;
      await ApiService.instance.setToken(token);

      final parts = token.split('.');
      if (parts.length == 3) {
        final payload =
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final claims = jsonDecode(payload) as Map<String, dynamic>;
        _user = UserModel.fromJwtClaims(claims);
        await SecureStorageService.instance.writeUserData(jsonEncode(claims));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('operational_role', role);
        await prefs.setString('operational_name', name);
      }

      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[UserProvider] identify error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _clearSession();
  }

  Future<void> updateProfile(String name, String company,
      {String? imageUrl, String? role}) async {
    if (!_isAuthenticated) {
      debugPrint(
          '[UserProvider] updateProfile bloqueado: usuário não autenticado');
      return;
    }
    final nextRole = role ?? _user.role;
    final identified = await identify(name: name, role: nextRole, company: company);
    if (!identified) return;
    _user = UserModel(
      id: _user.id,
      name: name,
      company: company,
      role: nextRole,
      tenantId: _user.tenantId,
      profileImageUrl: imageUrl ?? _user.profileImageUrl,
    );
    notifyListeners();
    await SecureStorageService.instance.writeUserData(jsonEncode(_user.toJson()));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  bool _isTokenExpired(Map<String, dynamic> claims) {
    final exp = claims['exp'];
    if (exp == null) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    return DateTime.now().isAfter(expiry);
  }

  // FIX #2: limpa Hive local além de JWT e SecureStorage
  Future<void> _clearSession() async {
    await ApiService.instance.clearToken();
    await SecureStorageService.instance.deleteUserData();
    try {
      await OfflineSyncService.clearAll();
    } catch (e) {
      debugPrint('[UserProvider] clearAll Hive error: $e');
    }
    _user = UserModel.guest();
    _isAuthenticated = false;
    notifyListeners();
  }
}
