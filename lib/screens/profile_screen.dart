// lib/screens/profile_screen.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fixnix_app/ui/theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import '../widgets/shell.dart';
import '../ui/tokens.dart';
import '../core/api_client.dart'; // api.dio + secure
import '../features/auth/auth_providers.dart'; // sessionProvider, meProvider

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Form
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _avatarUrl = TextEditingController();
  String _timezone = 'Asia/Kolkata';
  bool _notifyEmail = true;
  bool _notifyPush = true;

  // State
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  // Device push
  bool _deviceRegistered = false;
  bool _togglingPush = false;

  Map<String, dynamic>? _me; // raw profile cache

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await api.dio.get('/api/users/me');
      final data = Map<String, dynamic>.from(res.data as Map);
      _me = data;

      _name.text = (data['name'] ?? '').toString();
      _email.text = (data['email'] ?? '').toString();
      _phone.text = (data['phone'] ?? '').toString();
      _avatarUrl.text = (data['avatarUrl'] ?? '').toString();
      _timezone = (data['timezone'] ?? 'Asia/Kolkata').toString();

      final notif = (data['notifications'] is Map)
          ? Map<String, dynamic>.from(data['notifications'])
          : <String, dynamic>{};
      _notifyEmail = (notif['email'] ?? true) == true;
      _notifyPush = (notif['push'] ?? true) == true;

      if (!kIsWeb) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          final tokens = (data['deviceTokens'] is List)
              ? List<Map<String, dynamic>>.from(
                  (data['deviceTokens'] as List).map(
                    (e) => Map<String, dynamic>.from(e),
                  ),
                )
              : const <Map<String, dynamic>>[];
          _deviceRegistered = tokens.any((d) => d['token'] == token);
        }
      }
    } catch (e) {
      _loadError = _mapErr(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapErr(Object e) {
    if (e is DioException) {
      final c = e.response?.statusCode ?? 0;
      if (c == 401) return 'Session expired. Please sign in again.';
      if (c == 403) return 'You are not allowed to perform this action.';
      if (c == 409) return 'Email already in use by another account.';
      if (c >= 500) return 'Server error. Please try later.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Network timeout. Try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Unable to reach server. Check your connection.';
      }
      return 'Request failed (${c != 0 ? 'HTTP $c' : 'network error'}).';
    }
    return 'Something went wrong. Please try again.';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'phone': _phone.text.trim(),
        'avatarUrl': _avatarUrl.text.trim(),
        'timezone': _timezone,
        'notifications': {'email': _notifyEmail, 'push': _notifyPush},
      };

      payload.removeWhere((k, v) => v is String && v.trim().isEmpty);

      final res = await api.dio.patch('/api/users/me', data: payload);
      final updated = Map<String, dynamic>.from(res.data as Map);
      _me = updated;

      _toast('Profile updated');
      ref.invalidate(meProvider);
    } catch (e) {
      final m = _mapErr(e);
      _toast(m);
      if (m.startsWith('Session expired')) {
        ref.read(sessionProvider.notifier).state = null;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (ok == true) {
      _toast('Password updated');
    }
  }

  Future<void> _toggleDevicePush() async {
    if (kIsWeb) return;
    setState(() => _togglingPush = true);
    try {
      final fcm = FirebaseMessaging.instance;

      if (!_deviceRegistered) {
        final settings = await fcm.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          _toast('Notifications permission denied.');
          return;
        }
        final token = await fcm.getToken();
        if (token == null) {
          _toast('Could not get device token.');
          return;
        }
        await api.dio.post(
          '/api/users/devices/register',
          data: {'token': token, 'platform': Theme.of(context).platform.name},
        );
        _deviceRegistered = true;
        _toast('Push enabled on this device');
      } else {
        final token = await fcm.getToken();
        if (token != null) {
          await api.dio.post(
            '/api/users/devices/unregister',
            data: {'token': token},
          );
        }
        _deviceRegistered = false;
        _toast('Push disabled on this device');
      }
      setState(() {});
    } catch (e) {
      _toast(_mapErr(e));
    } finally {
      if (mounted) setState(() => _togglingPush = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppShell(
      child: Column(
        children: [
          AppBar(
            leading: BackButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/'); // fallback to Home
                }
              },
            ),
            title: const Text('Profile'),
          ),
          Expanded(child: _buildBody(cs)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(Fx.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: Fx.m),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: Fx.m),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Fx.l),
      children: [
        _Card(
          title: 'Your Profile',
          trailing: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving…' : 'Save'),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    _AvatarPreview(url: _avatarUrl.text, name: _name.text),
                    const SizedBox(width: Fx.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name.text.isEmpty ? '—' : _name.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email.text.isEmpty ? '—' : _email.text,
                            style: TextStyle(color: cs.outline),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Change password',
                      onPressed: _changePassword,
                      icon: const Icon(Icons.password_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: Fx.l),

                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Name is required';
                    if (s.length < 2) return 'Use at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: Fx.m),

                TextFormField(
                  controller: _email,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Email is required';
                    final ok = RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(s);
                    if (!ok) return 'Enter a valid email';
                    return null;
                  },
                ),
                // const SizedBox(height: Fx.m),

                // TextFormField(
                //   controller: _phone,
                //   textInputAction: TextInputAction.next,
                //   keyboardType: TextInputType.phone,
                //   decoration: const InputDecoration(
                //     labelText: 'Phone',
                //     prefixIcon: Icon(Icons.phone_rounded),
                //   ),
                // ),
                // const SizedBox(height: Fx.m),

                // TextFormField(
                //   controller: _avatarUrl,
                //   textInputAction: TextInputAction.next,
                //   decoration: const InputDecoration(
                //     labelText: 'Avatar URL (optional)',
                //     prefixIcon: Icon(Icons.link_rounded),
                //   ),
                //   onChanged: (_) => setState(() {}),
                // ),
                // const SizedBox(height: Fx.m),

                // DropdownButtonFormField<String>(
                //   value: _timezone,
                //   decoration: const InputDecoration(
                //     labelText: 'Time zone',
                //     prefixIcon: Icon(Icons.public_rounded),
                //   ),
                //   items: const [
                //     DropdownMenuItem(
                //       value: 'Asia/Kolkata',
                //       child: Text('Asia/Kolkata'),
                //     ),
                //     DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                //     DropdownMenuItem(
                //       value: 'Asia/Dubai',
                //       child: Text('Asia/Dubai'),
                //     ),
                //     DropdownMenuItem(
                //       value: 'Europe/London',
                //       child: Text('Europe/London'),
                //     ),
                //     DropdownMenuItem(
                //       value: 'America/New_York',
                //       child: Text('America/New_York'),
                //     ),
                //   ],
                //   onChanged: (v) =>
                //       setState(() => _timezone = v ?? 'Asia/Kolkata'),
                // ),
                const SizedBox(height: Fx.m),

                // SwitchListTile(
                //   value: _notifyEmail,
                //   onChanged: (v) => setState(() => _notifyEmail = v),
                //   title: const Text('Email notifications'),
                //   subtitle: Text(
                //     'Ticket updates & mentions to your inbox.',
                //     style: TextStyle(color: cs.outline),
                //   ),
                // ),
                SwitchListTile(
                  value: _notifyPush,
                  onChanged: (v) => setState(() => _notifyPush = v),
                  title: const Text('Push notifications'),
                  subtitle: Text(
                    'Allow push from FIXNIX (also requires enabling on this device).',
                    style: TextStyle(color: cs.outline),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: Fx.l),

        if (!kIsWeb)
          _Card(
            title: 'This Device',
            trailing: FilledButton.icon(
              onPressed: _togglingPush ? null : _toggleDevicePush,
              icon: _togglingPush
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _deviceRegistered
                          ? Icons.notifications_off_rounded
                          : Icons.notifications_active_rounded,
                    ),
              label: Text(
                _togglingPush
                    ? 'Working…'
                    : (_deviceRegistered ? 'Disable Push' : 'Enable Push'),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _deviceRegistered
                      ? Icons.smartphone_rounded
                      : Icons.smartphone_outlined,
                  color: cs.primary,
                ),
                const SizedBox(width: Fx.m),
                Expanded(
                  child: Text(
                    _deviceRegistered
                        ? 'Push is enabled on this device.'
                        : 'Push is disabled on this device.',
                    style: TextStyle(color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: Fx.l),

        if (_me != null)
          _Card(
            title: 'Account',
            child: Column(
              children: [
                _InfoRow('User ID', _me!['_id']?.toString() ?? '—'),
                const SizedBox(height: 8),
                _InfoRow('Role', (_me!['role'] ?? 'user').toString()),
                const SizedBox(height: 8),
                _InfoRow(
                  'Created',
                  (_me!['createdAt'] ?? '')
                      .toString()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first,
                ),
              ],
            ),
          ),

        const SizedBox(height: Fx.l),

        const BrandColorPicker(),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Card({required this.title, required this.child, this.trailing});

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
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: Fx.m),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(color: cs.outline)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String url;
  final String name;
  const _AvatarPreview({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return CircleAvatar(
      radius: 30,
      backgroundImage: (url.isNotEmpty) ? NetworkImage(url) : null,
      child: (url.isEmpty)
          ? Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            )
          : null,
    );
  }

  static String _initials(String s) {
    final parts = s
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1)
      return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Bottom sheet to change password (enhanced)
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  String? _error;
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;

  double get _strength {
    final s = _next.text;
    int score = 0;
    if (s.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(s)) score++;
    if (RegExp(r'[0-9]').hasMatch(s)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=;\[\]\\/~`]').hasMatch(s)) score++;
    return (score / 4).clamp(0, 1).toDouble();
  }

  String _mapErr(Object e) {
    if (e is DioException) {
      final c = e.response?.statusCode ?? 0;
      if (c == 401) return 'Current password is incorrect or session expired.';
      if (c == 400) return 'Please check the fields.';
      if (c >= 500) return 'Server error. Try later.';
      return 'Failed (${c != 0 ? 'HTTP $c' : 'network error'})';
    }
    return 'Something went wrong.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.dio.post(
        '/api/users/me/change-password',
        data: {'currentPassword': _current.text, 'newPassword': _next.text},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = _mapErr(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom + 16.0;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Change Password',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Current password (exactly 8 chars)
                TextFormField(
                  controller: _current,
                  obscureText: !_showCurrent,
                  maxLength: 8,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [LengthLimitingTextInputFormatter(8)],
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showCurrent = !_showCurrent),
                      icon: Icon(
                        _showCurrent ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '');
                    if (s.isEmpty) return 'Required';
                    if (s.length != 8) return 'Use exactly 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // New password (exactly 8 chars)
                TextFormField(
                  controller: _next,
                  obscureText: !_showNext,
                  onChanged: (_) => setState(() {}),
                  maxLength: 8,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [LengthLimitingTextInputFormatter(8)],
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showNext = !_showNext),
                      icon: Icon(
                        _showNext ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '');
                    if (s.length != 8) return 'Use exactly 8 characters';
                    return null;
                  },
                ),

                // Strength meter (optional; keep if you like)
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _strength, // you can keep your existing calc
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _strength < .34
                          ? 'Weak'
                          : (_strength < .67 ? 'Okay' : 'Strong'),
                      style: TextStyle(
                        color: _strength < .34
                            ? Colors.red
                            : (_strength < .67 ? Colors.orange : cs.primary),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Confirm password (exactly 8 chars and must match)
                TextFormField(
                  controller: _confirm,
                  obscureText: !_showConfirm,
                  maxLength: 8,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [LengthLimitingTextInputFormatter(8)],
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      icon: Icon(
                        _showConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '');
                    if (s.length != 8) return 'Use exactly 8 characters';
                    if (s != _next.text) return 'Passwords do not match';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        label: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        onPressed: _saving ? null : _submit,
                        label: Text(_saving ? 'Updating…' : 'Update password'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BrandColorPicker extends ConsumerWidget {
  const BrandColorPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    final ctrl = ref.read(themeControllerProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('App color', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kBrandSeeds.map((c) {
            final isSelected = c.value == current.value;
            return InkWell(
              onTap: () => ctrl.setSeed(c),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [c, c.withOpacity(.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.withOpacity(.35),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick a color to personalize your app.',
          style: TextStyle(color: cs.outline),
        ),
      ],
    );
  }
}
