import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/citadel_colors.dart';
import 'dashboard_card_shell.dart';

class QuickActionSection extends StatelessWidget {
  final bool hasBeneficiaries;
  final VoidCallback onBeneficiaryTap;
  final VoidCallback onPortfolioTap;
  final VoidCallback onProductsTap;
  final VoidCallback onSupportTap;

  const QuickActionSection({
    super.key,
    required this.hasBeneficiaries,
    required this.onBeneficiaryTap,
    required this.onPortfolioTap,
    required this.onProductsTap,
    required this.onSupportTap,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionItem(
              icon: Icons.people_outline,
              label: hasBeneficiaries ? 'Manage\nBeneficiaries' : 'Add\nBeneficiary',
              iconColor: CitadelColors.primary,
              iconBgColor: CitadelColors.primary.withValues(alpha:0.15),
              onTap: onBeneficiaryTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'My\nPortfolio',
              iconColor: CitadelColors.success,
              iconBgColor: CitadelColors.success.withValues(alpha:0.15),
              onTap: onPortfolioTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionItem(
              icon: Icons.shield_outlined,
              label: 'Trust\nProducts',
              iconColor: CitadelColors.warning,
              iconBgColor: CitadelColors.warning.withValues(alpha:0.15),
              onTap: onProductsTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionItem(
              icon: Icons.headset_mic_outlined,
              label: 'Support',
              iconColor: CitadelColors.primaryLight,
              iconBgColor: CitadelColors.primaryLight.withValues(alpha:0.15),
              onTap: onSupportTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  State<_QuickActionItem> createState() => _QuickActionItemState();
}

class _QuickActionItemState extends State<_QuickActionItem> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.94);
  void _onTapUp(TapUpDetails _) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.jost(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: CitadelColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}