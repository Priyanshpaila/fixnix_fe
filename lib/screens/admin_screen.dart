import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/shell.dart';
import '../ui/tokens.dart';
import '../features/queues/queues_repository.dart';
import '../features/sla/sla_repository.dart';
import '../core/api_client.dart'; // ⬅️ for api.dio

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  // queues
  final _qName = TextEditingController();
  bool _qSubmitting = false;
  List<Map<String, dynamic>> _queues = [];
  bool _qLoading = true;
  String? _qError;

  // sla
  final _sName = TextEditingController();
  final _sFirst = TextEditingController(text: '60');
  final _sRes = TextEditingController(text: '480');
  bool _sSubmitting = false;
  List<Map<String, dynamic>> _policies = [];
  bool _sLoading = true;
  String? _sError;

  // users
  final _uName = TextEditingController();
  final _uEmail = TextEditingController();
  final _uPassword = TextEditingController();
  String _uRole = 'agent';
  bool _uSubmitting = false;
  bool _uLoading = true;
  String? _uError;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  String _err(Object e) {
    if (e is DioException) {
      final c = e.response?.statusCode ?? 0;
      if (c == 401) return 'Session expired. Sign in again.';
      if (c == 403) return 'Not allowed.';
      if (c >= 500) return 'Server error. Try later.';
      final msg = e.response?.data is Map
          ? (e.response!.data['error']?.toString() ?? '')
          : '';
      return msg.isNotEmpty
          ? msg
          : 'Request failed (${c != 0 ? 'HTTP $c' : 'network'})';
    }
    return 'Something went wrong.';
  }

  Future<void> _refreshAll() async {
    setState(() {
      _qLoading = true;
      _sLoading = true;
      _uLoading = true;
      _qError = null;
      _sError = null;
      _uError = null;
    });
    try {
      final q = await ref.read(queuesRepoProvider).list();
      final s = await ref.read(slaRepoProvider).list();
      final u = await _fetchUsers();
      setState(() {
        _queues = q;
        _policies = s;
        _users = u;
      });
    } catch (e) {
      setState(() {
        final m = _err(e);
        _qError = m;
        _sError = m;
        _uError = m;
      });
    } finally {
      setState(() {
        _qLoading = false;
        _sLoading = false;
        _uLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final res = await api.dio.get('/api/users');
    final items =
        (res.data is Map ? (res.data['items'] as List?) : res.data as List?) ??
        [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> _createQueue() async {
    final name = _qName.text.trim();
    if (name.length < 2) {
      _toast('Enter a queue name (min 2 chars)');
      return;
    }
    setState(() => _qSubmitting = true);
    try {
      await ref.read(queuesRepoProvider).create(name);
      _qName.clear();
      _toast('Queue created');
      await _refreshAll();
    } catch (e) {
      _toast(_err(e));
    } finally {
      setState(() => _qSubmitting = false);
    }
  }

  Future<void> _createPolicy() async {
    final name = _sName.text.trim();
    final first = int.tryParse(_sFirst.text.trim()) ?? 0;
    final res = int.tryParse(_sRes.text.trim()) ?? 0;
    if (name.length < 2) return _toast('Enter policy name');
    if (first <= 0 || res <= 0) return _toast('Durations must be > 0');
    setState(() => _sSubmitting = true);
    try {
      await ref
          .read(slaRepoProvider)
          .create(name: name, firstResponseMins: first, resolutionMins: res);
      _sName.clear();
      _sFirst.text = '60';
      _sRes.text = '480';
      _toast('SLA policy created');
      await _refreshAll();
    } catch (e) {
      _toast(_err(e));
    } finally {
      setState(() => _sSubmitting = false);
    }
  }

  Future<void> _createUser() async {
    final name = _uName.text.trim();
    final email = _uEmail.text.trim();
    final pwd = _uPassword.text;
    if (name.length < 2) return _toast('Enter full name');
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!ok) return _toast('Enter valid email');
    if (pwd.length != 8) return _toast('Password must be exactly 8 characters');

    setState(() => _uSubmitting = true);
    try {
      await api.dio.post(
        '/api/users',
        data: {'name': name, 'email': email, 'role': _uRole, 'password': pwd},
      );
      _uName.clear();
      _uEmail.clear();
      _uPassword.clear();
      _toast('User created');
      _users = await _fetchUsers();
      setState(() {});
    } catch (e) {
      _toast(_err(e));
    } finally {
      setState(() => _uSubmitting = false);
    }
  }

  Future<void> _pingUser(
    String userId, {
    String title = 'Ping from Admin',
    String body = 'Please check your tickets.',
    Map<String, String> data = const {'kind': 'admin_ping'},
  }) async {
    try {
      // New endpoint: POST /api/admin/users/:id/ping
      await api.dio.post(
        '/api/users/$userId/ping',
        data: {
          'title': title,
          'body': body,
          'data': data, // values must be strings on FCM
        },
      );
      _toast('Ping sent');
    } catch (e) {
      _toast(_err(e));
    }
  }

  Future<void> _pingAll() async {
    try {
      await api.dio.post('/api/users/admin/ping'); // no userId => broadcast
      _toast('Ping sent to all users');
    } catch (e) {
      _toast(_err(e));
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  @override
  void dispose() {
    _qName.dispose();
    _sName.dispose();
    _sFirst.dispose();
    _sRes.dispose();
    _uName.dispose();
    _uEmail.dispose();
    _uPassword.dispose();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppShell(
      child: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              leading: Builder(
                builder: (ctx2) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx2).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              title: const Text('Admin'),
              bottom: TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: 'Queues'),
                  Tab(text: 'SLA Policies'),
                  Tab(text: 'Users'), // ⬅️ NEW
                ],
              ),
              actions: [
                IconButton(
                  onPressed: _refreshAll,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],

          body: TabBarView(
            controller: _tab,
            children: [
              // -------- Queues tab --------
              RefreshIndicator.adaptive(
                onRefresh: _refreshAll,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(Fx.l),
                  children: [
                    _Card(
                      title: 'Create Queue',
                      child: Column(
                        children: [
                          TextField(
                            controller: _qName,
                            decoration: const InputDecoration(
                              labelText: 'Queue name',
                              prefixIcon: Icon(Icons.inbox_rounded),
                            ),
                          ),
                          const SizedBox(height: Fx.m),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              icon: _qSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add_rounded),
                              label: Text(
                                _qSubmitting ? 'Creating…' : 'Create',
                              ),
                              onPressed: _qSubmitting ? null : _createQueue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Fx.l),
                    _Card(
                      title: 'Queues',
                      child: _qLoading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : (_qError != null)
                          ? _ErrorTile(msg: _qError!, onRetry: _refreshAll)
                          : (_queues.isEmpty)
                          ? const ListTile(title: Text('No queues yet'))
                          : Column(
                              children: _queues
                                  .map(
                                    (q) => ListTile(
                                      leading: const Icon(Icons.inbox_outlined),
                                      title: Text(q['name']?.toString() ?? '—'),
                                      subtitle: Text(
                                        q['_id']?.toString() ?? '',
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),

              // -------- SLA tab --------
              RefreshIndicator.adaptive(
                onRefresh: _refreshAll,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(Fx.l),
                  children: [
                    _Card(
                      title: 'Create SLA Policy',
                      child: Column(
                        children: [
                          TextField(
                            controller: _sName,
                            decoration: const InputDecoration(
                              labelText: 'Policy name',
                              prefixIcon: Icon(Icons.rule_rounded),
                            ),
                          ),
                          const SizedBox(height: Fx.m),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _sFirst,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'First response (mins)',
                                    prefixIcon: Icon(Icons.timer_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Fx.m),
                              Expanded(
                                child: TextField(
                                  controller: _sRes,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Resolution (mins)',
                                    prefixIcon: Icon(Icons.timelapse_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Fx.m),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              icon: _sSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add_task_rounded),
                              label: Text(
                                _sSubmitting ? 'Creating…' : 'Create',
                              ),
                              onPressed: _sSubmitting ? null : _createPolicy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Fx.l),
                    _Card(
                      title: 'SLA Policies',
                      child: _sLoading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : (_sError != null)
                          ? _ErrorTile(msg: _sError!, onRetry: _refreshAll)
                          : (_policies.isEmpty)
                          ? const ListTile(title: Text('No policies yet'))
                          : Column(
                              children: _policies
                                  .map(
                                    (p) => ListTile(
                                      leading: const Icon(
                                        Icons.flag_circle_outlined,
                                      ),
                                      title: Text(p['name']?.toString() ?? '—'),
                                      subtitle: Text(
                                        'First: ${p['firstResponseMins']}m • Resolution: ${p['resolutionMins']}m',
                                        style: TextStyle(color: cs.outline),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),

              // -------- Users tab (NEW) --------
              RefreshIndicator.adaptive(
                onRefresh: () async {
                  _users = await _fetchUsers();
                  setState(() {});
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(Fx.l),
                  children: [
                    _Card(
                      title: 'Create User',
                      child: Column(
                        children: [
                          TextField(
                            controller: _uName,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                            ),
                          ),
                          const SizedBox(height: Fx.m),
                          TextField(
                            controller: _uEmail,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: Fx.m),
                          Row(
                            children: [
                              // Role
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _uRole,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'agent',
                                      child: Text('Agent'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'admin',
                                      child: Text('Admin'),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _uRole = v ?? 'agent'),
                                  decoration: const InputDecoration(
                                    labelText: 'Role',
                                    prefixIcon: Icon(
                                      Icons.admin_panel_settings_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Fx.m),
                              // Password (8 char hard cap)
                              Expanded(
                                child: TextField(
                                  controller: _uPassword,
                                  obscureText: true,
                                  maxLength: 8,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(8),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Password (8 chars)',
                                    counterText: '',
                                    prefixIcon: Icon(Icons.lock_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Fx.m),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              icon: _uSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_rounded),
                              label: Text(
                                _uSubmitting ? 'Creating…' : 'Create user',
                              ),
                              onPressed: _uSubmitting ? null : _createUser,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Fx.l),

                    _Card(
                      title: 'Users',
                      child: _uLoading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : (_uError != null)
                          ? _ErrorTile(msg: _uError!, onRetry: _refreshAll)
                          : Column(
                              children: [
                                const SizedBox(height: Fx.m),
                                if (_users.isEmpty)
                                  const ListTile(title: Text('No users yet'))
                                else
                                  ..._users.map((u) {
                                    final name =
                                        (u['name'] ?? u['email'] ?? 'User')
                                            .toString();
                                    final email = (u['email'] ?? '').toString();
                                    final role = (u['role'] ?? 'agent')
                                        .toString();

                                    return ListTile(
                                      leading: CircleAvatar(
                                        child: Text(
                                          (name.isNotEmpty ? name[0] : '?')
                                              .toUpperCase(),
                                        ),
                                      ),
                                      title: Text(name),
                                      subtitle: Text(
                                        '$email • $role',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: TextButton.icon(
                                        onPressed: () => _pingUser(
                                          u['_id']?.toString() ?? '',
                                        ),
                                        icon: const Icon(Icons.waves_rounded),
                                        label: const Text('Ping'),
                                      ),
                                    );
                                  }).toList(),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: Fx.m),
          child,
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String msg;
  final Future<void> Function() onRetry;
  const _ErrorTile({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.error_outline, color: Colors.red),
    title: Text(msg, style: const TextStyle(color: Colors.red)),
    trailing: TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Retry'),
    ),
  );
}
