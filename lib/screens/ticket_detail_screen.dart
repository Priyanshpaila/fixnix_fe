import 'package:flutter/material.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // no back stack (e.g., opened via deep link) → go home
              context.go('/');
            }
          },
        ),
        title: const Text('Ticket'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reloadAll,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => _reloadAll(),
        child: FutureBuilder<Ticket>(
          future: _ticketFut,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return const Center(child: Text('Ticket not found'));
            }
            final t = snap.data!;

            return ListView(
              padding: const EdgeInsets.all(Fx.l),
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(Fx.l),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Fx.rMd),
                    boxShadow: Fx.cardShadow(Colors.black),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              t.number.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: Fx.l),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
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
                        ],
                      ),
                      const SizedBox(height: Fx.m),
                      // (Optional metadata placeholder)
                      Row(
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 16,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ID: ${t.id}',
                            style: TextStyle(color: scheme.outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Fx.l),

                // Status actions
                Container(
                  padding: const EdgeInsets.all(Fx.l),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Fx.rMd),
                    boxShadow: Fx.cardShadow(Colors.black),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.hourglass_empty_rounded),
                          onPressed: () => _updateStatus('waiting_customer'),
                          label: const Text('Wait Customer'),
                        ),
                      ),
                      const SizedBox(width: Fx.m),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_circle_outline),
                          onPressed: () => _updateStatus('in_progress'),
                          label: const Text('In Progress'),
                        ),
                      ),
                      const SizedBox(width: Fx.m),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check_circle),
                          onPressed: () => _updateStatus('resolved'),
                          label: const Text('Resolve'),
                        ),
                      ),
                    ],
                  ),
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
                          if (csnap.connectionState != ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final items = csnap.data ?? const <_Comment>[];
                          if (items.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No comments yet',
                                style: TextStyle(color: scheme.outline),
                              ),
                            );
                          }
                          return ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 16),
                            itemBuilder: (_, i) {
                              final c = items[i];
                              return _CommentTile(c: c);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: Fx.l),

                      // Composer
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentCtrl,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Add a comment…',
                                prefixIcon: Icon(Icons.mode_comment_outlined),
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendComment(),
                            ),
                          ),
                          const SizedBox(width: Fx.m),
                          FilledButton.icon(
                            onPressed: _sending ? null : _sendComment,
                            icon: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(_sending ? 'Sending…' : 'Send'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Fx.l),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Fx.rMd),
        boxShadow: Fx.cardShadow(Colors.black),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: Fx.m),
          child,
        ],
      ),
    );
  }
}

// -------- Comments --------

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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            (c.authorName.isNotEmpty ? c.authorName[0] : '?').toUpperCase(),
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: Fx.m),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.isInternal
                  ? scheme.surfaceContainerHighest
                  : scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
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
                      color: scheme.outline,
                    ),
                    Text(
                      _formatAgo(c.createdAt),
                      style: TextStyle(color: scheme.outline, fontSize: 12),
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
    // (Keep simple; no extra deps)
  }
}
