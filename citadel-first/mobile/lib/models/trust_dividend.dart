import 'package:equatable/equatable.dart';

class TrustDividend extends Equatable {
  final int id;
  final int trustPortfolioId;
  final String referenceNumber;
  final double dividendAmount;
  final double trusteeFeeAmount;
  final DateTime? periodStartingDate;
  final DateTime? periodEndingDate;
  final int dividendQuarter;
  final String paymentStatus;
  final DateTime? paymentDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrustDividend({
    required this.id,
    required this.trustPortfolioId,
    required this.referenceNumber,
    required this.dividendAmount,
    required this.trusteeFeeAmount,
    this.periodStartingDate,
    this.periodEndingDate,
    this.dividendQuarter = 0,
    this.paymentStatus = 'PENDING',
    this.paymentDate,
    this.createdAt,
    this.updatedAt,
  });

  factory TrustDividend.fromJson(Map<String, dynamic> json) {
    return TrustDividend(
      id: json['id'] as int,
      trustPortfolioId: json['trust_portfolio_id'] as int,
      referenceNumber: json['reference_number'] as String,
      dividendAmount: _parseDouble(json['dividend_amount']) ?? 0.0,
      trusteeFeeAmount: _parseDouble(json['trustee_fee_amount']) ?? 0.0,
      periodStartingDate: json['period_starting_date'] != null
          ? DateTime.tryParse(json['period_starting_date'] as String)
          : null,
      periodEndingDate: json['period_ending_date'] != null
          ? DateTime.tryParse(json['period_ending_date'] as String)
          : null,
      dividendQuarter: json['dividend_quarter'] as int? ?? 0,
      paymentStatus: json['payment_status'] as String? ?? 'PENDING',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  String get displayAmount {
    return 'RM ${dividendAmount.toStringAsFixed(2).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';
  }

  String get displayTrusteeFee {
    return 'RM ${trusteeFeeAmount.toStringAsFixed(2).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';
  }

  String get netAmount {
    final net = dividendAmount - trusteeFeeAmount;
    return 'RM ${net.toStringAsFixed(2).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';
  }

  String get quarterLabel => dividendQuarter > 0 ? 'Q$dividendQuarter' : '';

  String get paymentStatusLabel => switch (paymentStatus) {
        'PENDING' => 'Pending',
        'PAID' => 'Disbursed',
        _ => paymentStatus,
      };

  String displayDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  List<Object?> get props => [id, referenceNumber];
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}