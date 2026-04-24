import 'dart:convert';
import 'dart:io';
import 'dart:ui';
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
import 'widgets/signup_progress_bar.dart' show SignupProgressBar;

// ── Brand tokens — Liquid Glass Dark (Citadel Navy) ────────────────────────
const _bgPrimary    = Color(0xFF0C1829);
const _cyan         = Color(0xFF29ABE2);
const _cyanDim      = Color(0xFF1A7BA8);
const _textHeading  = Color(0xFFE2E8F0);
const _textSub      = Color(0xFFCBD5E1);
const _textMuted    = Color(0xFF64748B);
const _borderGlass  = Color(0xFF1E3A5F);
const _errorRed     = Color(0xFFEF4444);
const _ctaTop       = Color(0xFF2E6DA4);
const _ctaBottom    = Color(0xFF1B4F7A);

class RegisterScreen extends StatefulWidget {
  final String userType;

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

  bool _obscurePassword  = true;
  bool _obscureConfirm   = true;
  bool _isLoading        = false;
  bool _validatingDomain = false;
  String? _errorMessage;

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Email validation ────────────────────────────────────────────────────────

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) return 'Please enter a valid email address';
    return null;
  }

  // ── Domain validation ──────────────────────────────────────────────────────

  /// Common email provider domains that users frequently misspell.
  static const _commonProviders = {
    'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
    'icloud.com', 'live.com', 'aol.com', 'protonmail.com',
    'proton.me', 'mail.com', 'zoho.com', 'yandex.com',
  };

  /// Known misspellings of common providers → correct spelling.
  static const _typoMap = {
    'gmial.com': 'gmail.com', 'gmai.com': 'gmail.com',
    'gamil.com': 'gmail.com', 'gmal.com': 'gmail.com',
    'gmaiil.com': 'gmail.com', 'gmail.con': 'gmail.com',
    'gmail.comm': 'gmail.com', 'gmail.cpm': 'gmail.com',
    'gnail.com': 'gmail.com',
    'yahho.com': 'yahoo.com', 'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com', 'yahoo.con': 'yahoo.com',
    'outlok.com': 'outlook.com', 'outloo.com': 'outlook.com',
    'hotmai.com': 'hotmail.com', 'hotmal.com': 'hotmail.com',
    'hotnail.com': 'hotmail.com', 'hotmail.con': 'hotmail.com',
    'icloud.con': 'icloud.com', 'iclou.com': 'icloud.com',
    'live.con': 'live.com',
  };

  /// Returns a correction suggestion if the domain looks like a typo
  /// of a common provider, or null if it looks fine.
  String? _checkDomainTypo(String domain) {
    final lower = domain.toLowerCase();
    // 1. Exact typo match
    if (_typoMap.containsKey(lower)) {
      return _typoMap[lower]!;
    }
    // 2. Levenshtein distance check against common providers
    //    If edit distance is 1 or 2 and the domain is not a known provider,
    //    suggest the closest match.
    if (_commonProviders.contains(lower)) return null;
    for (final provider in _commonProviders) {
      final dist = _editDistance(lower, provider);
      if (dist == 1) return provider;
    }
    return null;
  }

  /// Minimum edit distance between two strings (Levenshtein).
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) dp[i][0] = i;
    for (int j = 0; j <= b.length; j++) dp[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

  /// Checks whether the domain has valid MX (mail exchange) DNS records.
  /// Uses Google's public DNS-over-HTTPS API.
  Future<bool> _domainHasMxRecords(String domain) async {
    try {
      final uri = Uri.parse(
        'https://dns.google/resolve?name=$domain&type=MX',
      );
      final response = await HttpClient().getUrl(uri);
      final body = await response.close();
      final jsonString = await body.transform(const Utf8Decoder()).join();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final answer = decoded['Answer'] as List<dynamic>?;
      return answer != null && answer.isNotEmpty;
    } catch (_) {
      return true; // If DNS check fails, don't block the user
    }
  }

  // ── Password strength checks ──────────────────────────────────────────────

  bool get _hasMinLength   => _passwordCtrl.text.length >= 8;
  bool get _hasUppercase   => _passwordCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase   => _passwordCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit       => _passwordCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar => _passwordCtrl.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]'));

  bool get _allPasswordRulesMet =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasDigit && _hasSpecialChar;

  Future<void> _onContinue() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_allPasswordRulesMet) {
      setState(() => _errorMessage = 'Password does not meet all requirements.');
      return;
    }

    // ── Domain validation ──────────────────────────────────────────────────────
    // 1. Check for typos of common providers (synchronous, instant feedback)
    final domain = _emailCtrl.text.trim().split('@').last;
    final typoSuggestion = _checkDomainTypo(domain);
    if (typoSuggestion != null) {
      setState(() => _errorMessage =
          'Did you mean $typoSuggestion? "$domain" looks like a typo.');
      return;
    }

    // 2. Async MX record check for non-common domains
    if (!_commonProviders.contains(domain.toLowerCase())) {
      setState(() => _validatingDomain = true);
      final hasMx = await _domainHasMxRecords(domain);
      if (!mounted) return;
      setState(() => _validatingDomain = false);

      if (!hasMx) {
        setState(() => _errorMessage =
            'Please enter a valid email address — the domain cannot receive mail.');
        return;
      }
    }

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
        email       : _emailCtrl.text.trim(),
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
      body: Stack(
        children: [
          const _PageBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(onBack: () => Navigator.of(context).pop()),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SignupProgressBar(currentStep: 0),
                              const SizedBox(height: 16),

                              // Heading
                              Text(
                                'Create your account',
                                style: GoogleFonts.bodoniModa(
                                  fontSize: 30, fontWeight: FontWeight.w700,
                                  color: _textHeading, letterSpacing: -0.3,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'You\'re signing up as a ${widget.userType == 'CLIENT' ? 'Client' : 'Agent'}. '
                                'Enter your email and create a secure password.',
                                style: GoogleFonts.jost(
                                  fontSize: 14, fontWeight: FontWeight.w300,
                                  color: _textMuted, height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Email
                              _FieldLabel(label: 'Email address'),
                              const SizedBox(height: 6),
                              _InputField(
                                controller: _emailCtrl,
                                hint: 'you@example.com',
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.mail_outline_rounded,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 20),

                              // Password
                              _FieldLabel(label: 'Password'),
                              const SizedBox(height: 6),
                              _InputField(
                                controller: _passwordCtrl,
                                hint: 'At least 8 characters',
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock_outline_rounded,
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
                              const SizedBox(height: 12),

                              // Password strength indicators
                              _PasswordStrengthBar(
                                hasMinLength: _hasMinLength,
                                hasUppercase: _hasUppercase,
                                hasLowercase: _hasLowercase,
                                hasDigit: _hasDigit,
                                hasSpecialChar: _hasSpecialChar,
                              ),
                              const SizedBox(height: 20),

                              // Confirm password
                              _FieldLabel(label: 'Confirm password'),
                              const SizedBox(height: 6),
                              _InputField(
                                controller: _confirmCtrl,
                                hint: 'Re-enter your password',
                                obscureText: _obscureConfirm,
                                prefixIcon: Icons.lock_outline_rounded,
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

                              const SizedBox(height: 8),

                              // CTA
                              _CtaButton(
                                isLoading: _isLoading || _validatingDomain,
                                onPressed: _validatingDomain ? () {} : _onContinue,
                              ),
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
        ],
      ),
    );
  }
}

// ── Page background ──────────────────────────────────────────────────────────

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: [
          // Upper-left radial glow
          Positioned(
            top: size.height * 0.10,
            left: size.width * 0.05,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyan.withAlpha(22),
                    _cyanDim.withAlpha(8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Center glow
          Positioned(
            top: size.height * 0.18,
            left: size.width * 0.28,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_cyan.withAlpha(15), Colors.transparent],
                ),
              ),
            ),
          ),
          // Lower-right glow
          Positioned(
            bottom: size.height * 0.1,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_cyanDim.withAlpha(15), Colors.transparent],
                ),
              ),
            ),
          ),
          // Logo watermark
          Align(
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_cyan.withAlpha(20), Colors.transparent],
                    ),
                  ),
                ),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                  child: Opacity(
                    opacity: 0.06,
                    child: Image.asset(
                      'assets/images/launcher_icon.png',
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderGlass, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textHeading,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jost(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF94A3B8),
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Input field ──────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    required this.prefixIcon,
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
      style: GoogleFonts.jost(fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFFF8FAFC)),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefixIcon, size: 18, color: _textMuted),
        suffixIcon: suffixIcon,
        hintStyle: GoogleFonts.jost(fontSize: 14, color: const Color(0xFF475569)),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderGlass, width: 1),
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
        errorStyle: GoogleFonts.jost(fontSize: 12, color: _errorRed),
      ),
    );
  }
}

// ── Password strength bar ────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;

  const _PasswordStrengthBar({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGlass.withAlpha(45), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements',
            style: GoogleFonts.jost(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textSub,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _RequirementRow(met: hasMinLength, label: 'At least 8 characters'),
          const SizedBox(height: 6),
          _RequirementRow(met: hasUppercase, label: 'One uppercase letter (A–Z)'),
          const SizedBox(height: 6),
          _RequirementRow(met: hasLowercase, label: 'One lowercase letter (a–z)'),
          const SizedBox(height: 6),
          _RequirementRow(met: hasDigit, label: 'One number (0–9)'),
          const SizedBox(height: 6),
          _RequirementRow(met: hasSpecialChar, label: 'One special character (!@#\$%&*)'),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final bool met;
  final String label;

  const _RequirementRow({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: met ? _cyan.withAlpha(20) : Colors.transparent,
            border: Border.all(
              color: met ? _cyan : _textMuted.withAlpha(60),
              width: 1.5,
            ),
          ),
          child: met
              ? const Icon(Icons.check_rounded, size: 12, color: _cyan)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.jost(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: met ? _textSub : _textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _errorRed.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errorRed.withAlpha(75), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _errorRed, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w300, color: _errorRed, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ── CTA button ───────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CtaButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLoading ? 0.38 : 1.0,
      duration: const Duration(milliseconds: 260),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_ctaTop, _ctaBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: _cyan.withAlpha(50), blurRadius: 22, offset: const Offset(0, 5)),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.jost(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: Colors.white, letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}