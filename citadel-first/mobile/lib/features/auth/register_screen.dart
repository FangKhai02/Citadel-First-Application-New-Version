import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/storage/secure_storage.dart';
import 'widgets/signup_progress_bar.dart';

// ── Brand tokens ───────────────────────────────────────────────────────────────
const _bgPrimary   = Color(0xFF0A0F1E);
const _cyan        = Color(0xFF29ABE2);
const _cyanDim     = Color(0xFF1A7BA8);
const _textHeading = Color(0xFFE2E8F0);
const _textMuted   = Color(0xFF94A3B8);
const _inputBorder = Color(0xFF1E2D40);
const _inputFill   = Color(0xFF0D1B2E);
const _errorRed    = Color(0xFFEF4444);

class RegisterScreen extends StatefulWidget {
  final String userType; // CLIENT | AGENT

  const RegisterScreen({super.key, required this.userType});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading       = false;
  String? _errorMessage;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().post(
        ApiEndpoints.register,
        data: {
          'email'    : _emailCtrl.text.trim(),
          'password' : _passwordCtrl.text,
          'user_type': widget.userType,
        },
      );

      await SecureStorage.saveTokens(
        accessToken : res.data['access_token'] as String,
        refreshToken: res.data['refresh_token'] as String,
        userType    : res.data['user_type'] as String,
        userId      : res.data['user_id'] as int,
      );

      if (!mounted) return;
      context.read<AuthBloc>().add(AuthLoginSucceeded(
        userType: res.data['user_type'] as String,
        userId  : res.data['user_id'] as int,
      ));

      context.push('/signup/client/declaration');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String?;
      setState(() => _errorMessage = msg ?? 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _textMuted, size: 20),
                      tooltip: 'Back',
                    ),
                  ]),
                ),

                // ── Scrollable body ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SignupProgressBar(currentStep: 0),
                          const SizedBox(height: 14),

                          // Heading
                          Text(
                            'Create your account',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 28, fontWeight: FontWeight.w700,
                              color: _textHeading, letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You\'re signing up as a ${widget.userType == 'CLIENT' ? 'Client' : 'Agent'}. '
                            'Enter your email and a secure password.',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14, color: _textMuted, height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Email
                          _InputField(
                            controller: _emailCtrl,
                            label: 'Email address',
                            hint: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                              if (!emailRe.hasMatch(v.trim())) return 'Enter a valid email address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          _InputField(
                            controller: _passwordCtrl,
                            label: 'Password',
                            hint: 'At least 8 characters',
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: _textMuted, size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Password is required';
                              if (v.length < 8) return 'Password must be at least 8 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm password
                          _InputField(
                            controller: _confirmCtrl,
                            label: 'Confirm password',
                            hint: 'Re-enter your password',
                            obscureText: _obscureConfirm,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: _textMuted, size: 20,
                              ),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please confirm your password';
                              if (v != _passwordCtrl.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Error banner
                          if (_errorMessage != null) ...[
                            _ErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 16),
                          ],

                          const SizedBox(height: 24),

                          // CTA
                          _CtaButton(isLoading: _isLoading, onPressed: _onContinue),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Input field ────────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.ibmPlexSans(fontSize: 14, color: const Color(0xFFE2E8F0)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        labelStyle: GoogleFonts.ibmPlexSans(fontSize: 13, color: _textMuted),
        hintStyle: GoogleFonts.ibmPlexSans(fontSize: 13, color: _textMuted.withAlpha(120)),
        filled: true,
        fillColor: _inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _cyan.withAlpha(180), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1.5),
        ),
        errorStyle: GoogleFonts.ibmPlexSans(fontSize: 12, color: _errorRed),
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _errorRed.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errorRed.withAlpha(80), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _errorRed, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.ibmPlexSans(fontSize: 13, color: _errorRed, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ── CTA button ─────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CtaButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_cyan, _cyanDim],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [BoxShadow(color: _cyan.withAlpha(55), blurRadius: 18, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Continue',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Colors.white, letterSpacing: 0.4,
                  ),
                ),
        ),
      ),
    );
  }
}
