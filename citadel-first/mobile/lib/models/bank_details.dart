import 'package:equatable/equatable.dart';

class BankDetails extends Equatable {
  final int id;
  final int? appUserId;
  final String? bankName;
  final String? accountHolderName;
  final String? accountNumber;
  final String? bankAddress;
  final String? postcode;
  final String? city;
  final String? state;
  final String? country;
  final String? swiftCode;
  final String? bankAccountProofKey;
  final bool? isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BankDetails({
    required this.id,
    this.appUserId,
    this.bankName,
    this.accountHolderName,
    this.accountNumber,
    this.bankAddress,
    this.postcode,
    this.city,
    this.state,
    this.country,
    this.swiftCode,
    this.bankAccountProofKey,
    this.isDeleted,
    this.createdAt,
    this.updatedAt,
  });

  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      id: json['id'] as int,
      appUserId: json['app_user_id'] as int?,
      bankName: json['bank_name'] as String?,
      accountHolderName: json['account_holder_name'] as String?,
      accountNumber: json['account_number'] as String?,
      bankAddress: json['bank_address'] as String?,
      postcode: json['postcode'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      swiftCode: json['swift_code'] as String?,
      bankAccountProofKey: json['bank_account_proof_key'] as String?,
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
      'bank_name': bankName,
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      if (bankAddress != null) 'bank_address': bankAddress,
      if (postcode != null) 'postcode': postcode,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (swiftCode != null) 'swift_code': swiftCode,
    };
  }

  String get maskedAccountNumber {
    if (accountNumber == null) return 'N/A';
    if (accountNumber!.length <= 4) return accountNumber!;
    return '****${accountNumber!.substring(accountNumber!.length - 4)}';
  }

  String display(String? value) => value ?? 'N/A';

  bool get hasProof => bankAccountProofKey != null && bankAccountProofKey!.isNotEmpty;

  @override
  List<Object?> get props => [id];
}