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

class SelfieInstructionScreen extends StatefulWidget {
  final String docImageKey;
  final VoidCallback onStart;

  const SelfieInstructionScreen({super.key, required this.docImageKey, required this.onStart});

  @override
  State<SelfieInstructionScreen> createState() =>
      _SelfieInstructionScreenState();
}

class _SelfieInstructionScreenState extends State<SelfieInstructionScreen>
    with SingleTickerProviderStateMixin {
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SignupProgressBar(currentStep: 3),
                            const SizedBox(height: 16),

                            Text(
                              'Identity Verification',
                              style: GoogleFonts.bodoniModa(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: _textHeading,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'We need a selfie to verify your identity. '
                              'Please follow the instructions below for the best result.',
                              style: GoogleFonts.jost(
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                color: _textMuted,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 28),

                            _StepCard(
                              icon: Icons.face_outlined,
                              title: 'Step 1',
                              description:
                                  'Keep your face clearly visible. '
                                  'Remove sunglasses, hats, or masks.',
                            ),
                            const SizedBox(height: 10),
                            _StepCard(
                              icon: Icons.light_mode_outlined,
                              title: 'Step 2',
                              description:
                                  'Ensure good lighting on your face. '
                                  'Avoid strong backlight or shadows.',
                            ),
                            const SizedBox(height: 10),
                            _StepCard(
                              icon: Icons.center_focus_strong_outlined,
                              title: 'Step 3',
                              description:
                                  'Look straight at the camera with a '
                                  'neutral expression and hold steady.',
                            ),
                            const SizedBox(height: 44),

                            _CtaButton(onPressed: widget.onStart),
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

// ── Page background ────────────────────────────────────────────────────────────

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

// ── Step card ──────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _StepCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
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
              color: _cyan.withAlpha(15),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _cyan.withAlpha(40), width: 1),
            ),
            child: Icon(icon, color: _cyan, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textHeading,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
        ],
      ),
    );
  }
}

// ── CTA button ─────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CtaButton({required this.onPressed});

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
                'Start Verification',
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
    );
  }
}