// lib/widgets/shell.dart
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// read role + root navigator
import '../features/auth/auth_providers.dart';
import '../router/app_router.dart'; // exposes navigatorKey

class AppShell extends ConsumerWidget {
  final Widget child;
  final Widget? fab;
  final int alertsCount;
  final bool showProfileDot;
  final VoidCallback? onLogout;

  const AppShell({
    super.key,
    required this.child,
    this.fab,
    this.alertsCount = 0,
    this.showProfileDot = false,
    this.onLogout,
  });

  static const _routes = ['/', '/alerts', '/profile', '/admin'];

  int _indexFromLocation(String loc) {
    final p = Uri.parse(loc).path;
    if (p.startsWith('/alerts')) return 1;
    if (p.startsWith('/profile')) return 2;
    if (p.startsWith('/admin')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _indexFromLocation(loc);
    final cs = Theme.of(context).colorScheme;
    final isHome = idx == 0;

    return Scaffold(
      // Drawer
      drawer: _AppDrawer(
        selectedIndex: idx,
        alertsCount: alertsCount,
        showProfileDot: showProfileDot,
        isAdmin: isAdmin,
        onNavigate: (drawerCtx, route) {
          // 1) close the drawer now (using drawer's context)
          Navigator.of(drawerCtx).pop();

          // 2) navigate next frame from the ROOT context
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final rootCtx = navigatorKey.currentContext;
            if (rootCtx == null) return;

            // Skip if already on that route
            final current = GoRouterState.of(rootCtx).uri.toString();
            if (current == route) return;

            // Most robust across go_router versions:
            rootCtx.go(route);
          });
        },
        onLogout: onLogout,
      ),

      // Body
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: child,
      ),

      // FAB only on Home
      floatingActionButton: isHome ? fab : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      drawerScrimColor: cs.scrim.withOpacity(.32),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final int alertsCount;
  final bool showProfileDot;
  final bool isAdmin;

  // NEW: pass the drawer's own BuildContext to the navigator
  final void Function(BuildContext drawerContext, String route) onNavigate;
  final VoidCallback? onLogout;

  const _AppDrawer({
    required this.selectedIndex,
    required this.alertsCount,
    required this.showProfileDot,
    required this.isAdmin,
    required this.onNavigate,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header w/ logo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  ClipRRect(
                    child: Image.asset(
                      'assets/logo.png',
                      height: 44,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerTile(
                    icon: Icons.home,
                    label: 'Home',
                    selected: selectedIndex == 0,
                    dot: showProfileDot,
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final rootCtx = navigatorKey.currentContext;
                        if (rootCtx != null) rootCtx.go('/');
                      });
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.notifications,
                    label: 'Alerts',
                    selected: selectedIndex == 1,
                    dot: showProfileDot,
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final rootCtx = navigatorKey.currentContext;
                        if (rootCtx != null) rootCtx.go('/alerts');
                      });
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    selected: selectedIndex == 2,
                    dot: showProfileDot,
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final rootCtx = navigatorKey.currentContext;
                        if (rootCtx != null) rootCtx.go('/profile');
                      });
                    },
                  ),

                  // Only for admins
                  if (isAdmin)
                    _DrawerTile(
                      icon: Icons.admin_panel_settings,
                      label: 'Admin',
                      selected: selectedIndex == 3,
                      dot: showProfileDot,
                      onTap: () {
                        Navigator.of(context).pop(); // close drawer
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final rootCtx = navigatorKey.currentContext;
                          if (rootCtx != null) rootCtx.go('/admin');
                        });
                      },
                    ),
                ],
              ),
            ),

            if (onLogout != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.of(context).maybePop(); // close drawer
                  onLogout!.call(); // then perform logout
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final String? badge;
  final bool dot;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
          if (dot)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? cs.primary : null,
        ),
      ),
      trailing: (badge != null)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      selected: selected,
      selectedTileColor: cs.primary.withOpacity(.07),
      onTap: onTap,
    );
  }
}
