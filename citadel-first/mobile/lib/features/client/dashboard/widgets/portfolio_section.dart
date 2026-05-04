import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/citadel_colors.dart';
import 'dashboard_card_shell.dart';
import 'section_header.dart';

class PortfolioSection extends StatelessWidget {
  final List<Map<String, dynamic>> portfolios;
  final VoidCallback? onViewMore;

  const PortfolioSection({super.key, this.portfolios = const [], this.onViewMore});

  @override
  Widget build(BuildContext context) {
    if (portfolios.isEmpty) {
      return _buildEmptyState();
    }
    return _buildPortfolioList();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'My Portfolio', actionLabel: 'Get Started', onAction: onViewMore),
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
                        Text('Get Started', style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
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

  Widget _buildPortfolioList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'My Portfolio', actionLabel: 'View More', onAction: onViewMore),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: portfolios.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final p = portfolios[index];
                return _PortfolioCard(
                  productName: p['name'] ?? 'Trust Product',
                  amount: p['amount'] ?? 'RM 0.00',
                  status: p['status'] ?? 'Active',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CitadelColors.textMuted.withValues(alpha:0.25)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = CitadelColors.primary.withValues(alpha:0.06)
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
      ..color = CitadelColors.primary.withValues(alpha:0.4)
      ..style = PaintingStyle.fill;

    final dots = [Offset(w * 0.3, h * 0.75), Offset(w * 0.6, h * 0.55), Offset(w * 0.9, h * 0.3)];
    for (final dot in dots) {
      canvas.drawCircle(dot, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PortfolioCard extends StatelessWidget {
  final String productName;
  final String amount;
  final String status;

  const _PortfolioCard({
    required this.productName,
    required this.amount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      borderColor: CitadelColors.primary.withValues(alpha:0.3),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            productName,
            style: GoogleFonts.jost(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CitadelColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            amount,
            style: GoogleFonts.jost(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CitadelColors.textPrimary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CitadelColors.success.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.jost(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CitadelColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}