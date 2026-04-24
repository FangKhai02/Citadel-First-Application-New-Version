import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import 'login_bloc.dart';
import 'login_event.dart';
import 'login_state.dart';

// ── Brand tokens (fintech dark OLED — IBM Plex Sans)
const _bgPrimary   = Color(0xFF0F172A); // Slate 900 — OLED base
const _cyan        = Color(0xFF29ABE2); // Citadel brand cyan
const _textHeading = Color(0xFFE2E8F0); // Slate 200 — soft heading
const _textMuted   = Color(0xFF94A3B8); // Slate 400
const _inputBorder = Color(0xFF334155); // Slate 700
const _errorRed    = Color(0xFFEF4444);

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();
  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView>
    with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure        = true;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LoginBloc>().add(LoginSubmitted(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ibm = GoogleFonts.ibmPlexSans;

    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          context.read<AuthBloc>().add(
            AuthLoginSucceeded(userType: state.userType, userId: state.userId),
          );
          context.go(state.userType == 'AGENT' ? '/agent/dashboard' : '/client/dashboard');
        } else if (state is LoginFailure) {
          if (state.emailNotRegistered) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.message, style: ibm(fontSize: 13))),
                ]),
                backgroundColor: const Color(0xFFE67E22),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'Sign Up',
                  textColor: Colors.white,
                  onPressed: () => context.push('/signup'),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message, style: ibm(fontSize: 13))),
                ]),
                backgroundColor: _errorRed,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: _bgPrimary,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // ── Logo ──────────────────────────────────────────
                    const _LogoSection(),
                    const SizedBox(height: 40),

                    // ── Glass card form ───────────────────────────────
                    _GlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Heading
                            Text('Welcome back',
                                style: ibm(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: _textHeading,
                                )),
                            const SizedBox(height: 4),
                            Text('Sign in to your account',
                                style: ibm(fontSize: 13, color: _textMuted)),
                            const SizedBox(height: 28),

                            // Email
                            _FieldLabel('Email Address', ibm: ibm),
                            const SizedBox(height: 6),
                            _DarkField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              hint: 'you@example.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _passwordFocus.requestFocus(),
                              isFocused: _emailFocus.hasFocus,
                              ibm: ibm,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password
                            _FieldLabel('Password', ibm: ibm),
                            const SizedBox(height: 6),
                            _DarkField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              isFocused: _passwordFocus.hasFocus,
                              ibm: ibm,
                              suffix: GestureDetector(
                                onTap: () =>
                                    setState(() => _obscure = !_obscure),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: _textMuted,
                                    size: 18,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 4),
                                  minimumSize: const Size(44, 44),
                                ),
                                child: Text('Forgot password?',
                                    style: ibm(
                                      fontSize: 12,
                                      color: _cyan,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Sign In button
                            BlocBuilder<LoginBloc, LoginState>(
                              builder: (context, state) {
                                final loading = state is LoginLoading;
                                return _SignInButton(
                                  loading: loading,
                                  onPressed: _submit,
                                  ibm: ibm,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Sign-up prompt ────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: ibm(fontSize: 13, color: _textMuted),
                        ),
                        TextButton(
                          onPressed: () => context.push('/signup'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Sign Up',
                            style: ibm(
                              fontSize: 13,
                              color: _cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Text(
                      '© ${DateTime.now().year} Citadel Group. All rights reserved.',
                      style: ibm(fontSize: 10, color: _inputBorder),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo section ───────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft ambient glow behind logo
        Container(
          width: 220,
          height: 80,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: _cyan.withAlpha(30),
                blurRadius: 50,
                spreadRadius: 12,
              ),
            ],
          ),
        ),
        // Logo — no box, no border
        Image.asset(
          'assets/images/logo.png',
          height: 52,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

// ── Glassmorphism card ─────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withAlpha(18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Field label ────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final TextStyle Function({double? fontSize, FontWeight? fontWeight, Color? color}) ibm;
  const _FieldLabel(this.text, {required this.ibm});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ibm(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
        ),
      );
}

// ── Dark text field ────────────────────────────────────────────────────────────

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final bool isFocused;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) ibm;

  const _DarkField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.isFocused,
    required this.ibm,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.suffix,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isFocused
            ? [BoxShadow(
                color: const Color(0xFF29ABE2).withAlpha(50),
                blurRadius: 12,
                spreadRadius: 1,
              )]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        style: ibm(fontSize: 14, color: const Color(0xFFF8FAFC)),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: ibm(fontSize: 14, color: const Color(0xFF475569)),
          prefixIcon: Icon(
            icon,
            size: 18,
            color: isFocused
                ? const Color(0xFF29ABE2)
                : const Color(0xFF475569),
          ),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFF0F172A),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF29ABE2), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          errorStyle: ibm(fontSize: 11, color: const Color(0xFFEF4444)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ── Sign In button ─────────────────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  final TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) ibm;

  const _SignInButton({
    required this.loading,
    required this.onPressed,
    required this.ibm,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF29ABE2), Color(0xFF1A7BA8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: loading ? const Color(0xFF1E293B) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF29ABE2).withAlpha(70),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFF29ABE2),
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Sign In',
                  style: ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
