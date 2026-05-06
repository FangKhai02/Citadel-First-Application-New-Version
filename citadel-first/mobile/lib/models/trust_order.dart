import 'dart:ui';

import 'package:equatable/equatable.dart';

class TrustOrder extends Equatable {
  final int id;
  final int appUserId;
  final DateTime? dateOfTrustDeed;
  final double? trustAssetAmount;
  final String? advisorName;
  final String? advisorNric;
  final String? trustReferenceId;
  final String caseStatus;
  final String? kycStatus;
  final String? defermentRemark;
  final String? advisorCode;
  final DateTime? commencementDate;
  final DateTime? trustPeriodEndingDate;
  final DateTime? irrevocableTerminationNoticeDate;
  final DateTime? autoRenewalDate;
  final String? projectedYieldScheduleKey;
  final String? acknowledgementReceiptKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrustOrder({
    required this.id,
    required this.appUserId,
    this.dateOfTrustDeed,
    this.trustAssetAmount,
    this.advisorName,
    this.advisorNric,
    this.trustReferenceId,
    this.caseStatus = 'PENDING',
    this.kycStatus,
    this.defermentRemark,
    this.advisorCode,
    this.commencementDate,
    this.trustPeriodEndingDate,
    this.irrevocableTerminationNoticeDate,
    this.autoRenewalDate,
    this.projectedYieldScheduleKey,
    this.acknowledgementReceiptKey,
    this.createdAt,
    this.updatedAt,
  });

  factory TrustOrder.fromJson(Map<String, dynamic> json) {
    return TrustOrder(
      id: json['id'] as int,
      appUserId: json['app_user_id'] as int,
      dateOfTrustDeed: json['date_of_trust_deed'] != null
          ? DateTime.tryParse(json['date_of_trust_deed'] as String)
          : null,
      trustAssetAmount: json['trust_asset_amount'] != null
          ? double.tryParse(json['trust_asset_amount'].toString())
          : null,
      advisorName: json['advisor_name'] as String?,
      advisorNric: json['advisor_nric'] as String?,
      trustReferenceId: json['trust_reference_id'] as String?,
      caseStatus: json['case_status'] as String? ?? 'PENDING',
      kycStatus: json['kyc_status'] as String?,
      defermentRemark: json['deferment_remark'] as String?,
      advisorCode: json['advisor_code'] as String?,
      commencementDate: json['commencement_date'] != null
          ? DateTime.tryParse(json['commencement_date'] as String)
          : null,
      trustPeriodEndingDate: json['trust_period_ending_date'] != null
          ? DateTime.tryParse(json['trust_period_ending_date'] as String)
          : null,
      irrevocableTerminationNoticeDate:
          json['irrevocable_termination_notice_date'] != null
              ? DateTime.tryParse(
                  json['irrevocable_termination_notice_date'] as String)
              : null,
      autoRenewalDate: json['auto_renewal_date'] != null
          ? DateTime.tryParse(json['auto_renewal_date'] as String)
          : null,
      projectedYieldScheduleKey:
          json['projected_yield_schedule_key'] as String?,
      acknowledgementReceiptKey:
          json['acknowledgement_receipt_key'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  String get statusLabel => switch (caseStatus) {
        'PENDING' => 'Pending Review',
        'UNDER_REVIEW' => 'Under Review',
        'APPROVED' => 'Approved',
        'REJECTED' => 'Rejected',
        'ACTIVE' => 'Active',
        _ => caseStatus,
      };

  Color get statusColor => switch (caseStatus) {
        'PENDING' => const Color(0xFFF59E0B),
        'UNDER_REVIEW' => const Color(0xFF29ABE2),
        'APPROVED' => const Color(0xFF22C55E),
        'REJECTED' => const Color(0xFFEF4444),
        'ACTIVE' => const Color(0xFF22C55E),
        _ => const Color(0xFF64748B),
      };

  @override
  List<Object?> get props => [id, caseStatus];

  /// Display helper: returns value or "N/A" for null fields.
  String display(String? value) => value ?? 'N/A';

  /// Display helper: formats a DateTime or returns "N/A".
  String displayDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Display helper: formats the trust asset amount or returns "N/A".
  String get displayAssetAmount {
    if (trustAssetAmount == null) return 'N/A';
    return 'RM ${trustAssetAmount!.toStringAsFixed(2).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';
  }
}