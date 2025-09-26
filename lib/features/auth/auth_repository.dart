import '../../core/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  final _storage = const FlutterSecureStorage();

  Future<void> register(String name, String email, String password) async {
    await api.dio.post('/api/auth/register', data: {
      'name': name, 'email': email, 'password': password
    });
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await api.dio.post('/api/auth/login', data: {
      'email': email, 'password': password
    });
    final token = res.data['token'] as String;
    final refresh = res.data['refreshToken'] as String?;
    final user = (res.data['user'] as Map).cast<String, dynamic>();

    await _storage.write(key: 'access_token', value: token);
    if (refresh != null) {
      await _storage.write(key: 'refresh_token', value: refresh);
    }
    await _storage.write(key: 'user_id', value: user['id'] as String);
    return user;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
