import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_bloc.dart';
import '../../../core/auth/auth_event.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/citadel_colors.dart';
import 'widgets/beneficiary_progress_section.dart';
import 'widgets/greeting_bar.dart';
import 'widgets/portfolio_section.dart';
import 'widgets/side_drawer.dart';
import 'widgets/transaction_section.dart';
import 'widgets/trust_product_card.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnimations;
  bool _beneficiaryPromptShown = false;
  bool _drawerOpen = false;
  int _trustRefreshKey = 0;
  BeneficiaryProgressData _beneficiaryProgress = const BeneficiaryProgressData();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimations = List.generate(5, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(
            (i * 0.1).clamp(0.0, 0.8),
            ((i * 0.1) + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowBeneficiaryPrompt();
      _fetchBeneficiaryProgress();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchBeneficiaryProgress() async {
    try {
      final api = ApiClient();
      final res = await api.get(ApiEndpoints.beneficiaries);
      if (mounted) {
        setState(() {
          _beneficiaryProgress = BeneficiaryProgressData.fromApiResponse(res.data);
        });
      }
    } catch (_) {
      // Keep default zero-progress state — section still serves as CTA
    }
  }

  void _openDrawer() => setState(() => _drawerOpen = true);
  void _closeDrawer() => setState(() => _drawerOpen = false);

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: CitadelColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _navigateToBeneficiarySummary() async {
    await context.push('/client/beneficiary-summary');
    if (mounted) _fetchBeneficiaryProgress();
  }
  void _navigateToProfile() => context.push('/client/profile');
  void _navigateToNotifications() => context.push('/client/notifications');

  void _checkAndShowBeneficiaryPrompt() {
    final authState = context.read<AuthBloc>().state;
    final hasBeneficiaries = authState is AuthAuthenticated ? authState.hasBeneficiaries : false;
    if (!hasBeneficiaries && !_beneficiaryPromptShown && mounted) {
      _beneficiaryPromptShown = true;
      _showBeneficiaryRequiredDialog();
    }
  }

  void _showBeneficiaryRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: CitadelColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: CitadelColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: CitadelColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Beneficiary Setup Required',
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CitadelColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'In order for you to purchase any trust products, we require you to set up your beneficiaries first. This is an important step to ensure your trust arrangements are properly configured.',
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  fontSize: 14,
                  color: CitadelColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _navigateToBeneficiarySummary();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CitadelColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.jost(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final userName = authState is AuthAuthenticated ? (authState.name ?? 'Client') : 'Client';
    final hasNotifications = authState is AuthAuthenticated ? authState.unreadNotificationCount > 0 : false;
    final showProgressSection = _beneficiaryProgress.completedSteps < 2;

    return Scaffold(
      backgroundColor: CitadelColors.background,
      body: Stack(
        children: [
          // Main content
          RefreshIndicator(
            color: CitadelColors.primary,
            backgroundColor: CitadelColors.surface,
            onRefresh: () async {
              context.read<AuthBloc>().add(const AuthCheckRequested());
              await _fetchBeneficiaryProgress();
            },
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 68),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Section 1: Beneficiary Progress (conditionally shown)
                    if (showProgressSection) ...[
                      _AnimatedSection(
                        animation: _fadeAnimations[1],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: BeneficiaryProgressSection(
                            data: _beneficiaryProgress,
                            onSetUp: _navigateToBeneficiarySummary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Section 2: Portfolio
                    _AnimatedSection(
                      animation: _fadeAnimations[2],
                      child: PortfolioSection(
                        onViewMore: () => _showComingSoon('Portfolio'),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Section 3: Trust Products
                    _AnimatedSection(
                      animation: _fadeAnimations[3],
                      child: TrustProductCard(
                        key: ValueKey('trust_product_$_trustRefreshKey'),
                        onViewDetails: () => context.push('/client/trust-product-detail'),
                        onPurchase: () async {
                          await context.push('/client/trust-purchase');
                          if (mounted) setState(() => _trustRefreshKey++);
                        },
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Section 4: Recent Activity
                    _AnimatedSection(
                      animation: _fadeAnimations[4],
                      child: TransactionSection(
                        onViewMore: () => _showComingSoon('Activity'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Sticky header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
                decoration: BoxDecoration(
                  color: CitadelColors.background.withValues(alpha: 0.85),
                  backgroundBlendMode: BlendMode.srcOver,
                ),
                child: _AnimatedSection(
                  animation: _fadeAnimations[0],
                  child: GreetingBar(
                    hasNotifications: hasNotifications,
                    onHamburgerTap: _openDrawer,
                    onNotificationTap: _navigateToNotifications,
                  ),
                ),
              ),
            ),
          ),

          // Side drawer overlay
          SideDrawerOverlay(
            isOpen: _drawerOpen,
            onClose: _closeDrawer,
            userName: userName,
            unreadNotificationCount: authState is AuthAuthenticated ? authState.unreadNotificationCount : 0,
            onNavigateProfile: () {
              _closeDrawer();
              WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToProfile());
            },
            onNavigateBeneficiaries: () {
              _closeDrawer();
              WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToBeneficiarySummary());
            },
            onNavigateNotifications: () {
              _closeDrawer();
              WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToNotifications());
            },
            onNavigatePortfolio: () {
              _closeDrawer();
              _showComingSoon('Portfolio');
            },
            onNavigateTrustProducts: () {
              _closeDrawer();
              WidgetsBinding.instance.addPostFrameCallback((_) => context.push('/client/trust-product-detail'));
            },
            onLogout: () {
              _closeDrawer();
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedSection extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _AnimatedSection({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}