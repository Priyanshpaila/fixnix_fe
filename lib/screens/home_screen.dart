// lib/screens/home_screen.dart
// ignore_for_file: unused_field, body_might_complete_normally_catch_error

import 'package:fixnix_app/screens/alerts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../features/tickets/tickets_repository.dart';
import '../features/auth/auth_providers.dart';
import '../router/app_router.dart';
import '../widgets/ticket_card.dart';
import '../ui/tokens.dart';
import '../widgets/shell.dart';
import '../core/api_client.dart'; // for `api` and `secure`

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  bool _refreshing = false;
  String _statusFilter = 'all';
  String _priorityFilter = 'all';

  Future<void> _reload() async {
    setState(() => _refreshing = true);
    ref.invalidate(ticketsListProvider);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _logout() async {
    final ctx = context;
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will stop receiving ticket notifications on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final fcm = await FirebaseMessaging.instance.getToken();
      if (fcm != null) {
        await api.dio
            .post('/api/users/devices/unregister', data: {'token': fcm})
            .catchError((_) {});
      }
      await secure.deleteAll();
      ref.read(sessionProvider.notifier).state = null;

      if (!mounted) return;
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Signed out'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
      navigatorKey.currentContext?.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Could not sign out: $e'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketsListProvider);
    final cs = Theme.of(context).colorScheme;

    return AppShell(
      // We keep FAB only from AppShell (no extra AppBar here)
      onLogout: _logout,
      alertsCount: ref.watch(unreadAlertsCountProvider),
      fab: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
        onPressed: () async {
          final created = await context.push<bool>('/ticket/new');
          if (created == true) _reload();
        },
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final isWide = box.maxWidth >= 900; // switch to grid
          final isTablet = box.maxWidth >= 600 && box.maxWidth < 900;

          return RefreshIndicator.adaptive(
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ---- Page Header (no extra AppBar) ----
                // in HomeScreen build(), replace the header SliverToBoxAdapter with this:
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Fx.l, Fx.l, Fx.l, Fx.s),
                    child: Row(
                      children: [
                        // Drawer button (since no AppBar)
                        Builder(
                          builder: (ctx) => IconButton.filledTonal(
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                            icon: const Icon(Icons.menu_rounded),
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            tooltip: 'Menu',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Tickets',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          tooltip: 'Refresh',
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Sign out',
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ---- Search ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Fx.l),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}), // live filter
                      onSubmitted: (_) => ref.refresh(ticketsListProvider),
                      decoration: InputDecoration(
                        hintText: 'Search tickets by title or #…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: (_search.text.isNotEmpty)
                            ? IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: Fx.m)),

                // ---- Filters (responsive row) ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Fx.l),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Status group
                        _FilterChip(
                          label: 'All status',
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        _FilterChip(
                          label: 'In progress',
                          selected: _statusFilter == 'in_progress',
                          onTap: () =>
                              setState(() => _statusFilter = 'in_progress'),
                        ),
                        _FilterChip(
                          label: 'Resolved',
                          selected: _statusFilter == 'resolved',
                          onTap: () =>
                              setState(() => _statusFilter = 'resolved'),
                        ),
                        // Spacer dot
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: cs.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Priority group
                        _FilterChip(
                          label: 'All priority',
                          selected: _priorityFilter == 'all',
                          onTap: () => setState(() => _priorityFilter = 'all'),
                        ),
                        _FilterChip(
                          label: 'P1',
                          selected: _priorityFilter == 'P1',
                          onTap: () => setState(() => _priorityFilter = 'P1'),
                        ),
                        _FilterChip(
                          label: 'P2',
                          selected: _priorityFilter == 'P2',
                          onTap: () => setState(() => _priorityFilter = 'P2'),
                        ),
                        _FilterChip(
                          label: 'P3',
                          selected: _priorityFilter == 'P3',
                          onTap: () => setState(() => _priorityFilter = 'P3'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: Fx.l)),

                // ---- List / Grid ----
                ticketsAsync.when<Widget>(
                  data: (items) {
                    final q = _search.text.trim().toLowerCase();
                    final filtered = items.where((t) {
                      final sOk =
                          _statusFilter == 'all' || t.status == _statusFilter;
                      final pOk =
                          _priorityFilter == 'all' ||
                          t.priority == _priorityFilter;
                      final qOk =
                          q.isEmpty ||
                          t.title.toLowerCase().contains(q) ||
                          t.number.toString() == q;
                      return sOk && pOk && qOk;
                    }).toList();

                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * .45,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inbox_rounded,
                                  size: 48,
                                  color: cs.outline,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No tickets found',
                                  style: TextStyle(color: cs.outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    if (isWide) {
                      // Responsive grid on large screens
                      final cross = (box.maxWidth >= 1200)
                          ? 3
                          : (box.maxWidth >= 900)
                          ? 2
                          : 1;
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: Fx.l),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => TicketCard(
                              t: filtered[i],
                              onTap: () => navigatorKey.currentContext?.go(
                                '/ticket/${filtered[i].id}',
                              ),
                            ),
                            childCount: filtered.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                mainAxisSpacing: Fx.m,
                                crossAxisSpacing: Fx.m,
                                childAspectRatio: isTablet ? 2.7 : 2.6,
                              ),
                        ),
                      );
                    }

                    // Simple separated list on phones/tablets
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: Fx.l),
                      sliver: SliverList.separated(
                        itemBuilder: (_, i) => TicketCard(
                          t: filtered[i],
                          onTap: () => navigatorKey.currentContext?.go(
                            '/ticket/${filtered[i].id}',
                          ),
                        ),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: Fx.m),
                        itemCount: filtered.length,
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * .45,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * .45,
                      child: Center(child: Text('Error: $e')),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ---------- Pretty Filter Chip ---------- */
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? cs.onPrimary : cs.onSurface,
      ),
      selectedColor: cs.primary,
      backgroundColor: cs.surface,
      side: BorderSide(color: cs.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
