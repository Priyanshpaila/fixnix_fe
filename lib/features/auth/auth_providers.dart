import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api_client.dart';

final authRepoProvider = Provider((_) => AuthRepository());

// Holds signed-in userId (null if logged out)
final sessionProvider = StateProvider<String?>((_) => null);

// ✅ Hydrate session from secure storage on app start
final sessionInitProvider = FutureProvider<void>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final userId = await storage.read(key: 'user_id');
  if (token != null &&
      token.isNotEmpty &&
      userId != null &&
      userId.isNotEmpty) {
    ref.read(sessionProvider.notifier).state = userId;
  }
});

/// Fetch current user profile (id, email, role, …)
final meProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final res = await api.dio.get('/api/users/me');
  return (res.data is Map) ? Map<String, dynamic>.from(res.data) : null;
});

/// Is admin?
final isAdminProvider = Provider<bool>((ref) {
  final me = ref
      .watch(meProvider)
      .maybeWhen(data: (u) => u, orElse: () => null);
  final role = (me?['role'] ?? '').toString().toLowerCase();
  return role == 'admin' || role == 'superadmin';
});
