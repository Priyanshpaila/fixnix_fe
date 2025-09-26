import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'push/notifications.dart';
import 'router/app_router.dart';
import 'features/auth/auth_providers.dart';
import 'ui/theme.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: FixnixApp()));
}

class FixnixApp extends ConsumerWidget {
  const FixnixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) hydrate session
    final init = ref.watch(sessionInitProvider);

    if (init.isLoading) {
      // lightweight splash while we load tokens from storage
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FIXNIX',
        theme: buildAppTheme(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // 2) build router & deep link glue
    final router = buildRouter(ref);
    AppNav.goToTicket = (id) => navigatorKey.currentContext?.go('/ticket/$id');

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FIXNIX',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
