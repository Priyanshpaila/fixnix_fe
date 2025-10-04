// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/tickets/tickets_repository.dart';
import '../ui/tokens.dart';
import '../core/api_client.dart'; // api.dio + secure

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();

  // Priority
  String _priority = 'P3';

  // Assignee
  String? _assigneeId;
  bool _loadingUsers = true;
  String? _loadUsersError;
  List<_UserOption> _users = [];
  String? _myUserId;
  bool _assignToMe = false;

  // Queue
  String? _queueId; // null = no queue / default
  bool _loadingQueues = true;
  String? _loadQueuesError;
  List<_QueueOption> _queues = [];

  bool _submitting = false;

  bool get _isDirty =>
      _title.text.trim().isNotEmpty ||
      _desc.text.trim().isNotEmpty ||
      _priority != 'P3' ||
      _assigneeId != null ||
      _queueId != null ||
      _assignToMe;

  bool get _isRefreshing => _loadingUsers || _loadingQueues;

  @override
  void initState() {
    super.initState();
    _hydrateMe().then((_) => _refreshAll());
  }

  Future<void> _hydrateMe() async {
    _myUserId = await secure.read(key: 'user_id');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  String _mapError(Object e) {
    if (e is DioException) {
      final sc = e.response?.statusCode ?? 0;
      if (sc == 401) return 'Session expired. Please sign in again.';
      if (sc == 403) return 'You don’t have permission for this action.';
      if (sc == 413)
        return 'Content too large. Please shorten the description.';
      if (sc == 400) return 'Please check the fields and try again.';
      if (sc >= 500) return 'Server error. Please try later.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Network timeout. Try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Unable to reach server. Check your connection.';
      }
      return 'Request failed (${sc != 0 ? 'HTTP $sc' : 'network error'}).';
    }
    return 'Something went wrong. Please try again.';
  }

  // ---------- Agents ----------
  List<_UserOption> _parseUsers(dynamic data) {
    final List rawList;
    if (data is Map && data['items'] is List) {
      rawList = List.from(data['items'] as List);
    } else if (data is List) {
      rawList = List.from(data);
    } else {
      return const <_UserOption>[];
    }

    return rawList
        .map<_UserOption?>((e) {
          final j = Map<String, dynamic>.from(e as Map);
          final id = (j['_id'] ?? j['id'] ?? '').toString();
          if (id.isEmpty) return null;
          final name = (j['name'] ?? '').toString();
          // final email = (j['email'] ?? '').toString();
          return _UserOption(id: id, label: name.isNotEmpty ? name : 'Agent');
        })
        .whereType<_UserOption>()
        .toList();
  }

  Future<void> _fetchAgents() async {
    setState(() {
      _loadingUsers = true;
      _loadUsersError = null;
      _users = [];
    });
    try {
      final res = await api.dio.get(
        '/api/users',
        queryParameters: {'role': 'agent', 'limit': 100},
      );
      _users = _parseUsers(res.data);
      _assigneeId = null; // default to Unassigned
      if (_users.isEmpty && _myUserId != null && _myUserId!.isNotEmpty) {
        _assignToMe = true;
      }
    } catch (e) {
      _loadUsersError = _mapError(e);
      if (_myUserId != null && _myUserId!.isNotEmpty) {
        _assignToMe = true;
      }
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  // ---------- Queues ----------
  List<_QueueOption> _parseQueues(dynamic data) {
    final List rawList;
    if (data is Map && data['items'] is List) {
      rawList = List.from(data['items'] as List);
    } else if (data is List) {
      rawList = List.from(data);
    } else {
      return const <_QueueOption>[];
    }

    return rawList
        .map<_QueueOption?>((e) {
          final j = Map<String, dynamic>.from(e as Map);
          final id = (j['_id'] ?? j['id'] ?? '').toString();
          final name = (j['name'] ?? '').toString();
          if (id.isEmpty || name.isEmpty) return null;
          return _QueueOption(id: id, name: name);
        })
        .whereType<_QueueOption>()
        .toList();
  }

  Future<void> _fetchQueues() async {
    setState(() {
      _loadingQueues = true;
      _loadQueuesError = null;
      _queues = [];
    });
    try {
      final res = await api.dio.get(
        '/api/queues',
        queryParameters: {'limit': 100},
      );
      _queues = _parseQueues(res.data);
      _queueId = null; // default: no queue / backend default
    } catch (e) {
      _loadQueuesError = _mapError(e);
    } finally {
      if (mounted) setState(() => _loadingQueues = false);
    }
  }

  // ---------- Common refresh ----------
  Future<void> _refreshAll() async {
    setState(() {
      _loadingUsers = true;
      _loadingQueues = true;
      _loadUsersError = null;
      _loadQueuesError = null;
    });
    try {
      await Future.wait([_fetchAgents(), _fetchQueues()]);
    } finally {
      // _fetch* already flips loading flags; nothing else needed here
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
              'You have unsaved changes. Do you want to discard them and go back?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmUnassigned() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Create without assignee?'),
            content: const Text(
              'No assignee was selected. Do you want to create this ticket as Unassigned?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _create() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    // Final assignee with fallback
    String? finalAssignee = _assigneeId;
    if ((_users.isEmpty || _loadUsersError != null) &&
        _assignToMe &&
        _myUserId != null &&
        _myUserId!.isNotEmpty) {
      finalAssignee = _myUserId;
    }
    if (finalAssignee == null) {
      final ok = await _confirmUnassigned();
      if (!ok) return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(ticketsRepoProvider)
          .createTicket(
            _title.text.trim(),
            _desc.text.trim(),
            queueId: _queueId,
            assigneeId: finalAssignee,
            priority: _priority,
          );
      _toast('Ticket created');
      if (mounted) context.pop(true);
    } catch (e) {
      final msg = _mapError(e);
      _toast(msg);
      if (msg.startsWith('Session expired') && mounted) {
        context.go('/login');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
      ref.invalidate(ticketsListProvider);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        final ok = await _confirmDiscard();
        if (ok) {
          if (context.canPop()) return true;
          context.go('/');
          return false;
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () async {
              final ok = await _confirmDiscard();
              if (!ok) return;
              if (context.canPop()) {
                context.pop(false);
              } else {
                context.go('/');
              }
            },
          ),
          title: const Text('Create Ticket'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isRefreshing ? null : _refreshAll,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator.adaptive(
          onRefresh: _refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Fx.l),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeader(
                        icon: Icons.receipt_long_rounded,
                        title: 'Details',
                        subtitle:
                            'Give the ticket a clear title and short description',
                      ),
                      const SizedBox(height: Fx.s),
                      _SectionCard(
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            children: [
                              // Title
                              TextFormField(
                                controller: _title,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Title',
                                  hintText: 'e.g. VPN not connecting on mobile',
                                  prefixIcon: const Icon(Icons.title_rounded),
                                  suffixIcon: (_title.text.isNotEmpty)
                                      ? IconButton(
                                          tooltip: 'Clear title',
                                          icon: const Icon(Icons.close_rounded),
                                          onPressed: () {
                                            _title.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'Title is required';
                                  if (s.length < 4)
                                    return 'Use at least 4 characters';
                                  return null;
                                },
                              ),

                              const SizedBox(height: Fx.m),

                              // Description
                              TextFormField(
                                controller: _desc,
                                maxLines: 6,
                                minLines: 4,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(2000),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  hintText:
                                      'Add steps to reproduce or screenshots (URLs)…',
                                  alignLabelWithHint: true,
                                  prefixIcon: Icon(Icons.description_outlined),
                                ),
                                buildCounter:
                                    (
                                      context, {
                                      required int currentLength,
                                      required bool isFocused,
                                      int? maxLength,
                                    }) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: 12,
                                        top: 6,
                                      ),
                                      child: Text(
                                        '$currentLength / ${maxLength ?? 2000}',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty)
                                    return 'Description is required';
                                  return null;
                                },
                              ),

                              const SizedBox(height: Fx.m),

                              // Priority (chips)
                              _LabeledRow(
                                icon: Icons.flag_outlined,
                                label: 'Priority',
                                child: _PriorityChips(
                                  value: _priority,
                                  onChanged: (v) =>
                                      setState(() => _priority = v),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: Fx.l),

                      _SectionHeader(
                        icon: Icons.route_rounded,
                        title: 'Routing',
                        subtitle: 'Optional: choose a queue',
                      ),
                      const SizedBox(height: Fx.s),
                      _SectionCard(
                        child: Column(
                          children: [
                            if (_loadingQueues)
                              const _LoadingTile(text: 'Loading queues…')
                            else if (_loadQueuesError != null)
                              _ErrorTileInline(
                                message: _loadQueuesError!,
                                onRetry: _refreshAll,
                              )
                            else if (_queues.isEmpty)
                              _InfoTileInline(
                                icon: Icons.info_outline,
                                title: 'No queues available',
                                subtitle:
                                    'Ticket will use the default routing.',
                              )
                            else
                              DropdownButtonFormField<String?>(
                                value: _queueId,
                                decoration: const InputDecoration(
                                  labelText: 'Queue',
                                  prefixIcon: Icon(Icons.inbox_outlined),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Default (no queue)'),
                                  ),
                                  ..._queues.map(
                                    (q) => DropdownMenuItem<String?>(
                                      value: q.id,
                                      child: Text(q.name),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() => _queueId = v),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: Fx.l),

                      _SectionHeader(
                        icon: Icons.person_pin_circle_rounded,
                        title: 'Assignment',
                        subtitle:
                            'Pick an agent or assign to yourself. You can change later.',
                      ),
                      const SizedBox(height: Fx.s),
                      _SectionCard(
                        child: Column(
                          children: [
                            if (_loadingUsers)
                              const _LoadingTile(text: 'Loading agents…')
                            else if (_loadUsersError != null)
                              Column(
                                children: [
                                  _ErrorTileInline(
                                    message: _loadUsersError!,
                                    onRetry: _refreshAll,
                                  ),
                                  if (_myUserId != null &&
                                      _myUserId!.isNotEmpty)
                                    SwitchListTile(
                                      value: _assignToMe,
                                      onChanged: (v) =>
                                          setState(() => _assignToMe = v),
                                      title: const Text('Assign to me'),
                                      subtitle: Text(
                                        'Agents list unavailable. Use your account as assignee.',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                      ),
                                    )
                                  else
                                    const _InfoTileInline(
                                      icon: Icons.info_outline,
                                      title: 'Proceed without assignee',
                                      subtitle:
                                          'You can assign later from the ticket page.',
                                    ),
                                ],
                              )
                            else if (_users.isEmpty)
                              Column(
                                children: [
                                  const _InfoTileInline(
                                    icon: Icons.info_outline,
                                    title: 'No agents found',
                                  ),
                                  if (_myUserId != null &&
                                      _myUserId!.isNotEmpty)
                                    SwitchListTile(
                                      value: _assignToMe,
                                      onChanged: (v) =>
                                          setState(() => _assignToMe = v),
                                      title: const Text('Assign to me'),
                                      subtitle: Text(
                                        'No agents available. Use your account as assignee.',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                      ),
                                    )
                                  else
                                    const _InfoTileInline(
                                      icon: Icons.info_outline,
                                      title: 'Proceed without assignee',
                                      subtitle:
                                          'You can assign later from the ticket page.',
                                    ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  DropdownButtonFormField<String?>(
                                    value: _assigneeId,
                                    decoration: const InputDecoration(
                                      labelText: 'Assign to',
                                      prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                      ),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Unassigned'),
                                      ),
                                      ..._users.map(
                                        (u) => DropdownMenuItem<String?>(
                                          value: u.id,
                                          child: _UserOptionTile(u: u),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _assigneeId = v),
                                  ),
                                  if (_myUserId != null &&
                                      _myUserId!.isNotEmpty)
                                    SwitchListTile(
                                      value: _assignToMe,
                                      onChanged: (v) {
                                        setState(() {
                                          _assignToMe = v;
                                          if (v) _assigneeId = null;
                                        });
                                      },
                                      title: const Text('Assign to me'),
                                      subtitle: Text(
                                        'Override dropdown and assign to your account.',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: Fx.l),

                      // Footer actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _submitting
                                  ? null
                                  : () async {
                                      final ok = await _confirmDiscard();
                                      if (!ok) return;
                                      if (context.canPop()) {
                                        context.pop(false);
                                      } else {
                                        context.go('/');
                                      }
                                    },
                              label: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: Fx.m),
                          Expanded(
                            child: FilledButton.icon(
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_rounded),
                              onPressed: _submitting ? null : _create,
                              label: Text(
                                _submitting ? 'Creating…' : 'Create ticket',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Fx.l),
                    ],
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

class _UserOption {
  final String id;
  final String label;
  final String? subtitle;
  _UserOption({required this.id, required this.label, this.subtitle});
}

class _QueueOption {
  final String id;
  final String name;
  _QueueOption({required this.id, required this.name});
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: cs.outline, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Fx.l),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Fx.cardShadow(Colors.black),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _LabeledRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PriorityChips extends StatelessWidget {
  final String value; // 'P1','P2','P3'
  final ValueChanged<String> onChanged;
  const _PriorityChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget chip(String v, String label, IconData icon) {
      final selected = value == v;
      return ChoiceChip(
        selected: selected,
        onSelected: (_) => onChanged(v),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selectedColor: cs.primary,
        labelStyle: TextStyle(
          color: selected ? cs.onPrimary : cs.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(color: cs.outlineVariant),
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        chip('P1', 'P1 – High', Icons.priority_high_rounded),
        chip('P2', 'P2 – Medium', Icons.outlined_flag_rounded),
        chip('P3', 'P3 – Normal', Icons.flag_circle_outlined),
      ],
    );
  }
}

class _UserOptionTile extends StatelessWidget {
  final _UserOption u;
  const _UserOptionTile({required this.u});

  @override
  Widget build(BuildContext context) {
    final initials = (u.label.isNotEmpty ? u.label.trim() : '?')
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .map((e) => e.characters.first.toUpperCase())
        .take(2)
        .join();

    return Row(
      mainAxisSize: MainAxisSize.min, // ⬅️ important for dropdown menus
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 12,
          child: Text(initials, style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),

        // Use Flexible.loose instead of Expanded/flex
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            mainAxisSize: MainAxisSize.min, // ⬅️ keep it shrink-wrapped
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              if (u.subtitle != null && u.subtitle!.isNotEmpty)
                Text(
                  u.subtitle!,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingTile extends StatelessWidget {
  final String text;
  const _LoadingTile({required this.text});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    title: Text(text),
  );
}

class _ErrorTileInline extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorTileInline({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.error_outline, color: Colors.red),
    title: Text(message, style: const TextStyle(color: Colors.red)),
    trailing: TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Retry'),
    ),
  );
}

class _InfoTileInline extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _InfoTileInline({
    required this.icon,
    required this.title,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: (subtitle != null) ? Text(subtitle!) : null,
  );
}
