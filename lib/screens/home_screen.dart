// lib/screens/home_screen.dart
// ignore_for_file: unused_field, body_might_complete_normally_catch_error

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
      // 1) Unregister device token (best-effort)
      final fcm = await FirebaseMessaging.instance.getToken();
      if (fcm != null) {
        await api.dio
            .post('/api/users/devices/unregister', data: {'token': fcm})
            .catchError((_) {});
      }
      // 2) Clear secure storage (tokens & cached ids)
      await secure.deleteAll();
      // 3) Update app session and navigate
      ref.read(sessionProvider.notifier).state = null;

      if (mounted) {
        // show toast before navigate so it appears instantly
        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Signed out'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
        navigatorKey.currentContext?.go('/login');
      }
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
    final scheme = Theme.of(context).colorScheme;

    return AppShell(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Row(
              children: [
                const Text('FIXNIX'),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Tickets',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Sign out',
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: Fx.l),
            ],
          ),

          // Search + Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Fx.l),
              child: Column(
                children: [
                  // Search
                  TextField(
                    controller: _search,
                    onSubmitted: (_) => ref.refresh(ticketsListProvider),
                    decoration: const InputDecoration(
                      hintText: 'Search tickets…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: Fx.m),

                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All status'),
                          selected: _statusFilter != 'all',
                          onSelected: (v) =>
                              setState(() => _statusFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('In progress'),
                          selected: _statusFilter == 'in_progress',
                          onSelected: (v) =>
                              setState(() => _statusFilter = 'in_progress'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Resolved'),
                          selected: _statusFilter == 'resolved',
                          onSelected: (v) =>
                              setState(() => _statusFilter = 'resolved'),
                        ),
                        const SizedBox(width: 8),
                        const VerticalDivider(width: Fx.xl, thickness: 0),
                        FilterChip(
                          label: const Text('All priority'),
                          selected: _priorityFilter != 'all',
                          onSelected: (v) =>
                              setState(() => _priorityFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('P1'),
                          selected: _priorityFilter == 'P1',
                          onSelected: (v) =>
                              setState(() => _priorityFilter = 'P1'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('P2'),
                          selected: _priorityFilter == 'P2',
                          onSelected: (v) =>
                              setState(() => _priorityFilter = 'P2'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('P3'),
                          selected: _priorityFilter == 'P3',
                          onSelected: (v) =>
                              setState(() => _priorityFilter = 'P3'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Fx.l),
                ],
              ),
            ),
          ),

          // List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Fx.l),
            sliver: SliverToBoxAdapter(
              child: RefreshIndicator.adaptive(
                onRefresh: _reload,
                child: ticketsAsync.when(
                  data: (items) {
                    final filtered = items.where((t) {
                      final sOk =
                          _statusFilter == 'all' || t.status == _statusFilter;
                      final pOk =
                          _priorityFilter == 'all' ||
                          t.priority == _priorityFilter;
                      final q = _search.text.trim().toLowerCase();
                      final qOk =
                          q.isEmpty ||
                          t.title.toLowerCase().contains(q) ||
                          t.number.toString() == q;
                      return sOk && pOk && qOk;
                    }).toList();

                    if (filtered.isEmpty) {
                      return SizedBox(
                        height: MediaQuery.of(context).size.height * .5,
                        child: const Center(child: Text('No tickets yet')),
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (_, i) => TicketCard(
                        t: filtered[i],
                        onTap: () => navigatorKey.currentContext?.go(
                          '/ticket/${filtered[i].id}',
                        ),
                      ),
                      separatorBuilder: (_, __) => const SizedBox(height: Fx.m),
                      itemCount: filtered.length,
                    );
                  },
                  loading: () => SizedBox(
                    height: MediaQuery.of(context).size.height * .5,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SizedBox(
                    height: MediaQuery.of(context).size.height * .5,
                    child: Center(child: Text('Error: $e')),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
