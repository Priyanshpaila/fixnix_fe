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
  final _searchNode = FocusNode();

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
  void dispose() {
    _search.dispose();
    _searchNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketsListProvider);
    final cs = Theme.of(context).colorScheme;

    return AppShell(
      onLogout: _logout,
      alertsCount: ref.watch(unreadAlertsCountProvider),
      fab: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
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
                // ---------- AppBar ----------
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  snap: true,
                  leading: Builder(
                    builder: (ctx) => IconButton(
                      tooltip: 'Menu',
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  title: const Text('Tickets'),
                  actions: [
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _reload,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(96),
                    child: Column(
                      children: [
                        // Search field in app bar bottom
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Fx.l,
                            0,
                            Fx.l,
                            Fx.s,
                          ),
                          child: Semantics(
                            label: 'Search tickets',
                            child: TextField(
                              controller: _search,
                              focusNode: _searchNode,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) =>
                                  ref.refresh(ticketsListProvider),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search tickets by title or #…',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _search.text.isNotEmpty
                                    ? IconButton(
                                        tooltip: 'Clear',
                                        onPressed: () {
                                          _search.clear();
                                          setState(() {});
                                          _searchNode.requestFocus();
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),

                        // Filters row — horizontally scrollable
                        SizedBox(
                          height: 44,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Fx.l,
                            ),
                            scrollDirection: Axis.horizontal,
                            children: [
                              _FilterChip(
                                label: 'All status',
                                selected: _statusFilter == 'all',
                                onTap: () =>
                                    setState(() => _statusFilter = 'all'),
                              ),
                              _FilterChip(
                                label: 'In progress',
                                selected: _statusFilter == 'in_progress',
                                onTap: () => setState(
                                  () => _statusFilter = 'in_progress',
                                ),
                              ),
                              _FilterChip(
                                label: 'Resolved',
                                selected: _statusFilter == 'resolved',
                                onTap: () =>
                                    setState(() => _statusFilter = 'resolved'),
                              ),
                              // Divider dot
                              _Dot(color: cs.outlineVariant),
                              _FilterChip(
                                label: 'All priority',
                                selected: _priorityFilter == 'all',
                                onTap: () =>
                                    setState(() => _priorityFilter = 'all'),
                              ),
                              _FilterChip(
                                label: 'P1',
                                selected: _priorityFilter == 'P1',
                                onTap: () =>
                                    setState(() => _priorityFilter = 'P1'),
                              ),
                              _FilterChip(
                                label: 'P2',
                                selected: _priorityFilter == 'P2',
                                onTap: () =>
                                    setState(() => _priorityFilter = 'P2'),
                              ),
                              _FilterChip(
                                label: 'P3',
                                selected: _priorityFilter == 'P3',
                                onTap: () =>
                                    setState(() => _priorityFilter = 'P3'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Fx.s),
                      ],
                    ),
                  ),
                ),

                // ---------- Body ----------
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

                    final cs = Theme.of(context).colorScheme;

                    // Summary row widget (box)
                    Widget summaryRow(int total) => Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Fx.l,
                        Fx.s,
                        Fx.l,
                        Fx.s,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.confirmation_num_outlined,
                            size: 18,
                            color: cs.outline,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$total ticket${total == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: cs.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );

                    // Empty state (single sliver)
                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Column(
                          children: [
                            summaryRow(0),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * .45,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inbox_rounded,
                                      size: 56,
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
                          ],
                        ),
                      );
                    }

                    // WIDE: summary + grid in one SliverToBoxAdapter (box world)
                    final isWide = MediaQuery.of(context).size.width >= 900;
                    final isTablet =
                        MediaQuery.of(context).size.width >= 600 &&
                        MediaQuery.of(context).size.width < 900;

                    if (isWide) {
                      final cross = (MediaQuery.of(context).size.width >= 1200)
                          ? 3
                          : 2;

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          Fx.l,
                          Fx.s,
                          Fx.l,
                          Fx.l,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summaryRow(filtered.length),
                              const SizedBox(height: Fx.s),
                              // Use a shrink-wrapped GridView to stay in box layout.
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cross,
                                      mainAxisSpacing: Fx.m,
                                      crossAxisSpacing: Fx.m,
                                      childAspectRatio: isTablet ? 2.7 : 2.6,
                                    ),
                                itemBuilder: (_, i) => TicketCard(
                                  t: filtered[i],
                                  onTap: () => navigatorKey.currentContext?.go(
                                    '/ticket/${filtered[i].id}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // NARROW: single SliverList.separated with summary as first row
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Fx.l,
                        Fx.s,
                        Fx.l,
                        Fx.l,
                      ),
                      sliver: SliverList.separated(
                        itemCount: filtered.length + 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: Fx.m),
                        itemBuilder: (_, index) {
                          if (index == 0) {
                            // summary row
                            return summaryRow(filtered.length);
                          }
                          final i = index - 1;
                          return TicketCard(
                            t: filtered[i],
                            onTap: () => navigatorKey.currentContext?.go(
                              '/ticket/${filtered[i].id}',
                            ),
                          );
                        },
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
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(height: 8),
                            Text('Error: $e'),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
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
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
