import 'dart:ui';

import 'package:equatable/equatable.dart';

class TrustPortfolio extends Equatable {
  final int id;
  final int appUserId;
  final int? trustOrderId;
  final String productName;
  final String productCode;
  final double? dividendRate;
  final int? investmentTenureMonths;
  final DateTime? maturityDate;
  final String payoutFrequency;
  final bool isProrated;
  final String status;
  final String? paymentMethod;
  final String paymentStatus;
  final int? bankDetailsId;
  final String? agreementFileName;
  final String? agreementKey;
  final DateTime? agreementDate;
  final String? clientAgreementStatus;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrustPortfolio({
    required this.id,
    required this.appUserId,
    this.trustOrderId,
    required this.productName,
    required this.productCode,
    this.dividendRate,
    this.investmentTenureMonths,
    this.maturityDate,
    this.payoutFrequency = 'QUARTERLY',
    this.isProrated = false,
    this.status = 'PENDING_PAYMENT',
    this.paymentMethod,
    this.paymentStatus = 'PENDING',
    this.bankDetailsId,
    this.agreementFileName,
    this.agreementKey,
    this.agreementDate,
    this.clientAgreementStatus,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory TrustPortfolio.fromJson(Map<String, dynamic> json) {
    return TrustPortfolio(
      id: json['id'] as int,
      appUserId: json['app_user_id'] as int,
      trustOrderId: json['trust_order_id'] as int?,
      productName: json['product_name'] as String? ?? 'CWD Trust',
      productCode: json['product_code'] as String? ?? 'CWD',
      dividendRate: _parseDouble(json['dividend_rate']),
      investmentTenureMonths: json['investment_tenure_months'] as int?,
      maturityDate: json['maturity_date'] != null
          ? DateTime.tryParse(json['maturity_date'] as String)
          : null,
      payoutFrequency: json['payout_frequency'] as String? ?? 'QUARTERLY',
      isProrated: json['is_prorated'] as bool? ?? false,
      status: json['status'] as String? ?? 'PENDING_PAYMENT',
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'PENDING',
      bankDetailsId: json['bank_details_id'] as int?,
      agreementFileName: json['agreement_file_name'] as String?,
      agreementKey: json['agreement_key'] as String?,
      agreementDate: json['agreement_date'] != null
          ? DateTime.tryParse(json['agreement_date'] as String)
          : null,
      clientAgreementStatus: json['client_agreement_status'] as String?,
      isDeleted: json['is_deleted'] == 1 || json['is_deleted'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (trustOrderId != null) 'trust_order_id': trustOrderId,
      'product_name': productName,
      'product_code': productCode,
      if (dividendRate != null) 'dividend_rate': dividendRate.toString(),
      if (investmentTenureMonths != null)
        'investment_tenure_months': investmentTenureMonths,
      if (maturityDate != null)
        'maturity_date': maturityDate!.toIso8601String().split('T')[0],
      'payout_frequency': payoutFrequency,
      'is_prorated': isProrated,
    };
  }

  String get statusLabel => switch (status) {
        'PENDING_PAYMENT' => switch (paymentStatus) {
          'IN_REVIEW' => 'In Review',
          'FAILED' => 'Payment Failed',
          _ => 'Pending Payment',
        },
        'ACTIVE' => 'Active',
        'MATURED' => 'Matured',
        'WITHDRAWN' => 'Withdrawn',
        _ => status,
      };

  Color get statusColor => switch (status) {
        'PENDING_PAYMENT' => switch (paymentStatus) {
          'IN_REVIEW' => const Color(0xFF29ABE2),
          'FAILED' => const Color(0xFFEF4444),
          _ => const Color(0xFFF59E0B),
        },
        'ACTIVE' => const Color(0xFF22C55E),
        'MATURED' => const Color(0xFF3B82F6),
        'WITHDRAWN' => const Color(0xFF64748B),
        _ => const Color(0xFF64748B),
      };

  String get paymentStatusLabel => switch (paymentStatus) {
        'PENDING' => 'Pending',
        'IN_REVIEW' => 'In Review',
        'SUCCESS' => 'Paid',
        'FAILED' => 'Failed',
        _ => paymentStatus,
      };

  Color get paymentStatusColor => switch (paymentStatus) {
        'PENDING' => const Color(0xFFF59E0B),
        'IN_REVIEW' => const Color(0xFF29ABE2),
        'SUCCESS' => const Color(0xFF22C55E),
        'FAILED' => const Color(0xFFEF4444),
        _ => const Color(0xFF64748B),
      };

  String get payoutFrequencyLabel => switch (payoutFrequency) {
        'QUARTERLY' => 'Quarterly',
        'MONTHLY' => 'Monthly',
        'SEMI_ANNUALLY' => 'Semi-Annually',
        'ANNUALLY' => 'Annually',
        _ => payoutFrequency,
      };

  String display(String? value) => value ?? 'N/A';

  String displayDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  List<Object?> get props => [id, status, paymentStatus];
}

/// Enriched portfolio detail that includes linked order + bank info.
class TrustPortfolioDetail extends Equatable {
  final TrustPortfolio portfolio;
  final double? trustAssetAmount;
  final String? trustReferenceId;
  final String? caseStatus;
  final DateTime? commencementDate;
  final DateTime? trustPeriodEndingDate;
  final String? advisorName;
  final String? advisorCode;
  final String? bankName;
  final String? bankAccountHolderName;
  final String? bankAccountNumber;
  final String? bankSwiftCode;

  const TrustPortfolioDetail({
    required this.portfolio,
    this.trustAssetAmount,
    this.trustReferenceId,
    this.caseStatus,
    this.commencementDate,
    this.trustPeriodEndingDate,
    this.advisorName,
    this.advisorCode,
    this.bankName,
    this.bankAccountHolderName,
    this.bankAccountNumber,
    this.bankSwiftCode,
  });

  factory TrustPortfolioDetail.fromJson(Map<String, dynamic> json) {
    return TrustPortfolioDetail(
      portfolio: TrustPortfolio.fromJson(
          json['portfolio'] as Map<String, dynamic>),
      trustAssetAmount: _parseDouble(json['trust_asset_amount']),
      trustReferenceId: json['trust_reference_id'] as String?,
      caseStatus: json['case_status'] as String?,
      commencementDate: json['commencement_date'] != null
          ? DateTime.tryParse(json['commencement_date'] as String)
          : null,
      trustPeriodEndingDate: json['trust_period_ending_date'] != null
          ? DateTime.tryParse(json['trust_period_ending_date'] as String)
          : null,
      advisorName: json['advisor_name'] as String?,
      advisorCode: json['advisor_code'] as String?,
      bankName: json['bank_name'] as String?,
      bankAccountHolderName: json['bank_account_holder_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankSwiftCode: json['bank_swift_code'] as String?,
    );
  }

  String get displayAssetAmount {
    if (trustAssetAmount == null) return 'N/A';
    return 'RM ${trustAssetAmount!.toStringAsFixed(2).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';
  }

  String displayDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String display(String? value) => value ?? 'N/A';

  @override
  List<Object?> get props => [portfolio.id];
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}