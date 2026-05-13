import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../widgets/signup_progress_bar.dart' show SignupProgressBar;
import 'package:citadel_first/core/theme/citadel_colors.dart';

// ── Brand tokens — Liquid Glass Dark (Citadel Navy) ──────────────────────────

class BankruptcyDeclarationScreen extends StatefulWidget {
  const BankruptcyDeclarationScreen({super.key});

  @override
  State<BankruptcyDeclarationScreen> createState() =>
      _BankruptcyDeclarationScreenState();
}

class _BankruptcyDeclarationScreenState
    extends State<BankruptcyDeclarationScreen>
    with SingleTickerProviderStateMixin {
  bool _declared    = false;
  bool _isLoading   = false;
  String? _errorMessage;

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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_declared || _isLoading) return;
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });
    try {
      await ApiClient().post(
        ApiEndpoints.bankruptcyDeclaration,
        data: {'is_not_bankrupt': true},
      );
      if (mounted) context.push('/signup/client/disclaimer');
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
      backgroundColor: CitadelColors.background,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SignupProgressBar(currentStep: 1),
                            const SizedBox(height: 16),

                            Text(
                              'Legal Declaration',
                              style: GoogleFonts.bodoniModa(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: CitadelColors.textPrimary,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Please confirm your bankruptcy status to proceed.',
                              style: GoogleFonts.jost(
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                color: CitadelColors.textMuted,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 32),

                            _DeclarationCard(
                              declared: _declared,
                              onToggle: (v) => setState(() {
                                _declared     = v;
                                _errorMessage = null;
                              }),
                            ),
                            const SizedBox(height: 14),

                            _WarningNotice(),
                            const SizedBox(height: 14),

                            if (_errorMessage != null) ...[
                              _ErrorBanner(message: _errorMessage!),
                              const SizedBox(height: 14),
                            ],

                            const SizedBox(height: 24),

                            _CtaButton(
                              enabled: _declared,
                              isLoading: _isLoading,
                              onPressed: _onContinue,
                            ),
                          ],
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

// ── Shared background ──────────────────────────────────────────────────────────

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: [
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
                    CitadelColors.primary.withAlpha(22),
                    CitadelColors.primaryDark.withAlpha(8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [CitadelColors.primaryDark.withAlpha(15), Colors.transparent],
                ),
              ),
            ),
          ),
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
                      colors: [CitadelColors.primary.withAlpha(15), Colors.transparent],
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

// ── Top bar ────────────────────────────────────────────────────────────────────

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
                border: Border.all(color: CitadelColors.border, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: CitadelColors.textPrimary,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Declaration card ───────────────────────────────────────────────────────────

class _DeclarationCard extends StatelessWidget {
  final bool declared;
  final ValueChanged<bool> onToggle;

  const _DeclarationCard({required this.declared, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!declared),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: declared ? CitadelColors.primary.withAlpha(12) : Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: declared ? CitadelColors.primary.withAlpha(120) : CitadelColors.border.withAlpha(45),
            width: declared ? 1.5 : 1,
          ),
          boxShadow: declared
              ? [BoxShadow(color: CitadelColors.primary.withAlpha(35), blurRadius: 24, offset: const Offset(0, 6))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: declared ? CitadelColors.primary.withAlpha(18) : Colors.white.withAlpha(6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: declared ? CitadelColors.primary.withAlpha(80) : CitadelColors.border.withAlpha(45),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.gavel_rounded,
                      color: declared ? CitadelColors.primary : CitadelColors.textMuted,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bankruptcy Declaration',
                      style: GoogleFonts.jost(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: declared ? CitadelColors.textPrimary : CitadelColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: declared ? CitadelColors.primary.withAlpha(25) : CitadelColors.border.withAlpha(45),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: declared ? CitadelColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: declared ? CitadelColors.primary : CitadelColors.border,
                        width: 1.5,
                      ),
                      boxShadow: declared
                          ? [BoxShadow(color: CitadelColors.primary.withAlpha(60), blurRadius: 8)]
                          : [],
                    ),
                    child: declared
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'I declare that I am NOT currently bankrupt and legally eligible to sign up.',
                      style: GoogleFonts.jost(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: declared ? CitadelColors.textPrimary : CitadelColors.textMuted,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Warning notice ─────────────────────────────────────────────────────────────

class _WarningNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CitadelColors.error.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.error.withAlpha(45), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, color: CitadelColors.error, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Note: If you are currently declared bankrupt, you are not eligible to sign up. '
              'Please contact customer support for further assistance.',
              style: GoogleFonts.jost(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: CitadelColors.error,
                height: 1.6,
              ),
            ),
          ),
        ],
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
        color: CitadelColors.error.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.error.withAlpha(75), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: CitadelColors.error, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jost(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: CitadelColors.error,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CTA button ─────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _CtaButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.38,
      duration: const Duration(milliseconds: 260),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E6DA4), Color(0xFF1B4F7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [BoxShadow(color: CitadelColors.primary.withAlpha(50), blurRadius: 22, offset: const Offset(0, 5))]
                : [],
          ),
          child: ElevatedButton(
            onPressed: (enabled && !isLoading) ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.jost(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.6,
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
