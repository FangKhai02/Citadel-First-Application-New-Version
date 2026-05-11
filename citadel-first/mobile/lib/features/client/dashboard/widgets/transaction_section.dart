import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/citadel_colors.dart';
import '../../../../models/transaction.dart';
import 'dashboard_card_shell.dart';
import 'section_header.dart';

class TransactionSection extends StatelessWidget {
  final List<TransactionVo> transactions;
  final VoidCallback? onViewMore;

  const TransactionSection({
    super.key,
    this.transactions = const [],
    this.onViewMore,
  });

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
          const SectionHeader(title: 'Recent Transactions'),
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
    final display = transactions.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recent Transactions',
            actionLabel: 'View All',
            onAction: onViewMore,
          ),
          Container(
            decoration: BoxDecoration(
              color: CitadelColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CitadelColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: display.length,
              separatorBuilder: (_, _) => Divider(
                color: CitadelColors.divider.withValues(alpha: 0.3),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final t = display[index];
                return _TransactionRow(transaction: t);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final TransactionVo transaction;

  const _TransactionRow({required this.transaction});

  IconData _typeIcon() {
    return switch (transaction.transactionType) {
      TransactionType.dividend => Icons.trending_up_rounded,
      TransactionType.placement => Icons.arrow_upward_rounded,
      TransactionType.withdrawal => Icons.arrow_downward_rounded,
      TransactionType.redemption => Icons.arrow_downward_rounded,
      TransactionType.rollover => Icons.autorenew_rounded,
      TransactionType.reallocation => Icons.swap_horiz_rounded,
    };
  }

  Color _typeColor() {
    return switch (transaction.transactionType) {
      TransactionType.dividend => CitadelColors.success,
      TransactionType.placement => CitadelColors.primary,
      TransactionType.withdrawal => CitadelColors.warning,
      TransactionType.redemption => CitadelColors.warning,
      TransactionType.rollover => CitadelColors.textSecondary,
      TransactionType.reallocation => CitadelColors.textSecondary,
    };
  }

  Color _amountColor() {
    return switch (transaction.transactionType) {
      TransactionType.dividend => CitadelColors.success,
      TransactionType.withdrawal => CitadelColors.warning,
      TransactionType.redemption => CitadelColors.warning,
      _ => CitadelColors.textPrimary,
    };
  }

  String _amountPrefix() {
    return switch (transaction.transactionType) {
      TransactionType.dividend => '+',
      TransactionType.withdrawal => '-',
      TransactionType.redemption => '-',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon(), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          // Name + product + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.transactionType.label,
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${transaction.productName} • ${transaction.displayDate}',
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
          const SizedBox(width: 8),
          // Amount
          Text(
            '${_amountPrefix()}${transaction.displayAmount}',
            style: GoogleFonts.jost(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _amountColor(),
            ),
          ),
        ],
      ),
    );
  }
}