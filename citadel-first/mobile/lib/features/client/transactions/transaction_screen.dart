import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/citadel_colors.dart';
import '../../../models/transaction.dart';
import '../../../services/portfolio_service.dart';

enum _TransactionFilter { all, placement, dividend }

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final _service = PortfolioService();
  List<TransactionVo> _transactions = [];
  bool _loading = true;
  String? _error;
  _TransactionFilter _filter = _TransactionFilter.all;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final transactions = await _service.getMyTransactions();
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load transactions';
        });
      }
    }
  }

  List<TransactionVo> get _filteredTransactions {
    return switch (_filter) {
      _TransactionFilter.all => _transactions,
      _TransactionFilter.placement => _transactions
          .where((t) => t.transactionType == TransactionType.placement)
          .toList(),
      _TransactionFilter.dividend => _transactions
          .where((t) => t.transactionType == TransactionType.dividend)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: CitadelColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Transactions',
            style: GoogleFonts.jost(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CitadelColors.textPrimary)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: CitadelColors.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Filter tabs
        _FilterTabs(
          selected: _filter,
          onSelected: (f) => setState(() => _filter = f),
        ),
        // Transaction list
        Expanded(
          child: _transactions.isEmpty
              ? _buildEmpty(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  subtitle: 'Your transaction history will appear here.',
                )
              : _filteredTransactions.isEmpty
                  ? _buildEmpty(
                      icon: Icons.filter_list_off_rounded,
                      title: _filter == _TransactionFilter.placement
                          ? 'No placements'
                          : 'No dividends',
                      subtitle: _filter == _TransactionFilter.placement
                          ? 'Placement transactions will appear here once approved.'
                          : 'Dividend payments will appear here once disbursed.',
                    )
                  : RefreshIndicator(
                      color: CitadelColors.primary,
                      backgroundColor: CitadelColors.surface,
                      onRefresh: _fetchTransactions,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) => _TransactionCard(
                            transaction: _filteredTransactions[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmpty(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: CitadelColors.textMuted),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.jost(
                  fontSize: 16, color: CitadelColors.textSecondary)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: GoogleFonts.jost(
                  fontSize: 13, color: CitadelColors.textMuted),
              textAlign: TextAlign.center),
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
          Text(_error!,
              style: GoogleFonts.jost(
                  fontSize: 14, color: CitadelColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchTransactions,
            style: ElevatedButton.styleFrom(
              backgroundColor: CitadelColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Filter tabs
// ═══════════════════════════════════════════════════════════════════════

class _FilterTabs extends StatelessWidget {
  final _TransactionFilter selected;
  final ValueChanged<_TransactionFilter> onSelected;

  const _FilterTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: CitadelColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CitadelColors.border),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _tab('All', _TransactionFilter.all),
            _tab('Placements', _TransactionFilter.placement),
            _tab('Dividends', _TransactionFilter.dividend),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, _TransactionFilter filter) {
    final isActive = filter == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? CitadelColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.jost(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? Colors.white : CitadelColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Transaction card
// ═══════════════════════════════════════════════════════════════════════

class _TransactionCard extends StatelessWidget {
  final TransactionVo transaction;
  const _TransactionCard({required this.transaction});

  IconData _typeIcon() => switch (transaction.transactionType) {
        TransactionType.dividend => Icons.trending_up_rounded,
        TransactionType.placement => Icons.arrow_upward_rounded,
        TransactionType.withdrawal => Icons.arrow_downward_rounded,
        TransactionType.redemption => Icons.arrow_downward_rounded,
        TransactionType.rollover => Icons.autorenew_rounded,
        TransactionType.reallocation => Icons.swap_horiz_rounded,
      };

  Color _typeColor() => switch (transaction.transactionType) {
        TransactionType.dividend => CitadelColors.success,
        TransactionType.placement => CitadelColors.primary,
        TransactionType.withdrawal => CitadelColors.warning,
        TransactionType.redemption => CitadelColors.warning,
        TransactionType.rollover => CitadelColors.textSecondary,
        TransactionType.reallocation => CitadelColors.textSecondary,
      };

  Color _amountColor() => switch (transaction.transactionType) {
        TransactionType.dividend => CitadelColors.success,
        TransactionType.withdrawal => CitadelColors.warning,
        TransactionType.redemption => CitadelColors.warning,
        _ => CitadelColors.textPrimary,
      };

  String _amountPrefix() => switch (transaction.transactionType) {
        TransactionType.dividend => '+',
        TransactionType.withdrawal => '-',
        TransactionType.redemption => '-',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final color = _typeColor();

    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(), color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.transactionType.label,
                      style: GoogleFonts.jost(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CitadelColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                      '${transaction.productName} • ${transaction.displayDate}',
                      style: GoogleFonts.jost(
                          fontSize: 12, color: CitadelColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_amountPrefix()}${transaction.displayAmount}',
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _amountColor(),
                  ),
                ),
                if (transaction.status != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: transaction.status == 'SUCCESS' ||
                              transaction.status == 'PAID'
                          ? CitadelColors.success.withValues(alpha: 0.15)
                          : CitadelColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(transaction.statusLabel,
                        style: GoogleFonts.jost(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: transaction.status == 'SUCCESS' ||
                                  transaction.status == 'PAID'
                              ? CitadelColors.success
                              : CitadelColors.warning,
                        )),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}