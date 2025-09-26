import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authRepoProvider = Provider((_) => AuthRepository());

// Holds signed-in userId (null if logged out)
final sessionProvider = StateProvider<String?>((_) => null);

// ✅ Hydrate session from secure storage on app start
final sessionInitProvider = FutureProvider<void>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final userId = await storage.read(key: 'user_id');
  if (token != null && token.isNotEmpty && userId != null && userId.isNotEmpty) {
    ref.read(sessionProvider.notifier).state = userId;
  }
});
