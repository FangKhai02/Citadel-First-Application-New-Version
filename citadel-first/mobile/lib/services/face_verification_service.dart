import 'dart:io';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/face_verification.dart';

class FaceVerificationService {
  final ApiClient _client = ApiClient();

  Future<Map<String, String>> getSelfiePresignedUrl({
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    final res = await _client.post(
      ApiEndpoints.selfiePresignedUrl,
      data: {'filename': filename, 'content_type': contentType},
    );
    return {
      'upload_url': res.data['upload_url'] as String,
      'key': res.data['key'] as String,
    };
  }

  Future<String> uploadSelfieToS3(File file, String uploadUrl) async {
    final bytes = await file.readAsBytes();
    await Dio().put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {
        'Content-Type': 'image/jpeg',
        'Content-Length': bytes.length,
      }),
    );
    return uploadUrl.split('?').first.split('/').last;
  }

  Future<FaceVerificationResult> verifyFace({
    required String selfieImageKey,
    required String docImageKey,
  }) async {
    final res = await _client.post(
      ApiEndpoints.faceVerify,
      data: {
        'selfie_image_key': selfieImageKey,
        'doc_image_key': docImageKey,
      },
    );
    return FaceVerificationResult.fromJson(res.data);
  }

  Future<FaceDetectResult> detectFace({
    required String selfieImageKey,
  }) async {
    final res = await _client.post(
      ApiEndpoints.faceDetect,
      data: {'selfie_image_key': selfieImageKey},
    );
    return FaceDetectResult.fromJson(res.data);
  }
}