// ignore_for_file: deprecated_member_use, unused_import

import 'dart:ui';
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
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Common, elevated text field style (keeps your validation/logic)
    InputDecoration _decor(String label, IconData icon, {Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(.7)),
        filled: true,
        fillColor: (isDark ? scheme.surface : Colors.white).withOpacity(.75),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 10, right: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 54),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );
    }

    // Gradient CTA with strong shadow (button logic unchanged)
    Widget _gradientCTA({
      Key? key,
      required Widget child,
      required VoidCallback? onTap,
    }) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: scheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: child,
        ),
      );
    }

    // Glass card with blur and deep shadows
    Widget _glassCard({required Widget child}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Fx.rLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(Fx.xl),
            decoration: BoxDecoration(
              color: (isDark ? scheme.surface : Colors.white).withOpacity(.82),
              borderRadius: BorderRadius.circular(Fx.rLg),
              border: Border.all(color: scheme.outlineVariant.withOpacity(.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.10),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          // Background: soft diagonal gradient + radial blobs
          final background = Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withOpacity(.10),
                      scheme.secondary.withOpacity(.10),
                      scheme.tertiary.withOpacity(.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // light blobs
              Positioned(
                top: -120,
                right: -80,
                child: _blob(220, scheme.primary.withOpacity(.20)),
              ),
              Positioned(
                bottom: -140,
                left: -100,
                child: _blob(280, scheme.secondary.withOpacity(.18)),
              ),
            ],
          );

          // Brand hero (only on wide screens)
          Widget? hero;
          if (isWide) {
            hero = Padding(
              padding: const EdgeInsets.all(Fx.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _floatingIcon(
                    icon: Icons.support_agent_rounded,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: Fx.l),
                  Text(
                    'FIXNIX Helpdesk',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Fx.m),
                  Text(
                    'Real-time assignment alerts and a lightning-fast agent workflow.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(.72),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Login form (scroll/keyboard safe)
          final form = SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Fx.l,
                  Fx.l,
                  Fx.l,
                  Fx.l + media.viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _glassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isWide) ...[
                            _floatingIcon(
                              icon: Icons.support_agent_rounded,
                              color: scheme.primary,
                              size: 56,
                            ),
                            const SizedBox(height: Fx.l),
                            Text(
                              'Welcome to FIXNIX',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: Fx.l),
                          ],

                          // Email
                          Material(
                            elevation: 6,
                            shadowColor: Colors.black.withOpacity(.08),
                            borderRadius: BorderRadius.circular(16),
                            child: TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              textInputAction: TextInputAction.next,
                              decoration: _decor(
                                'Email',
                                Icons.attribution_rounded,
                              ).copyWith(hintText: 'you@company.com'),
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
                          ),
                          const SizedBox(height: Fx.m),

                          // Password (exact 8 chars)
                          Material(
                            elevation: 6,
                            shadowColor: Colors.black.withOpacity(.08),
                            borderRadius: BorderRadius.circular(16),
                            child: TextFormField(
                              controller: _pass,
                              obscureText: _obscure,
                              maxLength: 8,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(8),
                              ],
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              decoration: _decor(
                                'Password (8 chars)',
                                Icons.lock_rounded,
                                suffix: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                ),
                              ).copyWith(counterText: ''),
                              validator: (v) {
                                final s = v ?? '';
                                if (s.isEmpty) return 'Password is required';
                                if (s.length != 8) {
                                  return 'Password must be exactly 8 characters';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _onLogin(),
                            ),
                          ),
                          const SizedBox(height: Fx.l),

                          // CTA
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _loading
                                  ? _gradientCTA(
                                      key: const ValueKey('loading'),
                                      onTap: null,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Signing in…'),
                                        ],
                                      ),
                                    )
                                  : _gradientCTA(
                                      key: const ValueKey('idle'),
                                      onTap: _onLogin,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.login_rounded),
                                          SizedBox(width: 8),
                                          Text('Sign in'),
                                        ],
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: Fx.m),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: scheme.outline,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Use your FIXNIX agent credentials',
                                style: TextStyle(
                                  color: scheme.outline,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          // Layout
          return Stack(
            children: [
              background,
              if (isWide)
                Row(
                  children: [
                    Expanded(flex: 5, child: hero!),
                    Expanded(flex: 4, child: form),
                  ],
                )
              else
                form,
            ],
          );
        },
      ),
    );
  }

  // Helper: soft radial blob
  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 1.8,
            spreadRadius: size / 6,
          ),
        ],
      ),
    );
  }

  // Helper: floating circular icon with inner shadow feel
  Widget _floatingIcon({
    required IconData icon,
    required Color color,
    double size = 72,
  }) {
    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withOpacity(.18), color.withOpacity(.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: color.withOpacity(.18),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
