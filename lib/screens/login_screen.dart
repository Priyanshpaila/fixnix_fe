// ignore_for_file: deprecated_member_use, unused_import

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/auth_repository.dart';
import '../push/notifications.dart';
import '../router/app_router.dart';
import '../ui/tokens.dart';
import 'package:dio/dio.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: '');
  final _pass = TextEditingController(text: '');
  bool _loading = false;
  bool _obscure = true;

  void _showToast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  String _mapLoginError(Object err) {
    if (err is DioException) {
      final code = err.response?.statusCode;
      if (code == 401) return 'Invalid email or password.';
      if (code == 400) {
        final data = err.response?.data;
        if (data is Map && data['error'] == 'validation_error') {
          return 'Please check your input.';
        }
      }
      // Network / timeout friendly messages
      if (err.type == DioExceptionType.connectionTimeout ||
          err.type == DioExceptionType.receiveTimeout) {
        return 'Network timeout. Please try again.';
      }
      if (err.type == DioExceptionType.connectionError) {
        return 'Unable to reach server. Check your connection.';
      }
      return 'Server error. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _onLogin() async {
    final ctx = context;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await ref
          .read(authRepoProvider)
          .login(_email.text.trim(), _pass.text);
      ref.read(sessionProvider.notifier).state = user['id'] as String;
      await ref.read(messagingInitProvider.future);
      if (mounted) navigatorKey.currentContext?.go('/');
    } catch (e) {
      if (mounted) _showToast(ctx, _mapLoginError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withOpacity(.12),
                  scheme.secondary.withOpacity(.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(Fx.xl),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.95),
                  borderRadius: BorderRadius.circular(Fx.rLg),
                  boxShadow: Fx.cardShadow(Colors.black),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: 48,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: Fx.l),
                      Text(
                        'Welcome to FIXNIX',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: Fx.l),

                      // Email
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Email is required';
                          final ok = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(s);
                          if (!ok) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: Fx.m),

                      // Password (hard cap 8 chars)
                      TextFormField(
                        controller: _pass,
                        obscureText: _obscure,
                        maxLength: 8, // hard cap
                        inputFormatters: [LengthLimitingTextInputFormatter(8)],
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password (8 chars)',
                          counterText: '', // hide counter
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final s = v ?? '';
                          if (s.isEmpty) return 'Password is required';
                          if (s.length != 8)
                            return 'Password must be exactly 8 characters';
                          return null;
                        },
                        onFieldSubmitted: (_) => _onLogin(),
                      ),
                      const SizedBox(height: Fx.l),

                      // CTA
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(_loading ? 'Signing in…' : 'Sign in'),
                          onPressed: _loading ? null : _onLogin,
                        ),
                      ),

                      // Subtle helper row
                      const SizedBox(height: Fx.m),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Use your FIXNIX agent credentials',
                            style: TextStyle(color: scheme.outline),
                          ),
                        ],
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
  }
}
