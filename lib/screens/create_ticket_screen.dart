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
          final email = (j['email'] ?? '').toString();
          return _UserOption(
            id: id,
            label: name.isNotEmpty ? name : email,
            subtitle: name.isNotEmpty ? email : null,
          );
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
            padding: const EdgeInsets.all(Fx.l),
            children: [
              Container(
                padding: const EdgeInsets.all(Fx.l),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: Fx.cardShadow(Colors.black),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // Title
                      TextFormField(
                        controller: _title,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Title is required';
                          if (s.length < 4) return 'Use at least 4 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: Fx.m),

                      // Description
                      TextFormField(
                        controller: _desc,
                        maxLines: 5,
                        minLines: 3,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(2000),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Description is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: Fx.m),

                      // Priority
                      DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'P1',
                            child: Text('P1 – High'),
                          ),
                          DropdownMenuItem(
                            value: 'P2',
                            child: Text('P2 – Medium'),
                          ),
                          DropdownMenuItem(
                            value: 'P3',
                            child: Text('P3 – Normal'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _priority = v ?? 'P3'),
                      ),
                      const SizedBox(height: Fx.m),

                      // Queue (robust)
                      if (_loadingQueues)
                        const ListTile(
                          leading: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          title: Text('Loading queues…'),
                        )
                      else if (_loadQueuesError != null)
                        ListTile(
                          leading: const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                          ),
                          title: Text(
                            _loadQueuesError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          trailing: TextButton.icon(
                            onPressed: _refreshAll,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        )
                      else if (_queues.isEmpty)
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('No queues available'),
                          subtitle: Text(
                            'Ticket will use the default routing.',
                            style: TextStyle(color: scheme.outline),
                          ),
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

                      const SizedBox(height: Fx.m),

                      // Assignee (robust + assign-to-me)
                      if (_loadingUsers)
                        const ListTile(
                          leading: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          title: Text('Loading agents…'),
                        )
                      else if (_loadUsersError != null)
                        Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              title: Text(
                                _loadUsersError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                              trailing: TextButton.icon(
                                onPressed: _refreshAll,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ),
                            if (_myUserId != null && _myUserId!.isNotEmpty)
                              SwitchListTile(
                                value: _assignToMe,
                                onChanged: (v) =>
                                    setState(() => _assignToMe = v),
                                title: const Text('Assign to me'),
                                subtitle: Text(
                                  'Agents list unavailable. Use your account as assignee.',
                                  style: TextStyle(color: scheme.outline),
                                ),
                              )
                            else
                              ListTile(
                                leading: const Icon(Icons.info_outline),
                                title: const Text('Proceed without assignee'),
                                subtitle: Text(
                                  'You can assign later from the ticket page.',
                                  style: TextStyle(color: scheme.outline),
                                ),
                              ),
                          ],
                        )
                      else if (_users.isEmpty)
                        Column(
                          children: [
                            const ListTile(
                              leading: Icon(Icons.info_outline),
                              title: Text('No agents found'),
                            ),
                            if (_myUserId != null && _myUserId!.isNotEmpty)
                              SwitchListTile(
                                value: _assignToMe,
                                onChanged: (v) =>
                                    setState(() => _assignToMe = v),
                                title: const Text('Assign to me'),
                                subtitle: Text(
                                  'No agents available. Use your account as assignee.',
                                  style: TextStyle(color: scheme.outline),
                                ),
                              )
                            else
                              ListTile(
                                leading: const Icon(Icons.info_outline),
                                title: const Text('Proceed without assignee'),
                                subtitle: Text(
                                  'You can assign later from the ticket page.',
                                  style: TextStyle(color: scheme.outline),
                                ),
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
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Unassigned'),
                                ),
                                ..._users.map(
                                  (u) => DropdownMenuItem<String?>(
                                    value: u.id,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (u.subtitle != null)
                                          Text(
                                            u.subtitle!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() => _assigneeId = v),
                            ),
                            if (_myUserId != null && _myUserId!.isNotEmpty)
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
                                  style: TextStyle(color: scheme.outline),
                                ),
                              ),
                          ],
                        ),

                      const SizedBox(height: Fx.l),

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
                                  : const Icon(Icons.check_rounded),
                              onPressed: _submitting ? null : _create,
                              label: Text(_submitting ? 'Creating…' : 'Create'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Fx.l),
              Text(
                'Tip: SLA picker can be added next. Queues and assignee are optional and can be changed later from the ticket page.',
                style: TextStyle(color: scheme.outline),
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
