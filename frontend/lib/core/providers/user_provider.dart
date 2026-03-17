// SEC #1: JWT e user_data via SecureStorageService (AES-256 Keystore)
// SEC #2: valida campo 'exp' do JWT antes de autenticar
// SEC #5: login distingue AuthException de erros de rede
// SEC #6: updateProfile só executa se _isAuthenticated
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

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
    // SEC #1: lê do secure storage
    final userJson =
        await SecureStorageService.instance.readUserData();
    if (userJson != null && ApiService.instance.hasToken) {
      try {
        final claims =
            jsonDecode(userJson) as Map<String, dynamic>;
        // SEC #2: verifica expiração
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
    }
  }

  // SEC #5: distingue InvalidCredentials x Rede x Expirado
  Future<bool> login(String email, String password) async {
    _lastLoginError = LoginError.none;
    try {
      final res = await ApiService.instance.login(email, password);
      final token = res['access_token'] as String;
      await ApiService.instance.setToken(token);

      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])));
        final claims =
            jsonDecode(payload) as Map<String, dynamic>;

        // SEC #2: verifica exp antes de aceitar o token
        if (_isTokenExpired(claims)) {
          _lastLoginError = LoginError.sessionExpired;
          return false;
        }

        _user = UserModel.fromJwtClaims(claims);
        // SEC #1: salva no secure storage
        await SecureStorageService.instance
            .writeUserData(jsonEncode(claims));
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

  Future<void> logout() async {
    await _clearSession();
  }

  // SEC #6: guard isAuthenticated
  Future<void> updateProfile(String name, String company,
      {String? imageUrl}) async {
    if (!_isAuthenticated) {
      debugPrint('[UserProvider] updateProfile bloqueado: usuário não autenticado');
      return;
    }
    _user = UserModel(
      id: _user.id,
      name: name,
      company: company,
      role: _user.role,
      tenantId: _user.tenantId,
      profileImageUrl: imageUrl ?? _user.profileImageUrl,
    );
    notifyListeners();
    // SEC #1: persiste no secure storage
    await SecureStorageService.instance
        .writeUserData(jsonEncode(_user.toJson()));
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// SEC #2: retorna true se o campo 'exp' do JWT já passou
  bool _isTokenExpired(Map<String, dynamic> claims) {
    final exp = claims['exp'];
    if (exp == null) return false; // sem exp = sem validade definida
    final expiry =
        DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    return DateTime.now().isAfter(expiry);
  }

  Future<void> _clearSession() async {
    await ApiService.instance.clearToken();
    await SecureStorageService.instance.deleteUserData();
    _user = UserModel.guest();
    _isAuthenticated = false;
    notifyListeners();
  }
}
