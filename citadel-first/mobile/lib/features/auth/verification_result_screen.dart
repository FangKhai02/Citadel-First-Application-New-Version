import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/signup_progress_bar.dart' show SignupProgressBar;

// ── Brand tokens ─────────────────────────────────────────────────────────────
const _bgPrimary   = Color(0xFF0C1829);
const _cyan        = Color(0xFF29ABE2);
const _cyanDim     = Color(0xFF1A7BA8);
const _textHeading = Color(0xFFE2E8F0);
const _textBody    = Color(0xFFCBD5E1);
const _textMuted   = Color(0xFF64748B);
const _borderGlass = Color(0xFF1E3A5F);
const _successGreen = Color(0xFF22C55E);
const _errorRed    = Color(0xFFEF4444);

class VerificationResultScreen extends StatefulWidget {
  final bool isMatch;
  final double? confidence;
  final String? message;
  final VoidCallback onContinue;
  final VoidCallback onRetry;

  const VerificationResultScreen({
    super.key,
    required this.isMatch,
    this.confidence,
    this.message,
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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.isMatch;
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SignupProgressBar(currentStep: 3),
                            const SizedBox(height: 24),

                            // Result icon
                            Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSuccess
                                      ? _successGreen.withAlpha(20)
                                      : _errorRed.withAlpha(20),
                                  border: Border.all(
                                    color: isSuccess
                                        ? _successGreen.withAlpha(80)
                                        : _errorRed.withAlpha(80),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  isSuccess
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  color: isSuccess ? _successGreen : _errorRed,
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Title
                            Center(
                              child: Text(
                                isSuccess
                                    ? 'Identity Verified'
                                    : 'Verification Failed',
                                style: GoogleFonts.bodoniModa(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: _textHeading,
                                  letterSpacing: -0.3,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Description
                            Center(
                              child: Text(
                                isSuccess
                                    ? 'Your selfie has been successfully matched with your ID document. You can proceed with your application.'
                                    : (widget.message ?? 'We could not verify your identity. Please try again or contact support.'),
                                style: GoogleFonts.jost(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: _textBody,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Confidence card (if available)
                            if (widget.confidence != null) ...[
                              _ConfidenceCard(
                                confidence: widget.confidence!,
                                isMatch: isSuccess,
                              ),
                              const SizedBox(height: 32),
                            ] else
                              const SizedBox(height: 32),

                            // CTA button
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
                              const SizedBox(height: 10),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    // TODO: contact support
                                  },
                                  child: Text(
                                    'Contact Support',
                                    style: GoogleFonts.jost(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _textMuted,
                                    ),
                                  ),
                                ),
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
    );
  }
}

// ── Confidence card ──────────────────────────────────────────────────────────

class _ConfidenceCard extends StatelessWidget {
  final double confidence;
  final bool isMatch;

  const _ConfidenceCard({required this.confidence, required this.isMatch});

  @override
  Widget build(BuildContext context) {
    final percentage = (confidence * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderGlass.withAlpha(45), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isMatch ? _successGreen : _errorRed).withAlpha(15),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: (isMatch ? _successGreen : _errorRed).withAlpha(40),
                width: 1,
              ),
            ),
            child: Icon(
              isMatch ? Icons.verified_outlined : Icons.warning_amber_rounded,
              color: isMatch ? _successGreen : _errorRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Confidence',
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textHeading,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$percentage% similarity score',
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: _textBody,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$percentage%',
            style: GoogleFonts.jost(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isMatch ? _successGreen : _errorRed,
            ),
          ),
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
              color: _cyan.withAlpha(50),
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
                    _cyan.withAlpha(22),
                    _cyanDim.withAlpha(8),
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
                  colors: [_cyanDim.withAlpha(15), Colors.transparent],
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
                      colors: [_cyan.withAlpha(15), Colors.transparent],
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