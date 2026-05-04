import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/citadel_colors.dart';

class DocumentUploadCard extends StatefulWidget {
  final String label;
  final String? hintMessage;
  final String? s3Key;
  final ValueChanged<String?> onUploaded;

  const DocumentUploadCard({
    super.key,
    required this.label,
    this.hintMessage,
    this.s3Key,
    required this.onUploaded,
  });

  @override
  State<DocumentUploadCard> createState() => _DocumentUploadCardState();
}

class _DocumentUploadCardState extends State<DocumentUploadCard> {
  final _api = ApiClient();
  final _picker = ImagePicker();
  bool _isUploading = false;
  String? _uploadedKey;
  String? _error;

  bool get _isUploaded => _uploadedKey != null || widget.s3Key != null;

  @override
  void initState() {
    super.initState();
    _uploadedKey = widget.s3Key;
  }

  @override
  void didUpdateWidget(covariant DocumentUploadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.s3Key != oldWidget.s3Key && widget.s3Key != null) {
      _uploadedKey = widget.s3Key;
    }
  }

  Future<void> _showHintAndUpload() async {
    if (widget.hintMessage != null && !_isUploaded) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _UploadHintDialog(
          label: widget.label,
          hint: widget.hintMessage!,
        ),
      );
      if (proceed != true) return;
    }
    _pickAndUpload();
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      // Get presigned URL
      final presignedRes = await _api.post(
        ApiEndpoints.beneficiaryPresignedUrl,
        data: {
          'filename': picked.name,
          'content_type': 'image/jpeg',
        },
      );
      final uploadUrl = presignedRes.data['upload_url'] as String;
      final fileKey = presignedRes.data['key'] as String;

      // Upload to S3
      final bytes = await File(picked.path).readAsBytes();
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

      setState(() => _uploadedKey = fileKey);
      widget.onUploaded(fileKey);
    } catch (e) {
      setState(() => _error = 'Upload failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: CitadelColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _remove() {
    setState(() => _uploadedKey = null);
    widget.onUploaded(null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CitadelColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isUploaded ? CitadelColors.success : CitadelColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isUploaded
                  ? CitadelColors.success.withValues(alpha:0.15)
                  : CitadelColors.primary.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isUploading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CitadelColors.primary,
                    ),
                  )
                : Icon(
                    _isUploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                    color: _isUploaded ? CitadelColors.success : CitadelColors.primary,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CitadelColors.textPrimary,
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      color: CitadelColors.error,
                    ),
                  )
                else if (_isUploaded)
                  Text(
                    'Uploaded',
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      color: CitadelColors.success,
                    ),
                  ),
              ],
            ),
          ),
          if (_isUploaded && !_isUploading)
            IconButton(
              onPressed: _remove,
              icon: const Icon(Icons.close_rounded, size: 18, color: CitadelColors.textMuted),
              visualDensity: VisualDensity.compact,
            )
          else if (!_isUploading)
            TextButton(
              onPressed: _showHintAndUpload,
              style: TextButton.styleFrom(
                foregroundColor: CitadelColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Upload',
                style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadHintDialog extends StatelessWidget {
  final String label;
  final String hint;

  const _UploadHintDialog({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CitadelColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: CitadelColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.info_outline_rounded, color: CitadelColors.primary, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              style: GoogleFonts.jost(fontSize: 18, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CitadelColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CitadelColors.warning.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: CitadelColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hint,
                      style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textSecondary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CitadelColors.textSecondary,
                      side: const BorderSide(color: CitadelColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CitadelColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text('Continue', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}