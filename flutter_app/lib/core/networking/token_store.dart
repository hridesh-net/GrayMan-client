import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors iOS TokenStore — JWT in secure storage, worker ID in prefs.
class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  static const _jwtKey = 'jwt';
  static const _workerIdKey = 'grayman.workerID';
  final _secure = const FlutterSecureStorage();

  String? _cached;

  String? get token => _cached;
  String? workerId;

  Future<void> load() async {
    _cached = await _secure.read(key: _jwtKey);
    final prefs = await SharedPreferences.getInstance();
    workerId = prefs.getString(_workerIdKey);
  }

  Future<void> save(String token, {String? workerId}) async {
    _cached = token;
    await _secure.write(key: _jwtKey, value: token);
    if (workerId != null) {
      this.workerId = workerId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_workerIdKey, workerId);
    }
  }

  Future<void> clear() async {
    _cached = null;
    workerId = null;
    await _secure.delete(key: _jwtKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_workerIdKey);
  }
}
