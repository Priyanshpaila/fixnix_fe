import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

final secure = const FlutterSecureStorage();

class ApiClient {
  final Dio _dio;

  ApiClient() : _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    headers: {'Content-Type': 'application/json'},
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secure.read(key: 'access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        // Attempt refresh on 401
        if (e.response?.statusCode == 401) {
          final refresh = await secure.read(key: 'refresh_token');
          if (refresh != null && refresh.isNotEmpty) {
            try {
              final r = await _dio.post('/api/auth/refresh', data: {'refreshToken': refresh});
              final newToken = r.data['token'] as String?;
              if (newToken != null) {
                await secure.write(key: 'access_token', value: newToken);
                e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                final clone = await _dio.fetch(e.requestOptions);
                return handler.resolve(clone);
              }
            } catch (_) {/* fall through */}
          }
        }
        handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}

final api = ApiClient();
