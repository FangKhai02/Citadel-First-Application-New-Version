import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/signup_progress_bar.dart' show SignupProgressBar;

// ── Brand tokens — Liquid Glass Dark (Citadel Navy) ──────────────────────────
const _bgPrimary    = Color(0xFF0C1829); // Citadel logo navy

const _cyan         = Color(0xFF29ABE2); // Citadel brand cyan (logo color)
const _cyanDim      = Color(0xFF1A7BA8); // dimmed cyan
const _gold         = Color(0xFFCA8A04); // Liquid Glass gold CTA
const _goldAmber    = Color(0xFFD97706); // warm amber highlight
const _textHeading  = Color(0xFFE2E8F0); // slate-200
const _textSub      = Color(0xFFCBD5E1); // slate-300
const _textMuted    = Color(0xFF64748B); // slate-500
const _borderGlass  = Color(0xFF1E3A5F); // navy glass border


const _roleClient = 'client';
const _roleAgent  = 'agent';
const _agencyCwp  = 'cwp';
const _agencyOther = 'other';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _scrollCtrl = ScrollController();

  String? _selectedRole;
  String? _selectedAgency;

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
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole   = role;
      _selectedAgency = null;
    });
    if (role == _roleAgent) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!_scrollCtrl.hasClients) return;
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  bool get _canContinue {
    if (_selectedRole == _roleClient) return true;
    if (_selectedRole == _roleAgent && _selectedAgency != null) return true;
    return false;
  }

  void _onContinue() {
    if (_selectedRole == _roleAgent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Agent registration is coming soon. Please select "I\'m a Client" to continue.',
                style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w400),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFFE67E22),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    context.push('/signup/register', extra: 'CLIENT');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Stack(
        children: [
          const _LiquidGlassBackground(),
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
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 52),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SignupProgressBar(currentStep: 0),
                            const SizedBox(height: 12),

                            _HeadingSection(),
                            const SizedBox(height: 40),

                            _RoleCard(
                              title: "I'm a Client",
                              subtitle: 'Manage investments and grow your wealth portfolio',
                              icon: Icons.person_outline_rounded,
                              selected: _selectedRole == _roleClient,
                              onTap: () => _selectRole(_roleClient),
                            ),
                            const SizedBox(height: 14),
                            _RoleCard(
                              title: "I'm an Agent",
                              subtitle: 'Serve clients and manage your agency book',
                              icon: Icons.business_center_outlined,
                              selected: _selectedRole == _roleAgent,
                              onTap: () => _selectRole(_roleAgent),
                            ),

                            AnimatedSize(
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              child: _selectedRole == _roleAgent
                                  ? _AgencySection(
                                      selected: _selectedAgency,
                                      onSelect: (v) =>
                                          setState(() => _selectedAgency = v),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 44),

                            _CtaButton(
                              label: 'Continue',
                              enabled: _canContinue,
                              onPressed: _onContinue,
                            ),

                            const SizedBox(height: 28),
                            Center(
                              child: Text(
                                '© ${DateTime.now().year} Citadel Group. All rights reserved.',
                                style: GoogleFonts.jost(
                                  fontSize: 10,
                                  color: _textMuted.withAlpha(110),
                                  letterSpacing: 0.3,
                                ),
                              ),
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

// ── Liquid Glass background ────────────────────────────────────────────────────

class _LiquidGlassBackground extends StatelessWidget {
  const _LiquidGlassBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: [
          // Outer cyan radial glow — upper center (Citadel brand color)
          Positioned(
            top: size.height * 0.10,
            left: size.width * 0.05,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyan.withAlpha(28),
                    _cyanDim.withAlpha(10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Inner bright cyan core
          Positioned(
            top: size.height * 0.18,
            left: size.width * 0.28,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyan.withAlpha(38),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Secondary deeper navy shimmer — lower right
          Positioned(
            bottom: size.height * 0.15,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyanDim.withAlpha(18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Subtle cyan floor wash
          Positioned(
            bottom: 0,
            child: Container(
              width: size.width,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _cyan.withAlpha(8),
                  ],
                ),
              ),
            ),
          ),
          // Soft glowing Citadel logo watermark — centered
          Align(
            alignment: Alignment.center,
            child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow halo around logo
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _cyan.withAlpha(20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Blurred soft logo
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                    child: Opacity(
                      opacity: 0.07,
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
                border: Border.all(
                  color: _borderGlass,
                  width: 1,
                ),
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

// ── Heading section ────────────────────────────────────────────────────────────

class _HeadingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Account',
          style: GoogleFonts.bodoniModa(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: _textHeading,
            letterSpacing: -0.3,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Select how you will be using Citadel First to personalize your experience.',
          style: GoogleFonts.jost(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: _textSub,
            height: 1.65,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ── Role selection card ────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: selected ? _cyan.withAlpha(12) : Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _cyan.withAlpha(120) : _borderGlass.withAlpha(45),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _cyan.withAlpha(35),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: selected ? _cyan.withAlpha(18) : Colors.white.withAlpha(6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? _cyan.withAlpha(80) : _borderGlass.withAlpha(45),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: selected ? _cyan : _textMuted,
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jost(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? _textHeading : _textSub,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: GoogleFonts.jost(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w300,
                      color: _textSub,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _cyan : Colors.transparent,
                border: Border.all(
                  color: selected ? _cyan : _borderGlass,
                  width: 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _cyan.withAlpha(90),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Agency section ─────────────────────────────────────────────────────────────

class _AgencySection extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _AgencySection({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_gold, _goldAmber],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withAlpha(80),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Select your agency',
                style: GoogleFonts.jost(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _textSub,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        _AgencyTile(
          title: 'CWP Agent',
          subtitle: 'Citadel Wealth Partners network',
          icon: Icons.shield_outlined,
          selected: selected == _agencyCwp,
          onTap: () => onSelect(_agencyCwp),
        ),
        const SizedBox(height: 10),
        _AgencyTile(
          title: 'Other Agency',
          subtitle: 'Independent or external agency',
          icon: Icons.groups_outlined,
          selected: selected == _agencyOther,
          onTap: () => onSelect(_agencyOther),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _AgencyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AgencyTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? _cyan.withAlpha(12) : Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _cyan.withAlpha(120) : _borderGlass.withAlpha(45),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _cyan.withAlpha(35),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? _cyan.withAlpha(18) : Colors.white.withAlpha(6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _cyan.withAlpha(80) : _borderGlass.withAlpha(45),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? _cyan : _textMuted,
              ),
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
                      color: selected ? _textHeading : _textSub,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.jost(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: _textSub,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _cyan : Colors.transparent,
                border: Border.all(
                  color: selected ? _cyan : _borderGlass,
                  width: 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _cyan.withAlpha(80),
                          blurRadius: 8,
                        )
                      ]
                    : [],
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── CTA button ─────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _CtaButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.40,
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E6DA4), Color(0xFF1B4F7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _cyan.withAlpha(55),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: _cyanDim.withAlpha(25),
                      blurRadius: 48,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
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
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
