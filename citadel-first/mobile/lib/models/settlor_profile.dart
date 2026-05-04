class SettlorProfile {
  final String? name;
  final String? identityCardNumber;
  final String? identityDocType; // MYKAD, IKAD, PASSPORT, MYTENTERA
  final String? gender;
  final DateTime? dob;
  final String? nationality;
  final String? residentialAddress;
  final String? mailingAddress;
  final bool? mailingSameAsResidential;
  final String? email;
  final String? mobileNumber;

  const SettlorProfile({
    this.name,
    this.identityCardNumber,
    this.identityDocType,
    this.gender,
    this.dob,
    this.nationality,
    this.residentialAddress,
    this.mailingAddress,
    this.mailingSameAsResidential,
    this.email,
    this.mobileNumber,
  });

  bool get isMyKadOrMyTentera =>
      identityDocType == 'MYKAD' || identityDocType == 'MYTENTERA';

  bool get isPassport => identityDocType == 'PASSPORT';

  factory SettlorProfile.fromJson(Map<String, dynamic> json) {
    return SettlorProfile(
      name: json['name'] as String?,
      identityCardNumber: json['identity_card_number'] as String?,
      identityDocType: json['identity_doc_type'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
      nationality: json['nationality'] as String?,
      residentialAddress: json['residential_address'] as String?,
      mailingAddress: json['mailing_address'] as String?,
      mailingSameAsResidential: json['mailing_same_as_residential'] as bool?,
      email: json['email'] as String?,
      mobileNumber: json['mobile_number'] as String?,
    );
  }
}