import 'package:equatable/equatable.dart';

class TrustPaymentReceipt extends Equatable {
  final int id;
  final int trustPortfolioId;
  final String fileName;
  final String fileKey;
  final String uploadStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrustPaymentReceipt({
    required this.id,
    required this.trustPortfolioId,
    required this.fileName,
    required this.fileKey,
    this.uploadStatus = 'DRAFT',
    this.createdAt,
    this.updatedAt,
  });

  factory TrustPaymentReceipt.fromJson(Map<String, dynamic> json) {
    return TrustPaymentReceipt(
      id: json['id'] as int,
      trustPortfolioId: json['trust_portfolio_id'] as int,
      fileName: json['file_name'] as String,
      fileKey: json['file_key'] as String,
      uploadStatus: json['upload_status'] as String? ?? 'DRAFT',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  bool get isUploaded => uploadStatus == 'UPLOADED';
  bool get isDraft => uploadStatus == 'DRAFT';

  String get uploadStatusLabel => switch (uploadStatus) {
        'DRAFT' => 'Draft',
        'UPLOADED' => 'Uploaded',
        _ => uploadStatus,
      };

  @override
  List<Object?> get props => [id, fileKey];
}