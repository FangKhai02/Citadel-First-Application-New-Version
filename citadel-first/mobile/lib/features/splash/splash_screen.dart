import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/auth/auth_state.dart';

// Brand tokens — kept in sync with login_screen.dart
const _kBgDeep    = Color(0xFF080D14); // Near-OLED black
const _kBgMid     = Color(0xFF0D1B2A); // Brand dark navy
const _kCyan      = Color(0xFF29ABE2); // Citadel brand cyan
const _kGlowBlue  = Color(0xFF1A4A6E); // Ambient glow tint

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _dotsCtrl;

  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _glowPulse;

  bool _minDelayDone = false;
  AuthState? _pendingState;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );

    // Breathing glow — continuous 2 s loop
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // Staggered dots — 1.4 s loop
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _entryCtrl.forward();

    // Fire auth check after animation has started
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) context.read<AuthBloc>().add(const AuthCheckRequested());
    });

    // Minimum 3-second splash display
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _minDelayDone = true);
      if (_pendingState != null) _navigate(_pendingState!);
    });
  }

  void _navigate(AuthState state) {
    if (state is AuthAuthenticated) {
      final route =
          state.userType == 'AGENT' ? '/agent/dashboard' : '/client/dashboard';
      context.go(route);
    } else if (state is AuthUnauthenticated) {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _glowCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          if (_minDelayDone) {
            _navigate(state);
          } else {
            _pendingState = state;
          }
        }
      },
      child: Scaffold(
        backgroundColor: _kBgDeep,
        body: Stack(
          children: [
            // Animated ambient background glow
            _AmbientBackground(pulse: _glowPulse),

            // Foreground content
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _entryCtrl,
                        builder: (context, child) => Opacity(
                          opacity: _fadeIn.value,
                          child: Transform.translate(
                            offset: Offset(0, _slideUp.value),
                            child: child,
                          ),
                        ),
                        child: _BrandCenter(glowPulse: _glowPulse),
                      ),
                    ),
                  ),

                  // Staggered dot loader
                  Padding(
                    padding: const EdgeInsets.only(bottom: 56),
                    child: _StaggeredDots(animation: _dotsCtrl),
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

// ── Animated radial glow that breathes with the logo ──────────────────────────

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 0.85,
            colors: [
              _kGlowBlue.withAlpha((pulse.value * 130).round()),
              _kBgMid.withAlpha((pulse.value * 70).round()),
              _kBgDeep,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

// ── Logo + brand text block ────────────────────────────────────────────────────

class _BrandCenter extends StatelessWidget {
  const _BrandCenter({required this.glowPulse});
  final Animation<double> glowPulse;

  @override
  Widget build(BuildContext context) {
    final ibm = GoogleFonts.ibmPlexSans;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoWithGlow(pulse: glowPulse),
        const SizedBox(height: 36),

        // App name
        Text(
          'Citadel First',
          style: ibm(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),

        // Cyan hairline divider
        Container(
          width: 44,
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, _kCyan, Colors.transparent],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tagline
        Text(
          'WEALTH MANAGEMENT PLATFORM',
          style: ibm(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: _kCyan.withAlpha(155),
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

// ── Circular logo with pulsing glow rings ─────────────────────────────────────

class _LogoWithGlow extends StatelessWidget {
  const _LogoWithGlow({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer diffuse ring
          Container(
            width: 200 + pulse.value * 18,
            height: 200 + pulse.value * 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _kCyan.withAlpha((pulse.value * 28).round()),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Inner ring
          Container(
            width: 164,
            height: 164,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _kCyan.withAlpha((pulse.value * 18).round()),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Logo container
          child!,
        ],
      ),
      child: Container(
        width: 136,
        height: 136,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(10),
          border: Border.all(
            color: _kCyan.withAlpha(55),
            width: 1,
          ),
        ),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ── Staggered 3-dot pulse loader ──────────────────────────────────────────────

class _StaggeredDots extends StatelessWidget {
  const _StaggeredDots({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset by 1/3 of the cycle
            final phase = (animation.value - i / 3.0) % 1.0;
            final t = math.sin(phase * math.pi).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Opacity(
                opacity: 0.25 + t * 0.75,
                child: Transform.scale(
                  scale: 0.65 + t * 0.55,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kCyan,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
