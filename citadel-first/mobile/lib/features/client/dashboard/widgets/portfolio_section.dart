import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/citadel_colors.dart';
import '../../../../models/trust_portfolio.dart';
import 'dashboard_card_shell.dart';
import 'section_header.dart';

class PortfolioSection extends StatelessWidget {
  final List<TrustPortfolioDetail> portfolios;
  final VoidCallback? onViewMore;
  final void Function(int portfolioId)? onPortfolioTap;

  const PortfolioSection({
    super.key,
    this.portfolios = const [],
    this.onViewMore,
    this.onPortfolioTap,
  });

  @override
  Widget build(BuildContext context) {
    if (portfolios.isEmpty) {
      return _buildEmptyState();
    }
    return _buildPortfolioList();
  }

  // ── Computed helpers ──────────────────────────────────────────────

  double get _totalValue => portfolios.fold<double>(
        0,
        (sum, p) => sum + (p.trustAssetAmount ?? 0),
      );

  String get _displayTotalValue {
    if (_totalValue == 0) return 'RM 0.00';
    return 'RM ${_totalValue.toStringAsFixed(2).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';
  }

  // ── Empty state (kept as-is for onboarding) ──────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Fund Holdings',
            actionLabel: 'Get Started',
            onAction: onViewMore,
          ),
          DashboardCardShell(
            child: Column(
              children: [
                CustomPaint(
                  size: const Size(double.infinity, 80),
                  painter: _ChartSilhouettePainter(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Start your first placement with us now and see your money grow',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    color: CitadelColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onViewMore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CitadelColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text('Get Started',
                            style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
                      ],
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

  // ── Populated state: soft glow banner + holding cards ──────────────

  Widget _buildPortfolioList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Fund Holdings',
            actionLabel: 'View All',
            onAction: onViewMore,
          ),
          // Soft glow total value banner
          _GlowBanner(
            totalValue: _displayTotalValue,
            holdingsCount: portfolios.length,
          ),
          const SizedBox(height: 10),
          // Individual holding cards
          ...portfolios.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GlowHoldingCard(
                detail: detail,
                onTap: () => onPortfolioTap?.call(detail.portfolio.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Glow Banner — subtle gradient with soft light effect, value at 26px
// ═══════════════════════════════════════════════════════════════════════

class _GlowBanner extends StatelessWidget {
  final String totalValue;
  final int holdingsCount;

  const _GlowBanner({
    required this.totalValue,
    required this.holdingsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CitadelColors.surface, Color(0xFF112240)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: CitadelColors.primary.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Stack(
        children: [
          // Soft glow circle in top-right
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CitadelColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Portfolio Value',
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: CitadelColors.textMuted,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: CitadelColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$holdingsCount Holdings',
                      style: GoogleFonts.jost(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: CitadelColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                totalValue,
                style: GoogleFonts.jost(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Glow Holding Card — bottom color accent, colored dot before div rate
// ═══════════════════════════════════════════════════════════════════════

class _GlowHoldingCard extends StatelessWidget {
  final TrustPortfolioDetail detail;
  final VoidCallback? onTap;

  const _GlowHoldingCard({required this.detail, this.onTap});

  @override
  Widget build(BuildContext context) {
    final portfolio = detail.portfolio;
    final statusColor = portfolio.statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CitadelColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CitadelColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            // Top row: icon + name + status badge
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_rounded,
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        portfolio.productName,
                        style: GoogleFonts.jost(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CitadelColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${portfolio.productCode}${detail.advisorName != null ? ' · ${detail.advisorName}' : ''}',
                        style: GoogleFonts.jost(
                          fontSize: 11,
                          color: CitadelColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    portfolio.statusLabel,
                    style: GoogleFonts.jost(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom row: Investment amount + div rate + payout + chevron
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Investment amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Investment',
                        style: GoogleFonts.jost(
                          fontSize: 10,
                          color: CitadelColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.displayAssetAmount,
                        style: GoogleFonts.jost(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CitadelColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Div rate + payout stacked on right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (portfolio.dividendRate != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Div. Rate',
                            style: GoogleFonts.jost(fontSize: 10, color: CitadelColors.textMuted),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${portfolio.dividendRate!.toStringAsFixed(2)}%',
                            style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.success),
                          ),
                        ],
                      ),
                    if (portfolio.dividendRate != null)
                      const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Payout',
                          style: GoogleFonts.jost(fontSize: 10, color: CitadelColors.textMuted),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          portfolio.payoutFrequencyLabel,
                          style: GoogleFonts.jost(fontSize: 12, fontWeight: FontWeight.w500, color: CitadelColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: CitadelColors.textMuted, size: 18),
              ],
            ),

            // Bottom status color accent line
            const SizedBox(height: 10),
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Decorative chart silhouette painter (empty state)
// ═══════════════════════════════════════════════════════════════════════

class _ChartSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CitadelColors.textMuted.withValues(alpha: 0.25)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = CitadelColors.primary.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(0, h * 0.85);
    path.lineTo(w * 0.15, h * 0.65);
    path.lineTo(w * 0.3, h * 0.75);
    path.lineTo(w * 0.45, h * 0.4);
    path.lineTo(w * 0.6, h * 0.55);
    path.lineTo(w * 0.75, h * 0.2);
    path.lineTo(w * 0.9, h * 0.3);
    path.lineTo(w, h * 0.1);

    // Fill area under the line
    final fillPath = Path.from(path);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw the line
    canvas.drawPath(path, paint);

    // Draw dots at key points
    final dotPaint = Paint()
      ..color = CitadelColors.primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final dots = [
      Offset(w * 0.3, h * 0.75),
      Offset(w * 0.6, h * 0.55),
      Offset(w * 0.9, h * 0.3)
    ];
    for (final dot in dots) {
      canvas.drawCircle(dot, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}