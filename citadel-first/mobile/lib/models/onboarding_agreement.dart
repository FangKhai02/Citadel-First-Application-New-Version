class OnboardingAgreementData {
  final String signatureBase64;
  final String fullName;
  final String icNumber;

  const OnboardingAgreementData({
    required this.signatureBase64,
    required this.fullName,
    required this.icNumber,
  });

  Map<String, dynamic> toJson() => {
        'signature_base64': signatureBase64,
        'full_name': fullName,
        'ic_number': icNumber,
      };
}