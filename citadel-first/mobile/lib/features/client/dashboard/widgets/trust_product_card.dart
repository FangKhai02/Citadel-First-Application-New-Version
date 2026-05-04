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

class _TrustProductCardState extends State<TrustProductCard> {
  TrustOrder? _latestOrder;

  @override
  void initState() {
    super.initState();
    _fetchTrustOrder();
  }

  Future<void> _fetchTrustOrder() async {
    try {
      final api = ApiClient();
      final res = await api.get(ApiEndpoints.trustOrderMe);
      final orders = res.data['orders'] as List<dynamic>?;
      if (orders != null && orders.isNotEmpty) {
        setState(() {
          _latestOrder = TrustOrder.fromJson(orders.first as Map<String, dynamic>);
        });
      }
    } catch (e) {
      debugPrint('TrustProductCard: failed to fetch orders — $e');
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
          _buildCard(),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CitadelColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background image
            Image.asset(
              'assets/images/Vanguard Trust Fund Photo.png',
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [CitadelColors.primaryDark, CitadelColors.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Dark overlay for text readability
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Status badge (if order exists)
            if (_latestOrder != null)
              Positioned(
                top: 12,
                right: 12,
                child: _StatusBadge(order: _latestOrder!),
              ),
            // Content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Citadel Wealth\nDiversification Trust',
                      style: GoogleFonts.jost(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vanguard Trustee Berhad',
                      style: GoogleFonts.jost(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_latestOrder != null)
                      _buildStatusActions()
                    else
                      _buildDefaultActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onViewDetails,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'View Details',
              style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: widget.onPurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: CitadelColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Purchase',
              style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusActions() {
    final order = _latestOrder!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            order.caseStatus == 'REJECTED'
                ? Icons.error_outline
                : order.caseStatus == 'APPROVED' || order.caseStatus == 'ACTIVE'
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.caseStatus == 'APPROVED'
                      ? 'Proceed with trust placement'
                      : order.caseStatus == 'REJECTED'
                          ? 'Contact support for assistance'
                          : 'Your application is being processed',
                  style: GoogleFonts.jost(
                    fontSize: 11,
                    color: Colors.white70,
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

class _StatusBadge extends StatelessWidget {
  final TrustOrder order;
  const _StatusBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: order.statusColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            order.statusLabel,
            style: GoogleFonts.jost(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _statusIcon => switch (order.caseStatus) {
        'PENDING' => Icons.schedule,
        'UNDER_REVIEW' => Icons.search,
        'APPROVED' => Icons.check,
        'REJECTED' => Icons.close,
        'ACTIVE' => Icons.verified,
        _ => Icons.info_outline,
      };
}