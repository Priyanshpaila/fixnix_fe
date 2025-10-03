// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../push/notifications.dart';
import '../router/app_router.dart';
import '../ui/tokens.dart';

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

  void _toast(BuildContext ctx, String msg) {
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
      if (mounted) _toast(ctx, _mapLoginError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    InputDecoration _decor(String label, IconData icon, {Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(.7)),
        filled: true,
        fillColor: (isDark ? cs.surface : Colors.white).withOpacity(.78),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 10, right: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 54),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );
    }

    Widget _glassCard({required Widget child}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Fx.rLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(Fx.xl),
            decoration: BoxDecoration(
              color: (isDark ? cs.surface : Colors.white).withOpacity(.86),
              borderRadius: BorderRadius.circular(Fx.rLg),
              border: Border.all(color: cs.outlineVariant.withOpacity(.6)),
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
          // always single centered card, but with responsive max width
          final double maxFormWidth = constraints.maxWidth < 520
              ? 440
              : (constraints.maxWidth < 900 ? 520 : 560);

          final background = Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withOpacity(.10),
                      cs.secondary.withOpacity(.10),
                      cs.tertiary.withOpacity(.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // soft blobs
              Positioned(
                top: -140,
                right: -100,
                child: _blob(260, cs.primary.withOpacity(.18)),
              ),
              Positioned(
                bottom: -160,
                left: -110,
                child: _blob(320, cs.secondary.withOpacity(.16)),
              ),
            ],
          );

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
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: _glassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // YOUR PNG LOGO
                          // Put logo at: assets/logo.png and declare in pubspec.yaml
                          Padding(
                            padding: const EdgeInsets.only(bottom: Fx.l),
                            child: Image.asset(
                              'assets/logo.png',
                              height: 50,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),

                          Text(
                            'Welcome',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: Fx.l),

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
                                Icons.alternate_email_rounded,
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
                                if (s.length != 8)
                                  return 'Password must be exactly 8 characters';
                                return null;
                              },
                              onFieldSubmitted: (_) => _onLogin(),
                            ),
                          ),

                          const SizedBox(height: Fx.l),

                          // CTA
                          SizedBox(
                            width: double.infinity,
                            child: _PrimaryCTA(
                              loading: _loading,
                              label: 'Sign in',
                              icon: Icons.login_rounded,
                              onPressed: _onLogin,
                            ),
                          ),

                          const SizedBox(height: Fx.m),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: cs.outline,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Use your FIXNIX agent credentials',
                                style: TextStyle(
                                  color: cs.outline,
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

          return Stack(children: [background, form]);
        },
      ),
    );
  }

  // soft radial blob
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
}

class _PrimaryCTA extends StatelessWidget {
  final bool loading;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PrimaryCTA({
    required this.loading,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // We wrap the button in a container to add a subtle drop shadow,
    // while keeping proper ink/ripple from the ElevatedButton.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey<bool>(loading),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(.28),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
          borderRadius: BorderRadius.circular(28),
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style:
              ElevatedButton.styleFrom(
                elevation: 0, // shadow handled by parent Container
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                // nice hover/press feedback on desktop/web
                shadowColor: cs.primary,
                minimumSize: const Size.fromHeight(52),
              ).copyWith(
                // Subtle pressed + hover effects
                backgroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.disabled))
                    return cs.primary.withOpacity(.72);
                  if (states.contains(MaterialState.pressed))
                    return cs.primary.withOpacity(.90);
                  if (states.contains(MaterialState.hovered))
                    return cs.primary.withOpacity(.96);
                  return cs.primary;
                }),
              ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: loading
                ? Row(
                    key: const ValueKey('loading'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Signing in…'),
                    ],
                  )
                : Row(
                    key: const ValueKey('idle'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
