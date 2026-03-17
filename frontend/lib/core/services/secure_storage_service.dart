// SEC #1: wrapper sobre flutter_secure_storage para dados sensíveis (JWT, user_data)
// Substitui SharedPreferences para tokens e claims do usuário.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _jwtKey = 'jwt_token_secure';
  static const _userDataKey = 'user_data_secure';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // AES-256 via Keystore
    ),
  );

  Future<void> writeToken(String token) =>
      _storage.write(key: _jwtKey, value: token);

  Future<String?> readToken() => _storage.read(key: _jwtKey);

  Future<void> deleteToken() => _storage.delete(key: _jwtKey);

  Future<void> writeUserData(String json) =>
      _storage.write(key: _userDataKey, value: json);

  Future<String?> readUserData() => _storage.read(key: _userDataKey);

  Future<void> deleteUserData() => _storage.delete(key: _userDataKey);

  Future<void> clearAll() => _storage.deleteAll();
}
