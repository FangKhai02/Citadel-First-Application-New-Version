import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/citadel_colors.dart';
import 'animated_progress_bar.dart';
import 'dashboard_card_shell.dart';

class BeneficiaryStatusCard extends StatelessWidget {
  final bool hasBeneficiaries;
  final VoidCallback onSetUp;
  final VoidCallback onManage;

  const BeneficiaryStatusCard({
    super.key,
    required this.hasBeneficiaries,
    required this.onSetUp,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: hasBeneficiaries
          ? _CompletedCard(key: const ValueKey('completed'), onManage: onManage)
          : _PromptCard(key: const ValueKey('prompt'), onSetUp: onSetUp),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final VoidCallback onSetUp;

  const _PromptCard({super.key, required this.onSetUp});

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      gradient: LinearGradient(
        colors: [
          CitadelColors.primary.withValues(alpha:0.12),
          CitadelColors.surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: CitadelColors.primary.withValues(alpha:0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CitadelColors.primary.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: CitadelColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Beneficiary Details Required',
                  style: GoogleFonts.jost(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You need to add both Pre-Demise and Post-Demise beneficiaries before placing trust products.',
            style: GoogleFonts.jost(
              fontSize: 14,
              color: CitadelColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              _StepLabel(label: 'Pre-Demise'),
              Spacer(),
              _StepLabel(label: 'Post-Demise'),
            ],
          ),
          const SizedBox(height: 8),
          const AnimatedProgressBar(completedSteps: 0, totalSteps: 2),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSetUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: CitadelColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Set Up Beneficiaries',
                style: GoogleFonts.jost(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String label;

  const _StepLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jost(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: CitadelColors.textMuted,
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final VoidCallback onManage;

  const _CompletedCard({super.key, required this.onManage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CitadelColors.success.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CitadelColors.success.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CitadelColors.success.withValues(alpha:0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: CitadelColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Beneficiaries Set Up',
              style: GoogleFonts.jost(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CitadelColors.success,
              ),
            ),
          ),
          TextButton(
            onPressed: onManage,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Manage',
              style: GoogleFonts.jost(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CitadelColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}