import 'package:equatable/equatable.dart';

enum TransactionType {
  placement('PLACEMENT', 'Placement'),
  dividend('DIVIDEND', 'Profit Sharing'),
  withdrawal('WITHDRAWAL', 'Withdrawal'),
  rollover('ROLLOVER', 'Rollover'),
  redemption('REDEMPTION', 'Redemption'),
  reallocation('REALLOCATION', 'Reallocation');

  const TransactionType(this.value, this.label);
  final String value;
  final String label;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransactionType.placement,
    );
  }
}

class TransactionVo extends Equatable {
  final int id;
  final TransactionType transactionType;
  final String transactionTitle;
  final String productName;
  final double? amount;
  final double? trusteeFee;
  final DateTime? transactionDate;
  final String? bankName;
  final String? referenceNumber;
  final String? status;

  // Portfolio-specific fields (only for PLACEMENT type)
  final int? portfolioId;
  final int? trustOrderId;

  // Dividend-specific fields (only for DIVIDEND type)
  final int? dividendQuarter;
  final DateTime? periodStartingDate;
  final DateTime? periodEndingDate;

  const TransactionVo({
    required this.id,
    required this.transactionType,
    required this.transactionTitle,
    required this.productName,
    this.amount,
    this.trusteeFee,
    this.transactionDate,
    this.bankName,
    this.referenceNumber,
    this.status,
    this.portfolioId,
    this.trustOrderId,
    this.dividendQuarter,
    this.periodStartingDate,
    this.periodEndingDate,
  });

  factory TransactionVo.fromJson(Map<String, dynamic> json) {
    return TransactionVo(
      id: json['id'] as int,
      transactionType: TransactionType.fromString(
          json['transaction_type'] as String? ?? 'PLACEMENT'),
      transactionTitle:
          json['transaction_title'] as String? ?? 'Transaction',
      productName: json['product_name'] as String? ?? 'CWD Trust',
      amount: _parseDouble(json['amount']),
      trusteeFee: _parseDouble(json['trustee_fee']),
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'].toString())
          : null,
      bankName: json['bank_name'] as String?,
      referenceNumber: json['reference_number'] as String?,
      status: json['status'] as String?,
      portfolioId: json['portfolio_id'] as int?,
      trustOrderId: json['trust_order_id'] as int?,
      dividendQuarter: json['dividend_quarter'] as int?,
      periodStartingDate: json['period_starting_date'] != null
          ? DateTime.tryParse(json['period_starting_date'] as String)
          : null,
      periodEndingDate: json['period_ending_date'] != null
          ? DateTime.tryParse(json['period_ending_date'] as String)
          : null,
    );
  }

  String get displayAmount {
    if (amount == null) return 'N/A';
    return 'RM ${amount!.toStringAsFixed(2).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';
  }

  String get displayDate {
    if (transactionDate == null) return 'N/A';
    final d = transactionDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String display(String? value) => value ?? 'N/A';

  String get statusLabel => switch (status) {
    'PAID' => 'Disbursed',
    'SUCCESS' => 'Success',
    'PENDING' => 'Pending',
    'IN_REVIEW' => 'In Review',
    'FAILED' => 'Failed',
    _ => status ?? 'N/A',
  };

  @override
  List<Object?> get props => [id, transactionType];
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}