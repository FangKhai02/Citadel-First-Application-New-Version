import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/document_upload.dart';
import '../widgets/signup_progress_bar.dart' show SignupProgressBar;
import 'package:citadel_first/core/theme/citadel_colors.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────────
const _successGreen = Color(0xFF22C55E);

class VerificationResultScreen extends StatefulWidget {
  final bool isMatch;
  final String? errorMessage;
  final DocumentUploadResult docUploadResult;
  final VoidCallback onContinue;
  final VoidCallback onRetry;

  const VerificationResultScreen({
    super.key,
    required this.isMatch,
    required this.docUploadResult,
    this.errorMessage,
    required this.onContinue,
    required this.onRetry,
  });

  @override
  State<VerificationResultScreen> createState() =>
      _VerificationResultScreenState();
}

class _VerificationResultScreenState extends State<VerificationResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.isMatch;
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                      if (!isSuccess) _TopBar(onBack: () => Navigator.of(context).pop()),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(24, isSuccess ? 60 : 0, 24, 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SignupProgressBar(currentStep: 3),
                            const SizedBox(height: 28),

                            // Result icon with scale animation
                            Center(
                              child: ScaleTransition(
                                scale: _iconScale,
                                child: _ResultIcon(isSuccess: isSuccess),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Title
                            Center(
                              child: Text(
                                isSuccess
                                    ? 'Identity Verified'
                                    : 'Verification Failed',
                                style: GoogleFonts.bodoniModa(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: CitadelColors.textPrimary,
                                  letterSpacing: -0.3,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Description
                            Center(
                              child: Text(
                                isSuccess
                                    ? 'Your identity has been verified successfully. Please log in to continue with your application.'
                                    : (widget.errorMessage ??
                                        'Your selfie does not match your ID photo.'),
                                style: GoogleFonts.jost(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: CitadelColors.textBody,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Error detail card (failure only)
                            if (!isSuccess) ...[
                              _ErrorDetailCard(
                                message: widget.errorMessage ??
                                    'Your selfie does not match your ID photo.',
                              ),
                              const SizedBox(height: 12),
                              _TipsCard(),
                              const SizedBox(height: 32),
                            ] else
                              const SizedBox(height: 32),

                            // CTA buttons
                            if (isSuccess) ...[
                              _GradientButton(
                                label: 'Continue',
                                icon: Icons.arrow_forward_rounded,
                                onPressed: widget.onContinue,
                              ),
                            ] else ...[
                              _GradientButton(
                                label: 'Try Again',
                                icon: Icons.refresh_rounded,
                                onPressed: widget.onRetry,
                              ),
                            ],
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
    ),
    );
  }
}

// ── Result icon ──────────────────────────────────────────────────────────────

class _ResultIcon extends StatelessWidget {
  final bool isSuccess;
  const _ResultIcon({required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? _successGreen : CitadelColors.error;
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(20),
        border: Border.all(color: color.withAlpha(80), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(30),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        isSuccess ? Icons.check_rounded : Icons.close_rounded,
        color: color,
        size: 42,
      ),
    );
  }
}

// ── Error detail card ────────────────────────────────────────────────────────

class _ErrorDetailCard extends StatelessWidget {
  final String message;
  const _ErrorDetailCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CitadelColors.error.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CitadelColors.error.withAlpha(75), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CitadelColors.error.withAlpha(15),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: CitadelColors.error.withAlpha(40), width: 1),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: CitadelColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Face Mismatch',
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: CitadelColors.textBody,
                    height: 1.5,
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

// ── Tips card ────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tips = [
      'Ensure your face is clearly visible',
      'Take the selfie in a well-lit area',
      'Remove sunglasses or face coverings',
      'Hold your phone at eye level',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CitadelColors.border.withAlpha(45), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CitadelColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: CitadelColors.primary.withAlpha(40), width: 1),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: CitadelColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Tips for a Better Selfie',
                style: GoogleFonts.jost(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CitadelColors.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 16, color: CitadelColors.primary.withAlpha(180)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip,
                    style: GoogleFonts.jost(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: CitadelColors.textBody,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Gradient button ──────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
          boxShadow: [
            BoxShadow(
              color: CitadelColors.primary.withAlpha(50),
              blurRadius: 22,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.jost(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 17, color: Colors.white),
            ],
          ),
        ),
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

// ── Page background ──────────────────────────────────────────────────────────

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