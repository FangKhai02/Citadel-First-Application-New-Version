// ignore_for_file: use_null_aware_elements
import 'dart:io';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/document_upload.dart';

class DocumentUploadService {
  final ApiClient _client = ApiClient();

  Future<PresignedUrlResponse> getPresignedUrl({
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    final res = await _client.post(
      ApiEndpoints.presignedUrl,
      data: {'filename': filename, 'content_type': contentType},
    );
    return PresignedUrlResponse.fromJson(res.data);
  }

  Future<String> uploadFileToS3(File file, String uploadUrl) async {
    final bytes = await file.readAsBytes();
    await Dio().put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': 'image/jpeg',
          'Content-Length': bytes.length,
        },
      ),
    );
    return uploadUrl.split('?').first.split('/').last;
  }

  Future<Map<String, String?>> submitDocumentKeys({
    required DocumentType docType,
    required String? frontImageKey,
    required String? backImageKey,
  }) async {
    final res = await _client.post(
      ApiEndpoints.identityDocument,
      data: {
        'doc_type': docType.apiValue,
        'front_image_key': frontImageKey,
        'back_image_key': backImageKey,
      },
    );
    return {
      'front_image_key': res.data['front_image_key'] as String?,
      'back_image_key': res.data['back_image_key'] as String?,
    };
  }

  Future<OcrResult> runOcr({
    required DocumentType docType,
    required String imageKey,
  }) async {
    final res = await _client.post(
      ApiEndpoints.ocr,
      data: {'image_key': imageKey, 'doc_type': docType.apiValue},
    );
    return OcrResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> confirmUserDetails({
    required String? name,
    required String? identityCardNumber,
    required DateTime? dob,
    required String? gender,
    required String? nationality,
    required String? address,
  }) async {
    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (identityCardNumber != null) 'identity_card_number': identityCardNumber,
      if (dob != null) 'dob': dob.toIso8601String().split('T').first,
      if (gender != null) 'gender': gender,
      if (nationality != null) 'nationality': nationality,
      if (address != null) 'address': address,
    };
    await _client.patch(
      ApiEndpoints.identityDocument,
      data: data,
    );
  }
}
