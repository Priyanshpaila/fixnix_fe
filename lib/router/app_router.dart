import 'package:fixnix_app/screens/alerts_screen.dart';
import 'package:fixnix_app/screens/create_ticket_screen.dart';
import 'package:fixnix_app/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_providers.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/ticket_detail_screen.dart';
import '../screens/admin_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      // ADMIN (role-gated)
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(
        path: '/ticket/new',
        builder: (_, __) => const CreateTicketScreen(),
      ),
      GoRoute(
        path: '/ticket/:id([0-9a-fA-F]{24})',
        builder: (_, s) =>
            TicketDetailScreen(ticketId: s.pathParameters['id']!),
      ),
    ],
    redirect: (ctx, state) {
      final loggedIn = ref.read(sessionProvider) != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/';
      // gate admin route
      if (state.matchedLocation.startsWith('/admin')) {
        final isAdmin = ref.read(isAdminProvider);
        if (!isAdmin) return '/login';
      }
      return null;
    },
  );
}
