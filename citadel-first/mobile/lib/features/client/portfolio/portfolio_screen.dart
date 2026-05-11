import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/citadel_colors.dart';
import '../../../models/trust_portfolio.dart';
import '../../../services/portfolio_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _service = PortfolioService();
  List<TrustPortfolioDetail> _portfolios = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPortfolios();
  }

  Future<void> _fetchPortfolios() async {
    try {
      final portfolios = await _service.getMyPortfolios();
      if (mounted) {
        setState(() {
          _portfolios = portfolios;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load portfolios';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: CitadelColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'My Portfolio',
          style: GoogleFonts.jost(fontSize: 18, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CitadelColors.primary))
          : _error != null
              ? _buildError()
              : _portfolios.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: CitadelColors.primary,
                      onRefresh: _fetchPortfolios,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _portfolios.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _PortfolioCard(
                          detail: _portfolios[index],
                          onTap: () => context.push('/client/portfolio/${_portfolios[index].portfolio.id}'),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: CitadelColors.textMuted),
          const SizedBox(height: 16),
          Text('No portfolios yet', style: GoogleFonts.jost(fontSize: 16, color: CitadelColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Your portfolio will appear here after your trust order is approved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: CitadelColors.error),
          const SizedBox(height: 16),
          Text(_error!, style: GoogleFonts.jost(fontSize: 14, color: CitadelColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchPortfolios, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final TrustPortfolioDetail detail;
  final VoidCallback onTap;

  const _PortfolioCard({required this.detail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = detail.portfolio;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CitadelColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CitadelColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: CitadelColors.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CitadelColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance, color: CitadelColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.productName,
                          style: GoogleFonts.jost(fontSize: 15, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
                        if (detail.trustReferenceId != null)
                          Text('Ref: ${detail.trustReferenceId}',
                            style: GoogleFonts.jost(fontSize: 11, color: CitadelColors.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(p.statusLabel,
                      style: GoogleFonts.jost(fontSize: 11, fontWeight: FontWeight.w600, color: p.statusColor)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Investment Amount', style: GoogleFonts.jost(fontSize: 11, color: CitadelColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(detail.displayAssetAmount,
                          style: GoogleFonts.jost(fontSize: 18, fontWeight: FontWeight.w700, color: CitadelColors.textPrimary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment', style: GoogleFonts.jost(fontSize: 11, color: CitadelColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(p.paymentStatusLabel,
                          style: GoogleFonts.jost(fontSize: 14, fontWeight: FontWeight.w600, color: _paymentColor(p.paymentStatus))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: CitadelColors.textMuted, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _paymentColor(String status) => switch (status) {
    'SUCCESS' => CitadelColors.success,
    'FAILED' => CitadelColors.error,
    _ => CitadelColors.warning,
  };
}