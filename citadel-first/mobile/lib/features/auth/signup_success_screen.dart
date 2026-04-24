import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';

const _bgPrimary   = Color(0xFF0C1829);
const _cyan        = Color(0xFF29ABE2);
const _cyanDim     = Color(0xFF1A7BA8);
const _textHeading = Color(0xFFE2E8F0);
const _textBody    = Color(0xFFCBD5E1);
const _textMuted   = Color(0xFF64748B);
const _borderGlass = Color(0xFF1E3A5F);
const _successGreen = Color(0xFF22C55E);
const _ctaTop      = Color(0xFF2E6DA4);
const _ctaBottom   = Color(0xFF1B4F7A);

class SignupSuccessScreen extends StatefulWidget {
  const SignupSuccessScreen({super.key});

  @override
  State<SignupSuccessScreen> createState() => _SignupSuccessScreenState();
}

class _SignupSuccessScreenState extends State<SignupSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _iconScale;
  late final Animation<double> _cardSlide;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _fadeIn = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.1, 0.5, curve: Curves.elasticOut),
      ),
    );
    _cardSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _buttonFade = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onGoToLogin() {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgPrimary,
        body: Stack(
          children: [
            const _SuccessBackground(),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Shield icon with check ──────────────────────
                        ScaleTransition(
                          scale: _iconScale,
                          child: _SuccessShield(),
                        ),
                        const SizedBox(height: 32),

                        // ── Title ───────────────────────────────────────
                        Text(
                          'Registration Complete',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bodoniModa(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: _textHeading,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Description ─────────────────────────────────
                        Text(
                          'Your onboarding agreement has been signed and your account is ready.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jost(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: _textMuted,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Completion summary card ──────────────────────
                        AnimatedBuilder(
                          animation: _cardSlide,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _cardSlide.value),
                              child: child,
                            );
                          },
                          child: _CompletionCard(),
                        ),
                        const SizedBox(height: 40),

                        // ── Go to Login button ──────────────────────────
                        FadeTransition(
                          opacity: _buttonFade,
                          child: _GoToLoginButton(onPressed: _onGoToLogin),
                        ),
                        const SizedBox(height: 20),

                        // ── Subtle note ────────────────────────────────
                        FadeTransition(
                          opacity: _buttonFade,
                          child: Text(
                            'You will need to log in with your credentials to access your account.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jost(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: _textMuted.withAlpha(160),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
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

// ── Success shield icon ────────────────────────────────────────────────────

class _SuccessShield extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_successGreen, Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _successGreen.withAlpha(50),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_outlined,
        color: Colors.white,
        size: 48,
      ),
    );
  }
}

// ── Completion summary card ────────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGlass.withAlpha(60), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _CompletionRow(
            icon: Icons.verified_user_outlined,
            label: 'Identity Verified',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: _borderGlass.withAlpha(40), height: 1),
          ),
          _CompletionRow(
            icon: Icons.description_outlined,
            label: 'Onboarding Agreement Signed',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: _borderGlass.withAlpha(40), height: 1),
          ),
          _CompletionRow(
            icon: Icons.account_circle_outlined,
            label: 'Account Created',
          ),
        ],
      ),
    );
  }
}

class _CompletionRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompletionRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _successGreen.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _successGreen.withAlpha(40), width: 1),
          ),
          child: Icon(icon, size: 18, color: _successGreen),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.jost(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textBody,
            ),
          ),
        ),
        Icon(Icons.check_circle_rounded, size: 20, color: _successGreen),
      ],
    );
  }
}

// ── Go to Login button ─────────────────────────────────────────────────────

class _GoToLoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GoToLoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Go to Login',
                style: GoogleFonts.jost(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.login_rounded,
                size: 17,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Background decoration ──────────────────────────────────────────────────

class _SuccessBackground extends StatelessWidget {
  const _SuccessBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: size.height * 0.08,
            left: size.width * 0.1,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _successGreen.withAlpha(18),
                    _successGreen.withAlpha(6),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.15,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_cyanDim.withAlpha(12), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.35,
            left: size.width * 0.6,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_successGreen.withAlpha(10), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}