/// Data models for CRS tax residency rows.
class CrsTaxResidencyRow {
  String jurisdiction;
  String? tin;
  String? noTinReason; // "A", "B", or "C"
  String? reasonBExplanation;
  String? otherJurisdiction; // Used when jurisdiction is "Others"

  CrsTaxResidencyRow({
    this.jurisdiction = '',
    this.tin,
    this.noTinReason,
    this.reasonBExplanation,
    this.otherJurisdiction,
  });

  Map<String, dynamic> toJson() => {
        'jurisdiction': jurisdiction,
        'tin': tin,
        'no_tin_reason': noTinReason,
        'reason_b_explanation': reasonBExplanation,
        'other_jurisdiction': otherJurisdiction,
      };

  CrsTaxResidencyRow copyWith({
    String? jurisdiction,
    String? tin,
    String? noTinReason,
    String? reasonBExplanation,
    String? otherJurisdiction,
  }) =>
      CrsTaxResidencyRow(
        jurisdiction: jurisdiction ?? this.jurisdiction,
        tin: tin ?? this.tin,
        noTinReason: noTinReason ?? this.noTinReason,
        reasonBExplanation: reasonBExplanation ?? this.reasonBExplanation,
        otherJurisdiction: otherJurisdiction ?? this.otherJurisdiction,
      );
}