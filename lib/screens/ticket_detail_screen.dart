// lib/screens/ticket_detail_screen.dart
// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/tickets/tickets_repository.dart';
import '../widgets/chips.dart';
import '../ui/tokens.dart';
import '../core/api_client.dart'; // for api.dio

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  late Future<Ticket> _ticketFut;
  late Future<List<_Comment>> _commentsFut;

  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _descExpanded = ValueNotifier<bool>(false);

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  void _reloadAll() {
    _ticketFut = ref.read(ticketsRepoProvider).getById(widget.ticketId);
    _commentsFut = _fetchComments();
    setState(() {});
  }

  Future<List<_Comment>> _fetchComments() async {
    final res = await api.dio.get('/api/comments/${widget.ticketId}');
    final list = (res.data as List? ?? [])
        .map((j) => _Comment.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    return list;
  }

  Future<void> _updateStatus(String status) async {
    final ctx = context;
    try {
      await api.dio.post(
        '/api/tickets/${widget.ticketId}/status',
        data: {'status': status},
      );
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Status updated: $status'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
      _reloadAll();
      ref.invalidate(ticketsListProvider);
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
    }
  }

  Future<void> _sendComment() async {
    final ctx = context;
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Write a comment first'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await api.dio.post(
        '/api/comments',
        data: {'ticketId': widget.ticketId, 'body': body, 'isInternal': false},
      );
      _commentCtrl.clear();
      _commentsFut = _fetchComments();
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Could not add comment: $e'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    _descExpanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withOpacity(.05),
              cs.secondary.withOpacity(.04),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: 'Ticket',
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                onRefresh: _reloadAll,
              ),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: () async => _reloadAll(),
                  child: FutureBuilder<Ticket>(
                    future: _ticketFut,
                    builder: (ctx, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError || !snap.hasData) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(Fx.l),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ticket not found',
                                  style: TextStyle(color: cs.outline),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: _reloadAll,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final t = snap.data!;
                      final description =
                          t.description.trim().isNotEmpty == true
                          ? t.description.trim()
                          : 'No description provided.';

                      return ListView(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(
                          Fx.l,
                          Fx.m,
                          Fx.l,
                          Fx.l,
                        ),
                        children: [
                          _HeaderCard(t: t),
                          const SizedBox(height: Fx.l),

                          // Details grid (ID, timestamps, assignee, queue, requester)
                          _Section(
                            title: 'Details',
                            trailing: IconButton(
                              tooltip: 'Copy ticket ID',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: t.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ticket ID copied'),
                                    behavior: SnackBarBehavior.floating,
                                    showCloseIcon: true,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                            ),
                            child: _MetaGrid(t: t),
                          ),
                          const SizedBox(height: Fx.l),

                          // Description (collapsible)
                          _Section(
                            title: 'Description',
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _descExpanded,
                              builder: (_, expanded, __) {
                                final text = Text(
                                  description,
                                  maxLines: expanded ? null : 6,
                                  overflow: expanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    text,
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _descExpanded.value = !expanded,
                                      icon: Icon(
                                        expanded
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                      ),
                                      label: Text(
                                        expanded ? 'Show less' : 'Show more',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: Fx.l),

                          // Quick actions
                          _ActionBar(
                            onWait: () => _updateStatus('waiting_customer'),
                            onProgress: () => _updateStatus('in_progress'),
                            onResolve: () => _updateStatus('resolved'),
                          ),
                          const SizedBox(height: Fx.l),

                          // Comments
                          _Section(
                            title: 'Comments',
                            child: Column(
                              children: [
                                FutureBuilder<List<_Comment>>(
                                  future: _commentsFut,
                                  builder: (ctx, csnap) {
                                    if (csnap.connectionState !=
                                        ConnectionState.done) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 24,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    final items =
                                        csnap.data ?? const <_Comment>[];
                                    if (items.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          'No comments yet',
                                          style: TextStyle(color: cs.outline),
                                        ),
                                      );
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            '${items.length} ${items.length == 1 ? 'comment' : 'comments'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        ListView.separated(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          shrinkWrap: true,
                                          itemCount: items.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (_, i) =>
                                              _CommentTile(c: items[i]),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: Fx.l),
                                _Composer(
                                  controller: _commentCtrl,
                                  sending: _sending,
                                  onSend: _sendComment,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------- Top Bar ---------- */

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Fx.l, Fx.l, Fx.l, Fx.m),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: cs.surface,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
            ),
          ),
          const SizedBox(width: Fx.m),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: cs.surface,
              child: IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------- Header Card ---------- */

class _HeaderCard extends StatelessWidget {
  final Ticket t;
  const _HeaderCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NumberBadge(number: t.number),
              const SizedBox(width: Fx.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusChip(t.status),
                        PriorityChip(t.priority),
                      ],
                    ),
                  ],
                ),
              ),
              // Optional more/menu
              const SizedBox(width: Fx.s),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  const _NumberBadge({required this.number});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

/* ---------- Meta grid ---------- */

class _MetaGrid extends StatelessWidget {
  final Ticket t;
  const _MetaGrid({required this.t});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtle = TextStyle(color: cs.outline);

    // Safe field access with defaults
    final created = t.createdAt;
    final updated = t.updatedAt;

    final items = <_MetaItem>[
      _MetaItem(
        icon: Icons.confirmation_number_outlined,
        label: 'ID',
        value: t.id,
      ),
      _MetaItem(
        icon: Icons.flag_outlined,
        label: 'Priority',
        value: t.priority,
      ),
      _MetaItem(
        icon: Icons.schedule_rounded,
        label: 'Created',
        value: _ago(created),
      ),
      _MetaItem(
        icon: Icons.update_rounded,
        label: 'Updated',
        value: _ago(updated),
      ),
      _MetaItem(
        icon: Icons.info_outline_rounded,
        label: 'Status',
        value: t.status,
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 760 ? 3 : (box.maxWidth >= 520 ? 2 : 1);
        final gap = 16.0;
        final width = (box.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: 10,
          children: items.map((m) {
            return SizedBox(
              width: width,
              child: Row(
                children: [
                  Icon(m.icon, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: subtle,
                        children: [
                          TextSpan(
                            text: '${m.label}: ',
                            style: subtle.copyWith(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: m.value),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _MetaItem {
  final IconData icon;
  final String label;
  final String value;
  _MetaItem({required this.icon, required this.label, required this.value});
}

/* ---------- Action Bar (responsive) ---------- */

class _ActionBar extends StatelessWidget {
  final VoidCallback onWait;
  final VoidCallback onProgress;
  final VoidCallback onResolve;

  const _ActionBar({
    required this.onWait,
    required this.onProgress,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final wait = OutlinedButton.icon(
      icon: const Icon(Icons.hourglass_empty_rounded),
      onPressed: onWait,
      label: const Text('Wait Customer'),
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );

    final progress = FilledButton.tonalIcon(
      icon: const Icon(Icons.play_circle_outline),
      onPressed: onProgress,
      label: const Text('In Progress'),
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );

    final resolve = FilledButton.icon(
      icon: const Icon(Icons.check_circle_rounded),
      onPressed: onResolve,
      label: const Text('Resolve'),
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
        backgroundColor: WidgetStateProperty.all(cs.primary),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 640;
        return _GlassCard(
          child: narrow
              ? Column(
                  children: [
                    wait,
                    const SizedBox(height: 10),
                    progress,
                    const SizedBox(height: 10),
                    resolve,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: wait),
                    const SizedBox(width: 12),
                    Expanded(child: progress),
                    const SizedBox(width: 12),
                    Expanded(child: resolve),
                  ],
                ),
        );
      },
    );
  }
}

/* ---------- Comments ---------- */

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                prefixIcon: const Icon(Icons.mode_comment_outlined),
                fillColor: cs.surface,
                filled: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(const Size(52, 48)),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: Fx.m),
          child,
        ],
      ),
    );
  }
}

/* ---------- Shared Glass Card ---------- */

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Fx.l),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(Fx.rMd),
        boxShadow: Fx.cardShadow(Colors.black),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

/* ---------- Comments model & tile ---------- */

class _Comment {
  final String id;
  final String body;
  final String authorName;
  final bool isInternal;
  final DateTime createdAt;

  _Comment({
    required this.id,
    required this.body,
    required this.authorName,
    required this.isInternal,
    required this.createdAt,
  });

  factory _Comment.fromJson(Map<String, dynamic> j) => _Comment(
    id: (j['_id'] ?? j['id'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    authorName: (j['authorName'] ?? j['author'] ?? 'Agent') as String,
    isInternal: (j['isInternal'] ?? false) as bool,
    createdAt:
        DateTime.tryParse((j['createdAt'] ?? '') as String) ?? DateTime.now(),
  );
}

class _CommentTile extends StatelessWidget {
  final _Comment c;
  const _CommentTile({required this.c});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: cs.primaryContainer,
          child: Text(
            (c.authorName.isNotEmpty ? c.authorName[0] : '?').toUpperCase(),
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: Fx.m),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.isInternal ? cs.surfaceContainerHighest : cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      c.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      c.isInternal
                          ? Icons.lock_outline_rounded
                          : Icons.public_rounded,
                      size: 14,
                      color: cs.outline,
                    ),
                    Text(
                      _formatAgo(c.createdAt),
                      style: TextStyle(color: cs.outline, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(c.body),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
