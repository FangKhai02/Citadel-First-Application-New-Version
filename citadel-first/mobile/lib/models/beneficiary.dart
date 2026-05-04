class Beneficiary {
  final int id;
  final int appUserId;
  final String beneficiaryType; // "pre_demise" or "post_demise"
  final bool sameAsSettlor;
  final String? fullName;
  final String? nric;
  final String? idNumber;
  final String? gender;
  final DateTime? dob;
  final String? relationshipToSettlor;
  final String? residentialAddress;
  final String? mailingAddress;
  final String? email;
  final String? contactNumber;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankSwiftCode;
  final String? bankAddress;
  final double? sharePercentage;
  final String? settlorNricKey;
  final String? proofOfAddressKey;
  final String? beneficiaryIdKey;
  final String? bankStatementKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Beneficiary({
    required this.id,
    required this.appUserId,
    required this.beneficiaryType,
    this.sameAsSettlor = false,
    this.fullName,
    this.nric,
    this.idNumber,
    this.gender,
    this.dob,
    this.relationshipToSettlor,
    this.residentialAddress,
    this.mailingAddress,
    this.email,
    this.contactNumber,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankName,
    this.bankSwiftCode,
    this.bankAddress,
    this.sharePercentage,
    this.settlorNricKey,
    this.proofOfAddressKey,
    this.beneficiaryIdKey,
    this.bankStatementKey,
    this.createdAt,
    this.updatedAt,
  });

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json['id'] as int,
      appUserId: json['app_user_id'] as int,
      beneficiaryType: json['beneficiary_type'] as String,
      sameAsSettlor: json['same_as_settlor'] as bool? ?? false,
      fullName: json['full_name'] as String?,
      nric: json['nric'] as String?,
      idNumber: json['id_number'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
      relationshipToSettlor: json['relationship_to_settlor'] as String?,
      residentialAddress: json['residential_address'] as String?,
      mailingAddress: json['mailing_address'] as String?,
      email: json['email'] as String?,
      contactNumber: json['contact_number'] as String?,
      bankAccountName: json['bank_account_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankName: json['bank_name'] as String?,
      bankSwiftCode: json['bank_swift_code'] as String?,
      bankAddress: json['bank_address'] as String?,
      sharePercentage: _parseDouble(json['share_percentage']),
      settlorNricKey: json['settlor_nric_key'] as String?,
      proofOfAddressKey: json['proof_of_address_key'] as String?,
      beneficiaryIdKey: json['beneficiary_id_key'] as String?,
      bankStatementKey: json['bank_statement_key'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (beneficiaryType.isNotEmpty) 'beneficiary_type': beneficiaryType,
      'same_as_settlor': sameAsSettlor,
      if (fullName != null) 'full_name': fullName,
      if (nric != null) 'nric': nric,
      if (idNumber != null) 'id_number': idNumber,
      if (gender != null) 'gender': gender,
      if (dob != null) 'dob': dob!.toIso8601String().split('T')[0],
      if (relationshipToSettlor != null) 'relationship_to_settlor': relationshipToSettlor,
      if (residentialAddress != null) 'residential_address': residentialAddress,
      if (mailingAddress != null) 'mailing_address': mailingAddress,
      if (email != null) 'email': email,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (bankAccountName != null) 'bank_account_name': bankAccountName,
      if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
      if (bankName != null) 'bank_name': bankName,
      if (bankSwiftCode != null) 'bank_swift_code': bankSwiftCode,
      if (bankAddress != null) 'bank_address': bankAddress,
      if (sharePercentage != null) 'share_percentage': sharePercentage,
      if (settlorNricKey != null) 'settlor_nric_key': settlorNricKey,
      if (proofOfAddressKey != null) 'proof_of_address_key': proofOfAddressKey,
      if (beneficiaryIdKey != null) 'beneficiary_id_key': beneficiaryIdKey,
      if (bankStatementKey != null) 'bank_statement_key': bankStatementKey,
    };
  }

  bool get isPreDemise => beneficiaryType == 'pre_demise';
  bool get isPostDemise => beneficiaryType == 'post_demise';
}

class BeneficiaryListResult {
  final List<Beneficiary> beneficiaries;
  final bool hasPreDemise;
  final bool hasPostDemise;

  const BeneficiaryListResult({
    required this.beneficiaries,
    required this.hasPreDemise,
    required this.hasPostDemise,
  });

  factory BeneficiaryListResult.fromJson(Map<String, dynamic> json) {
    return BeneficiaryListResult(
      beneficiaries: (json['beneficiaries'] as List)
          .map((b) => Beneficiary.fromJson(b as Map<String, dynamic>))
          .toList(),
      hasPreDemise: json['has_pre_demise'] as bool,
      hasPostDemise: json['has_post_demise'] as bool,
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}