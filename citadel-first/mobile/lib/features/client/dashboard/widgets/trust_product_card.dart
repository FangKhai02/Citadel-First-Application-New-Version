import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/citadel_colors.dart';
import '../../../../models/trust_order.dart';
import 'section_header.dart';

class TrustProductCard extends StatefulWidget {
  final VoidCallback? onViewDetails;
  final VoidCallback? onPurchase;

  const TrustProductCard({
    super.key,
    this.onViewDetails,
    this.onPurchase,
  });

  @override
  State<TrustProductCard> createState() => _TrustProductCardState();
}

class _TrustProductCardState extends State<TrustProductCard>
    with WidgetsBindingObserver {
  TrustOrder? _latestOrder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchTrustOrder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchTrustOrder();
    }
  }

  Future<void> _fetchTrustOrder() async {
    try {
      final api = ApiClient();
      final res = await api.get(ApiEndpoints.trustOrderMe);
      final orders = res.data['orders'] as List<dynamic>?;
      if (orders != null && orders.isNotEmpty) {
        setState(() {
          _latestOrder =
              TrustOrder.fromJson(orders.first as Map<String, dynamic>);
        });
      }
    } catch (e, st) {
      debugPrint('❌ TrustProductCard: failed to fetch orders — $e');
      debugPrint('$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Trust Products'),
          const SizedBox(height: 8),
          _buildFeaturedCard(),
          const SizedBox(height: 10),
          _latestOrder != null
              ? _buildStatusInfo()
              : _buildMetricsWithButtons(),
        ],
      ),
    );
  }

  // ── Soft Glow Featured Card ────────────────────────────────

  Widget _buildFeaturedCard() {
    final badgeColor = _latestOrder?.statusColor ?? CitadelColors.primary;

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CitadelColors.primary.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/Background Vanguard Picture.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [CitadelColors.surface, Color(0xFF112240)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Dark overlay — high transparency so image shows but text stays readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.35),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Bottom gradient overlay for text area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 70,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          // Badge
          if (_latestOrder == null)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CitadelColors.primary.withValues(alpha: 0.2),
                  border: Border.all(
                    color: CitadelColors.primary.withValues(alpha: 0.15),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'FEATURED',
                  style: GoogleFonts.jost(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.primaryLight,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          if (_latestOrder != null)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.15),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _latestOrder!.statusLabel,
                  style: GoogleFonts.jost(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          // Product name overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Citadel Wealth Diversification Trust',
                    style: GoogleFonts.jost(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Vanguard Trustee Berhad',
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Metrics + Buttons (no order) ─────────────────────────────

  Widget _buildMetricsWithButtons() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        border: Border.all(color: CitadelColors.primary.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Subtle inner glow circle
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CitadelColors.primary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom accent line
          Positioned(
            bottom: 0,
            left: 16,
            right: 16,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: CitadelColors.primary.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Metrics row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DIV. RATE',
                            style: GoogleFonts.jost(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: CitadelColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: CitadelColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '5.00% p.a.',
                                style: GoogleFonts.jost(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CitadelColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: CitadelColors.primary.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAYOUT',
                              style: GoogleFonts.jost(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: CitadelColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quarterly',
                              style: GoogleFonts.jost(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CitadelColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: CitadelColors.primary.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MIN.',
                              style: GoogleFonts.jost(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: CitadelColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RM 50,000',
                              style: GoogleFonts.jost(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CitadelColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onViewDetails,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CitadelColors.primary,
                          side: BorderSide(
                            color: CitadelColors.primary.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('View Details',
                            style: GoogleFonts.jost(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: CitadelColors.primary.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: widget.onPurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CitadelColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('Purchase',
                              style: GoogleFonts.jost(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Metrics + Status row (order exists) ──────────────────────

  Widget _buildStatusInfo() {
    final order = _latestOrder!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        border: Border.all(color: CitadelColors.primary.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Subtle inner glow circle
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CitadelColors.primary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom accent line
          Positioned(
            bottom: 0,
            left: 16,
            right: 16,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: order.statusColor.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Metrics row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DIV. RATE',
                            style: GoogleFonts.jost(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: CitadelColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: CitadelColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '5.00% p.a.',
                                style: GoogleFonts.jost(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CitadelColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: CitadelColors.primary.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAYOUT',
                              style: GoogleFonts.jost(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: CitadelColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quarterly',
                              style: GoogleFonts.jost(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CitadelColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: CitadelColors.primary.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MIN.',
                              style: GoogleFonts.jost(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: CitadelColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RM 50,000',
                              style: GoogleFonts.jost(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CitadelColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status row
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CitadelColors.primary.withValues(alpha: 0.05),
                    border: Border.all(
                      color: CitadelColors.primary.withValues(alpha: 0.08),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        order.caseStatus == 'REJECTED'
                            ? Icons.error_outline
                            : order.caseStatus == 'APPROVED' ||
                                    order.caseStatus == 'ACTIVE'
                                ? Icons.check_circle_outline
                                : Icons.hourglass_top,
                        color: order.statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.statusLabel,
                              style: GoogleFonts.jost(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: order.statusColor,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              order.caseStatus == 'APPROVED'
                                  ? 'Proceed with trust placement'
                                  : order.caseStatus == 'REJECTED'
                                      ? 'Contact support for assistance'
                                      : 'Your application is being processed',
                              style: GoogleFonts.jost(
                                fontSize: 11,
                                color: CitadelColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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