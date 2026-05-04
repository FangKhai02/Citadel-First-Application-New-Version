import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/citadel_colors.dart';
import 'dashboard_card_shell.dart';
import 'section_header.dart';

class TransactionSection extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final VoidCallback? onViewMore;

  const TransactionSection({super.key, this.transactions = const [], this.onViewMore});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return _buildEmptyState();
    }
    return _buildTransactionList();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Recent Activity'),
          DashboardCardShell(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: CitadelColors.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No transactions yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    color: CitadelColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Recent Activity', actionLabel: 'View More', onAction: onViewMore),
          Container(
            decoration: BoxDecoration(
              color: CitadelColors.primary.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CitadelColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: transactions.length > 3 ? 3 : transactions.length,
              separatorBuilder: (_, _) => Divider(
                color: CitadelColors.divider.withValues(alpha:0.3),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final t = transactions[index];
                return _TransactionRow(
                  type: t['type'] ?? 'PLACEMENT',
                  productName: t['product'] ?? 'Trust Product',
                  amount: t['amount'] ?? 'RM 0.00',
                  date: t['date'] ?? '',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final String type;
  final String productName;
  final String amount;
  final String date;

  const _TransactionRow({
    required this.type,
    required this.productName,
    required this.amount,
    required this.date,
  });

  IconData _typeIcon() {
    switch (type.toUpperCase()) {
      case 'DIVIDEND':
        return Icons.account_balance_wallet_outlined;
      case 'PLACEMENT':
        return Icons.arrow_upward_rounded;
      case 'WITHDRAWAL':
      case 'REDEMPTION':
        return Icons.arrow_downward_rounded;
      case 'ROLLOVER':
        return Icons.autorenew_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _typeColor() {
    switch (type.toUpperCase()) {
      case 'DIVIDEND':
        return CitadelColors.success;
      case 'PLACEMENT':
        return CitadelColors.primary;
      case 'WITHDRAWAL':
      case 'REDEMPTION':
        return CitadelColors.warning;
      default:
        return CitadelColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _typeColor().withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon(), color: _typeColor(), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.textPrimary,
                  ),
                ),
                Text(
                  productName,
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
          Text(
            amount,
            style: GoogleFonts.jost(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CitadelColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}