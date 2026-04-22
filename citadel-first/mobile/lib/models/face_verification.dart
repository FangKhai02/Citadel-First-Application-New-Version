class FaceVerificationResult {
  final int id;
  final int appUserId;
  final bool isMatch;
  final double confidence;
  final double? distance;
  final bool selfieFaceDetected;
  final bool docFaceDetected;
  final String message;

  const FaceVerificationResult({
    required this.id,
    required this.appUserId,
    required this.isMatch,
    required this.confidence,
    this.distance,
    required this.selfieFaceDetected,
    required this.docFaceDetected,
    required this.message,
  });

  factory FaceVerificationResult.fromJson(Map<String, dynamic> json) =>
      FaceVerificationResult(
        id: json['id'] as int,
        appUserId: json['app_user_id'] as int,
        isMatch: json['is_match'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        distance: (json['distance'] as num?)?.toDouble(),
        selfieFaceDetected: json['selfie_face_detected'] as bool,
        docFaceDetected: json['doc_face_detected'] as bool,
        message: json['message'] as String,
      );
}

class FaceDetectResult {
  final bool faceDetected;
  final int faceCount;
  final String message;

  const FaceDetectResult({
    required this.faceDetected,
    required this.faceCount,
    required this.message,
  });

  factory FaceDetectResult.fromJson(Map<String, dynamic> json) => FaceDetectResult(
        faceDetected: json['face_detected'] as bool,
        faceCount: json['face_count'] as int,
        message: json['message'] as String,
      );
}