import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/citadel_colors.dart';
import 'dashboard_card_shell.dart';

class BeneficiaryProgressData {
  final bool hasPreDemise;
  final bool hasPostDemise;
  final int preCount;
  final int postCount;
  final double preTotalShare;
  final double postTotalShare;

  const BeneficiaryProgressData({
    this.hasPreDemise = false,
    this.hasPostDemise = false,
    this.preCount = 0,
    this.postCount = 0,
    this.preTotalShare = 0,
    this.postTotalShare = 0,
  });

  bool get preComplete => hasPreDemise && (preTotalShare - 100).abs() < 0.01;
  bool get postComplete => hasPostDemise && (postTotalShare - 100).abs() < 0.01;
  int get completedSteps => (preComplete ? 1 : 0) + (postComplete ? 1 : 0);
  double get overallPercent =>
      ((preTotalShare.clamp(0, 100) + postTotalShare.clamp(0, 100)) / 2)
          .clamp(0, 100);

  factory BeneficiaryProgressData.fromApiResponse(Map<String, dynamic> json) {
    final list = (json['beneficiaries'] as List?) ?? [];
    final hasPre = json['has_pre_demise'] as bool? ?? false;
    final hasPost = json['has_post_demise'] as bool? ?? false;

    double preTotal = 0;
    double postTotal = 0;
    int preCount = 0;
    int postCount = 0;

    for (final b in list) {
      final type = b['beneficiary_type'] as String? ?? '';
      final share = _parseDouble(b['share_percentage']);
      if (type == 'pre_demise') {
        preCount++;
        preTotal += share;
      } else if (type == 'post_demise') {
        postCount++;
        postTotal += share;
      }
    }

    return BeneficiaryProgressData(
      hasPreDemise: hasPre,
      hasPostDemise: hasPost,
      preCount: preCount,
      postCount: postCount,
      preTotalShare: preTotal,
      postTotalShare: postTotal,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

class BeneficiaryProgressSection extends StatelessWidget {
  final BeneficiaryProgressData data;
  final VoidCallback onSetUp;

  const BeneficiaryProgressSection({
    super.key,
    required this.data,
    required this.onSetUp,
  });

  @override
  Widget build(BuildContext context) {
    if (data.completedSteps == 2) return const SizedBox.shrink();

    final preFrac = (data.preTotalShare / 100).clamp(0.0, 1.0);
    final postFrac = (data.postTotalShare / 100).clamp(0.0, 1.0);

    return DashboardCardShell(
      gradient: const LinearGradient(
        colors: [CitadelColors.surfaceLight, CitadelColors.surface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: CitadelColors.primary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CitadelColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: CitadelColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beneficiary Setup',
                      style: GoogleFonts.jost(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CitadelColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${data.overallPercent.toStringAsFixed(0)}% overall completed',
                      style: GoogleFonts.jost(
                        fontSize: 12,
                        color: CitadelColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Overall percentage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: data.overallPercent >= 100
                      ? CitadelColors.success.withValues(alpha: 0.15)
                      : CitadelColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data.overallPercent.toStringAsFixed(0)}%',
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: data.overallPercent >= 100
                        ? CitadelColors.success
                        : CitadelColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Segmented progress bar (Pre + Post halves)
          _SegmentedProgressBar(preFraction: preFrac, postFraction: postFrac),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SegmentLabel(
                  label: 'Pre-Demise',
                  percent: data.preTotalShare,
                  isComplete: data.preComplete,
                  color: CitadelColors.primary,
                ),
              ),
              Expanded(
                child: _SegmentLabel(
                  label: 'Post-Demise',
                  percent: data.postTotalShare,
                  isComplete: data.postComplete,
                  color: CitadelColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pre-Demise row
          _ProgressRow(
            icon: Icons.person_outline_rounded,
            iconColor: CitadelColors.primary,
            iconBgColor: CitadelColors.primary.withValues(alpha: 0.12),
            label: 'Pre-Demise',
            count: data.preCount,
            maxCount: 2,
            sharePercent: data.preTotalShare,
            isComplete: data.preComplete,
          ),
          const SizedBox(height: 14),

          // Post-Demise row
          _ProgressRow(
            icon: Icons.group_outlined,
            iconColor: CitadelColors.warning,
            iconBgColor: CitadelColors.warning.withValues(alpha: 0.12),
            label: 'Post-Demise',
            count: data.postCount,
            maxCount: 5,
            sharePercent: data.postTotalShare,
            isComplete: data.postComplete,
          ),
          const SizedBox(height: 20),

          // CTA button
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
                style: GoogleFonts.jost(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedProgressBar extends StatelessWidget {
  final double preFraction;
  final double postFraction;

  const _SegmentedProgressBar({
    required this.preFraction,
    required this.postFraction,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            // Pre-demise half
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: CitadelColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: preFraction,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: preFraction >= 1.0
                            ? CitadelColors.success
                            : CitadelColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Container(width: 2, color: CitadelColors.background),
            // Post-demise half
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: CitadelColors.warning.withValues(alpha: 0.12),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: postFraction,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: postFraction >= 1.0
                            ? CitadelColors.success
                            : CitadelColors.warning,
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

class _SegmentLabel extends StatelessWidget {
  final String label;
  final double percent;
  final bool isComplete;
  final Color color;

  const _SegmentLabel({
    required this.label,
    required this.percent,
    required this.isComplete,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isComplete) ...[
          const Icon(Icons.check_circle_rounded,
              color: CitadelColors.success, size: 14),
          const SizedBox(width: 4),
        ] else ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: GoogleFonts.jost(
            fontSize: 11,
            fontWeight: isComplete ? FontWeight.w600 : FontWeight.w400,
            color: isComplete ? CitadelColors.success : CitadelColors.textMuted,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${percent.clamp(0, 100).toStringAsFixed(0)}%',
          style: GoogleFonts.jost(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isComplete ? CitadelColors.success : color,
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final int count;
  final int maxCount;
  final double sharePercent;
  final bool isComplete;

  const _ProgressRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.count,
    required this.maxCount,
    required this.sharePercent,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (sharePercent / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CitadelColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isComplete
              ? CitadelColors.success.withValues(alpha: 0.3)
              : CitadelColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count of $maxCount added  |  ${sharePercent.toStringAsFixed(0)}% allocated',
                  style: GoogleFonts.jost(
                    fontSize: 11,
                    color: CitadelColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: CitadelColors.textMuted.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isComplete ? CitadelColors.success : iconColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isComplete)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle_rounded,
                  color: CitadelColors.success, size: 20),
            ),
        ],
      ),
    );
  }
}