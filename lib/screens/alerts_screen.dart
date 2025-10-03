// lib/screens/alerts_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import '../ui/tokens.dart';
import '../core/api_client.dart'; // optional server fetch (best-effort)

// ---------- Model ----------
class AlertItem {
  final String id; // local guid or server id
  final String title;
  final String body;
  final DateTime time;
  final bool read;
  final Map<String, dynamic> data;

  AlertItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
    this.data = const {},
  });

  AlertItem copyWith({bool? read}) => AlertItem(
    id: id,
    title: title,
    body: body,
    time: time,
    read: read ?? false,
    data: data,
  );
}

// ---------- State ----------
class AlertsState {
  final List<AlertItem> items;
  final bool loading;
  final String? error;
  const AlertsState({this.items = const [], this.loading = false, this.error});

  int get unread => items.where((e) => !e.read).length;

  AlertsState copy({List<AlertItem>? items, bool? loading, String? error}) =>
      AlertsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error,
      );
}

// ---------- Notifier ----------
class AlertsNotifier extends StateNotifier<AlertsState> {
  StreamSubscription<RemoteMessage>? _subOnMessage;
  StreamSubscription<RemoteMessage>? _subOnOpened;
  bool _initializedListen = false;

  AlertsNotifier() : super(const AlertsState());

  @override
  void dispose() {
    _subOnMessage?.cancel();
    _subOnOpened?.cancel();
    super.dispose();
  }

  // Attach FCM listeners once.
  Future<void> ensureListening(WidgetRef ref, BuildContext context) async {
    if (_initializedListen) return;
    _initializedListen = true;

    if (!kIsWeb) {
      // 1) Foreground messages
      _subOnMessage = FirebaseMessaging.onMessage.listen((m) {
        _insertFromMessage(m);
      });

      // 2) App opened from background by tapping a notification
      _subOnOpened = FirebaseMessaging.onMessageOpenedApp.listen((m) {
        _insertFromMessage(m);
        _maybeNavigateFromData(context, m.data);
      });

      // 3) App cold start from a notification
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _insertFromMessage(initial);
        _maybeNavigateFromData(context, initial.data);
      }
    }
  }

  // Best-effort server fetch (optional). If your API has /api/alerts, wire it here.
  Future<void> refresh() async {
    state = state.copy(loading: true, error: null);
    try {
      // If you have a real endpoint, replace this with:
      // final res = await api.dio.get('/api/alerts');
      // final items = (res.data as List).map(...).toList();
      // For now, make this a no-op that preserves current items.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      state = state.copy(loading: false);
    } catch (e) {
      state = state.copy(loading: false, error: 'Failed to load alerts');
    }
  }

  void _insertFromMessage(RemoteMessage m) {
    final title =
        m.notification?.title ?? m.data['title']?.toString() ?? 'Notification';
    final body = m.notification?.body ?? m.data['body']?.toString() ?? '';
    final data = Map<String, dynamic>.from(m.data);
    final id =
        (data['id']?.toString() ?? m.messageId ?? UniqueKey().toString());

    // de-dupe by id
    final existsIndex = state.items.indexWhere((it) => it.id == id);
    if (existsIndex >= 0) {
      final updated = [...state.items];
      updated[existsIndex] = updated[existsIndex].copyWith(read: false);
      state = state.copy(items: updated);
    } else {
      state = state.copy(
        items: [
          AlertItem(
            id: id,
            title: title,
            body: body,
            time: DateTime.now(),
            data: data,
          ),
          ...state.items,
        ],
      );
    }
  }

  void addDebugAlert({
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) {
    // Handy for manual testing on web/desktop
    state = state.copy(
      items: [
        AlertItem(
          id: UniqueKey().toString(),
          title: title ?? 'Test alert',
          body: body ?? 'This is a local test alert.',
          time: DateTime.now(),
          data: data ?? const {},
        ),
        ...state.items,
      ],
    );
  }

  void markRead(String id, {bool read = true}) {
    state = state.copy(
      items: state.items
          .map((e) => e.id == id ? e.copyWith(read: read) : e)
          .toList(),
    );
  }

  void markAllRead() {
    state = state.copy(
      items: state.items.map((e) => e.copyWith(read: true)).toList(),
    );
  }

  void remove(String id) {
    state = state.copy(items: state.items.where((e) => e.id != id).toList());
  }

  void clearAll() {
    state = state.copy(items: const []);
  }

  void _maybeNavigateFromData(BuildContext context, Map<String, dynamic> data) {
    final ticketId = data['ticketId']?.toString();
    if (ticketId != null && ticketId.isNotEmpty) {
      context.go('/ticket/$ticketId');
    }
  }
}

// ---------- Providers ----------
final alertsProvider = StateNotifierProvider<AlertsNotifier, AlertsState>(
  (_) => AlertsNotifier(),
);
final unreadAlertsCountProvider = Provider<int>(
  (ref) => ref.watch(alertsProvider).unread,
);

// ---------- UI ----------
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    // Kick a refresh so pull-to-refresh completes fast
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertsProvider);
    final notifier = ref.read(alertsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    // Ensure FCM listeners are attached
    notifier.ensureListening(ref, context);

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () => notifier.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Fx.l, Fx.l, Fx.l, Fx.s),
                child: Row(
                  children: [
                    // Back button (works for deep links too)
                    IconButton.filledTonal(
                      tooltip: 'Back',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/'); // fallback to home if no back stack
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: Fx.m),
                    Text(
                      'Alerts',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Tooltip(
                      message: 'Mark all read',
                      child: IconButton.filledTonal(
                        onPressed: state.items.isEmpty
                            ? null
                            : notifier.markAllRead,
                        icon: const Icon(Icons.done_all_rounded),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Clear all',
                      child: IconButton.filledTonal(
                        onPressed: state.items.isEmpty
                            ? null
                            : notifier.clearAll,
                        icon: const Icon(Icons.clear_all_rounded),
                      ),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Add test alert (web/dev)',
                        child: IconButton.filledTonal(
                          onPressed: () => notifier.addDebugAlert(
                            title: 'Debug ping',
                            body: 'This was generated locally.',
                          ),
                          icon: const Icon(Icons.bolt_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Content
            if (state.loading)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * .4,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              )
            else if (state.items.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * .45,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off_rounded,
                          size: 56,
                          color: cs.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nothing yet',
                          style: TextStyle(color: cs.outline),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Fx.l),
                sliver: SliverList.separated(
                  itemBuilder: (_, i) {
                    final a = state.items[i];
                    return Dismissible(
                      key: ValueKey(a.id),
                      direction: DismissDirection.horizontal,
                      background: _swipeBg(
                        cs,
                        left: true,
                        icon: Icons.delete_sweep_rounded,
                      ),
                      secondaryBackground: _swipeBg(
                        cs,
                        left: false,
                        icon: a.read ? Icons.markunread : Icons.mark_email_read,
                      ),

                      // Only dismiss (remove from the tree) when deleting.
                      // For read/unread toggle, handle it and return false so the tile stays.
                      confirmDismiss: (dir) async {
                        if (dir == DismissDirection.startToEnd) {
                          // Delete
                          notifier.remove(
                            a.id,
                          ); // remove from state immediately
                          return true; // allow Dismissible to animate away
                        } else {
                          // Toggle read/unread without removing the tile
                          notifier.markRead(a.id, read: !a.read);
                          // Optional tiny feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                a.read ? 'Marked as unread' : 'Marked as read',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(milliseconds: 1200),
                            ),
                          );
                          return false; // keep the tile in the list => no error
                        }
                      },

                      child: _AlertTile(
                        item: a,
                        onTap: () {
                          final ticketId = a.data['ticketId']?.toString();
                          if (ticketId != null && ticketId.isNotEmpty) {
                            context.go('/ticket/$ticketId');
                          }
                          notifier.markRead(a.id, read: true);
                        },
                        onMore: () async {
                          await showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => _AlertActionsSheet(
                              item: a,
                              onMarkRead: () =>
                                  notifier.markRead(a.id, read: true),
                              onMarkUnread: () =>
                                  notifier.markRead(a.id, read: false),
                              onDelete: () => notifier.remove(a.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: Fx.s),
                  itemCount: state.items.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Fx.l)),
          ],
        ),
      ),
    );
  }

  Widget _swipeBg(
    ColorScheme cs, {
    required bool left,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsetsDirectional.only(
        start: left ? Fx.l : 0,
        end: left ? 0 : Fx.l,
      ),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: left ? Colors.red.withOpacity(.12) : cs.primary.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: left ? Colors.red : cs.primary),
    );
  }
}

// ---------- Tiles & Sheets ----------
class _AlertTile extends StatelessWidget {
  final AlertItem item;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _AlertTile({
    required this.item,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtle = TextStyle(color: cs.outline);

    return Container(
      padding: const EdgeInsets.all(Fx.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: Fx.cardShadow(Colors.black),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dot for unread
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(
                item.read
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: item.read ? cs.onSurfaceVariant : cs.primary,
              ),
            ),
            const SizedBox(width: Fx.m),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                      color: item.read ? cs.onSurface : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: cs.outline),
                      const SizedBox(width: 4),
                      Text(
                        _ago(item.time),
                        style: subtle.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Fx.s),
            IconButton(
              onPressed: onMore,
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More',
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }
}

class _AlertActionsSheet extends StatelessWidget {
  final AlertItem item;
  final VoidCallback onMarkRead;
  final VoidCallback onMarkUnread;
  final VoidCallback onDelete;

  const _AlertActionsSheet({
    required this.item,
    required this.onMarkRead,
    required this.onMarkUnread,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Fx.l, 0, Fx.l, Fx.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.mark_email_read_rounded, color: cs.primary),
            title: const Text('Mark as read'),
            onTap: () {
              onMarkRead();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.markunread_rounded),
            title: const Text('Mark as unread'),
            onTap: () {
              onMarkUnread();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_rounded, color: Colors.red),
            title: const Text('Delete'),
            onTap: () {
              onDelete();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
