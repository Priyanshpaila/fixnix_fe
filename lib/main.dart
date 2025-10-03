// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'push/notifications.dart';
import 'router/app_router.dart';
import 'features/auth/auth_providers.dart';
import 'ui/theme.dart'; // <-- dynamic theme (seed + providers)
import 'firebase_options.dart';

// (optional but recommended for Flutter Web pretty URLs)
import 'package:flutter_web_plugins/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web: make URLs path-based (/admin) instead of hash (#/admin)
  if (kIsWeb) {
    usePathUrlStrategy(); // requires <base href="/"> in web/index.html
  }

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
    // hydrate session from secure storage
    final sessionInit = ref.watch(sessionInitProvider);
    // hydrate theme seed from secure storage
    final themeInit = ref.watch(themeInitProvider);

    // build router once; GoRouter will handle /admin, redirects, etc.
    final router = buildRouter(ref);
    // allow other places to deep-link to tickets
    AppNav.goToTicket = (id) => navigatorKey.currentContext?.go('/ticket/$id');

    // current seed color for the app (changes live when user picks new color)
    final seed = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FIXNIX',
      theme: buildAppTheme(seed), // <-- apply user-selected seed color
      routerConfig: router,

      // Overlay a lightweight splash while initializers run,
      // but keep router active so deep links like /admin still work.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final loading = sessionInit.isLoading || themeInit.isLoading;
        return Stack(children: [child, if (loading) const _SplashOverlay()]);
      },
    );
  }
}

class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
