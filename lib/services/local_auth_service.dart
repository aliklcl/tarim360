import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthSession {
  const LocalAuthSession({
    required this.username,
  });

  final String username;
}

class LocalAuthService {
  LocalAuthService._();

  static const _usersKey = 'local_auth_users_v1';
  static const _activeUserKey = 'local_auth_active_user_v1';
  static const _pbkdf2Iterations = 120000;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<List<Map<String, String>>> _readUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.trim().isEmpty) return <Map<String, String>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, String>>[];
      return decoded
          .whereType<Map>()
          .map(
            (e) => {
              'username': '${e['username'] ?? ''}',
              'passwordHash': '${e['passwordHash'] ?? ''}',
              'salt': '${e['salt'] ?? ''}',
              'iterations': '${e['iterations'] ?? _pbkdf2Iterations}',
            },
          )
          .where((e) => e['username']!.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return <Map<String, String>>[];
    }
  }

  static Future<void> _writeUsers(List<Map<String, String>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  static String _rastgeleSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  static String _hashPassword(
    String password, {
    required String salt,
    int iterations = _pbkdf2Iterations,
  }) {
    final pass = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    var block = Hmac(sha256, pass).convert(saltBytes).bytes;
    var result = List<int>.from(block);
    for (var i = 1; i < iterations; i++) {
      block = Hmac(sha256, pass).convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return base64Encode(result);
  }

  static Future<LocalAuthSession> register({
    required String username,
    required String password,
  }) async {
    final user = username.trim();
    if (user.isEmpty || password.trim().isEmpty) {
      throw Exception('Kullanici adi ve sifre bos olamaz');
    }
    final users = await _readUsers();
    if (users.any((e) => e['username']!.toLowerCase() == user.toLowerCase())) {
      throw Exception('Bu kullanici adi zaten kayitli');
    }
    final salt = _rastgeleSalt();
    users.add({
      'username': user,
      'salt': salt,
      'iterations': '$_pbkdf2Iterations',
      'passwordHash': _hashPassword(
        password,
        salt: salt,
        iterations: _pbkdf2Iterations,
      ),
    });
    await _writeUsers(users);
    await _secureStorage.write(key: _activeUserKey, value: user);
    return LocalAuthSession(username: user);
  }

  static Future<LocalAuthSession> signIn({
    required String username,
    required String password,
  }) async {
    final user = username.trim();
    final users = await _readUsers();
    final existing = users.where(
      (e) => e['username']!.toLowerCase() == user.toLowerCase(),
    );
    if (existing.isEmpty) {
      throw Exception('Kullanici adi veya sifre hatali');
    }
    final kayit = existing.first;
    final salt = kayit['salt']?.trim();
    final iterations = int.tryParse(kayit['iterations'] ?? '') ?? _pbkdf2Iterations;
    final beklenenHash = kayit['passwordHash'] ?? '';
    final legacyHash = sha256.convert(utf8.encode(password)).toString();
    final passHash = _hashPassword(
      password,
      salt: (salt == null || salt.isEmpty) ? user.toLowerCase() : salt,
      iterations: iterations,
    );
    if (beklenenHash != passHash && beklenenHash != legacyHash) {
      throw Exception('Kullanici adi veya sifre hatali');
    }
    if (beklenenHash == legacyHash) {
      final yeniSalt = _rastgeleSalt();
      kayit['salt'] = yeniSalt;
      kayit['iterations'] = '$_pbkdf2Iterations';
      kayit['passwordHash'] = _hashPassword(
        password,
        salt: yeniSalt,
        iterations: _pbkdf2Iterations,
      );
      await _writeUsers(users);
    }
    await _secureStorage.write(key: _activeUserKey, value: existing.first['username']!);
    return LocalAuthSession(username: existing.first['username']!);
  }

  static Future<LocalAuthSession?> activeSession() async {
    final activeUser = await _secureStorage.read(key: _activeUserKey);
    if (activeUser == null || activeUser.trim().isEmpty) return null;
    final users = await _readUsers();
    final exists = users.any(
      (e) => e['username']!.toLowerCase() == activeUser.trim().toLowerCase(),
    );
    if (!exists) return null;
    return LocalAuthSession(username: activeUser.trim());
  }

  static Future<void> signOut() async {
    await _secureStorage.delete(key: _activeUserKey);
  }
}
