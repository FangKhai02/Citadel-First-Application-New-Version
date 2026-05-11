import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/citadel_colors.dart';

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

    return GestureDetector(
      onTap: onSetUp,
      child: Container(
        decoration: BoxDecoration(
          color: CitadelColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CitadelColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CitadelColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: CitadelColors.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete beneficiary setup',
                    style: GoogleFonts.jost(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CitadelColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Required before purchasing trust products',
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      color: CitadelColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: CitadelColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}