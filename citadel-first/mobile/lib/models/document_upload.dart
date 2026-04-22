enum DocumentType {
  mykad('MyKad', 'Malaysian NRIC'),
  passport('Passport', 'International Passport'),
  mytentera('MyTentera', 'Malaysian Military ID');

  final String label;
  final String description;
  const DocumentType(this.label, this.description);

  String get apiValue => name.toUpperCase();

  bool get requiresBackCapture => this == DocumentType.mykad;
}

class OcrResult {
  final String? fullName;
  final String? identityNumber;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? address;
  final double confidence;
  final String rawText;

  const OcrResult({
    this.fullName,
    this.identityNumber,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.address,
    this.confidence = 0.0,
    this.rawText = '',
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return OcrResult(
      fullName: data?['full_name'] as String?,
      identityNumber: data?['identity_number'] as String?,
      dateOfBirth: data?['date_of_birth'] != null
          ? DateTime.tryParse(data!['date_of_birth'] as String)
          : null,
      gender: data?['gender'] as String?,
      nationality: data?['nationality'] as String?,
      address: data?['address'] as String?,
      confidence: (data?['confidence'] as num?)?.toDouble() ?? 0.0,
      rawText: (data?['raw_text'] as String?) ?? '',
    );
  }
}

class DocumentUploadResult {
  final DocumentType docType;
  final String? frontImageKey;
  final String? backImageKey;
  final OcrResult? ocrResult;
  /// Local file path of the cropped front image — used for the review thumbnail.
  final String? frontLocalPath;

  const DocumentUploadResult({
    required this.docType,
    this.frontImageKey,
    this.backImageKey,
    this.ocrResult,
    this.frontLocalPath,
  });
}

class PresignedUrlResponse {
  final String uploadUrl;
  final String key;

  const PresignedUrlResponse({required this.uploadUrl, required this.key});

  factory PresignedUrlResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResponse(
      uploadUrl: json['upload_url'] as String,
      key: json['key'] as String,
    );
  }
}
