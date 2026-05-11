import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../../../core/theme/citadel_colors.dart';
import '../../../models/trust_payment_receipt.dart';
import '../../../services/portfolio_service.dart';

class PaymentReceiptScreen extends StatefulWidget {
  final int orderId;
  final String paymentStatus;
  const PaymentReceiptScreen({super.key, required this.orderId, this.paymentStatus = 'PENDING'});

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  final _service = PortfolioService();
  List<TrustPaymentReceipt> _receipts = [];
  bool _loading = true;
  bool _uploading = false;
  bool _submitting = false;
  String? _error;
  late String _paymentStatus;

  bool get _isInReview => _paymentStatus == 'IN_REVIEW';
  bool get _isPaid => _paymentStatus == 'SUCCESS';
  bool get _isFailed => _paymentStatus == 'FAILED';
  bool get _canSubmit => _paymentStatus == 'PENDING' && _receipts.any((r) => r.isUploaded);

  @override
  void initState() {
    super.initState();
    _paymentStatus = widget.paymentStatus;
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    try {
      final receipts = await _service.getPaymentReceipts(widget.orderId);
      if (mounted) {
        setState(() {
          _receipts = receipts;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load receipts';
        });
      }
    }
  }

  Future<void> _pickAndUploadReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploading = true);

    try {
      // Step 1: Get presigned upload URL
      final uploadData = await _service.getPaymentReceiptUploadUrl(
        widget.orderId,
        fileName: file.name,
        contentType: _contentType(file.name),
      );

      // Step 2: Upload file to S3
      final bytes = await file.xFile.readAsBytes();
      await _service.uploadFileToS3(
        uploadData['upload_url']!,
        bytes,
        contentType: _contentType(file.name),
      );

      // Step 3: Find the draft receipt and confirm
      final newReceipts = await _service.getPaymentReceipts(widget.orderId);
      final draft = newReceipts.firstWhere(
        (r) => r.fileKey == uploadData['key'],
        orElse: () => throw Exception('Receipt not found after upload'),
      );

      await _service.confirmPaymentReceipt(widget.orderId, draft.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Receipt uploaded successfully',
              style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.success,
        ));
        _fetchReceipts();
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: ${e.toString()}',
              style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.error,
        ));
        // Refresh to show the receipt even if confirm failed
        _fetchReceipts();
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _contentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _submitForReview() async {
    setState(() => _submitting = true);
    try {
      await _service.submitPaymentReceipt(widget.orderId);
      if (mounted) {
        setState(() => _paymentStatus = 'IN_REVIEW');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment receipt submitted for review', style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.primary,
        ));
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: ${e.toString()}', style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: CitadelColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Payment Receipts',
            style: GoogleFonts.jost(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CitadelColors.textPrimary)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: CitadelColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: CitadelColors.error),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: GoogleFonts.jost(
                              color: CitadelColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReceipts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CitadelColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: CitadelColors.primary,
      backgroundColor: CitadelColors.surface,
      onRefresh: _fetchReceipts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status banner
          _buildStatusBanner(),
          const SizedBox(height: 16),
          // Upload zone (disabled when in review)
          _buildUploadZone(),
          const SizedBox(height: 16),
          // Section header (only show if there are receipts)
          if (_receipts.isNotEmpty) ...[
            _buildSectionHeader(),
            const SizedBox(height: 10),
          ],
          // Receipts list or empty state
          if (_receipts.isEmpty)
            _buildEmpty()
          else
            ..._receipts.map((receipt) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReceiptCard(
                receipt: receipt,
                orderId: widget.orderId,
                onDeleted: _fetchReceipts,
                canDelete: !_isInReview && !_isPaid,
              ),
            )),
          // Submit for Review button
          if (_canSubmit) ...[
            const SizedBox(height: 16),
            _buildSubmitButton(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_isPaid) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CitadelColors.success.withValues(alpha: 0.08),
          border: Border.all(color: CitadelColors.success.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: CitadelColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Verified', style: GoogleFonts.jost(
                    fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.success)),
                  const SizedBox(height: 2),
                  Text('Your payment has been verified by Vanguard', style: GoogleFonts.jost(
                    fontSize: 11, color: CitadelColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_isInReview) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CitadelColors.primary.withValues(alpha: 0.08),
          border: Border.all(color: CitadelColors.primary.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: CitadelColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('In Review', style: GoogleFonts.jost(
                    fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.primary)),
                  const SizedBox(height: 2),
                  Text('Your payment receipt has been submitted and is awaiting Vanguard verification', style: GoogleFonts.jost(
                    fontSize: 11, color: CitadelColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_isFailed) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CitadelColors.error.withValues(alpha: 0.08),
          border: Border.all(color: CitadelColors.error.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: CitadelColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Rejected', style: GoogleFonts.jost(
                    fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.error)),
                  const SizedBox(height: 2),
                  Text('Vanguard was unable to verify your payment. Please contact support.', style: GoogleFonts.jost(
                    fontSize: 11, color: CitadelColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // PENDING — default state
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CitadelColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: CitadelColors.warning.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: CitadelColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Pending', style: GoogleFonts.jost(
                  fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.warning)),
                const SizedBox(height: 2),
                Text('Upload your receipt, then submit for Vanguard review', style: GoogleFonts.jost(
                  fontSize: 11, color: CitadelColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitForReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: CitadelColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('Submit for Review', style: GoogleFonts.jost(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This will notify Vanguard that your payment receipt is ready for verification',
          style: GoogleFonts.jost(fontSize: 11, color: CitadelColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUploadZone() {
    final disabled = _isInReview || _isPaid;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled || _uploading ? null : _pickAndUploadReceipt,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(
              color: disabled
                  ? CitadelColors.border
                  : _uploading
                      ? CitadelColors.border
                      : CitadelColors.primary.withValues(alpha: 0.35),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
            color: disabled
                ? CitadelColors.surfaceLight.withValues(alpha: 0.3)
                : CitadelColors.primary.withValues(alpha: 0.03),
          ),
          child: Column(
            children: [
              if (_uploading) ...[
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: CitadelColors.primary),
                ),
                const SizedBox(height: 12),
                Text('Uploading...', style: GoogleFonts.jost(
                  fontSize: 15, fontWeight: FontWeight.w600, color: CitadelColors.primary)),
              ] else if (disabled) ...[
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: CitadelColors.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.cloud_upload_outlined, size: 26, color: CitadelColors.textMuted.withValues(alpha: 0.4)),
                ),
                const SizedBox(height: 12),
                Text('Upload Receipt', style: GoogleFonts.jost(
                  fontSize: 15, fontWeight: FontWeight.w600, color: CitadelColors.textMuted)),
                const SizedBox(height: 4),
                Text(_isInReview
                    ? 'Additional uploads disabled while under review'
                    : 'Receipt already verified', style: GoogleFonts.jost(
                  fontSize: 12, color: CitadelColors.textMuted)),
              ] else ...[
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: CitadelColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.cloud_upload_outlined, size: 26, color: CitadelColors.primary),
                ),
                const SizedBox(height: 12),
                Text('Upload Receipt', style: GoogleFonts.jost(
                  fontSize: 15, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Tap to select PDF, JPG, or PNG files', style: GoogleFonts.jost(
                  fontSize: 12, color: CitadelColors.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Uploaded Files', style: GoogleFonts.jost(
          fontSize: 14, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: CitadelColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${_receipts.length} file${_receipts.length == 1 ? '' : 's'}',
            style: GoogleFonts.jost(fontSize: 12, fontWeight: FontWeight.w600, color: CitadelColors.primary)),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: CitadelColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text('No receipts uploaded yet', style: GoogleFonts.jost(
            fontSize: 15, fontWeight: FontWeight.w500, color: CitadelColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Upload your payment receipt to verify your placement.',
            style: GoogleFonts.jost(fontSize: 12, color: CitadelColors.textMuted),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Receipt card
// ═══════════════════════════════════════════════════════════════════════

class _ReceiptCard extends StatefulWidget {
  final TrustPaymentReceipt receipt;
  final int orderId;
  final VoidCallback onDeleted;
  final bool canDelete;

  const _ReceiptCard({
    required this.receipt,
    required this.orderId,
    required this.onDeleted,
    this.canDelete = true,
  });

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard> {
  final _service = PortfolioService();
  bool _deleting = false;
  bool _viewing = false;

  IconData _fileIcon() {
    final name = widget.receipt.fileName.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    return Icons.image_rounded;
  }

  Color _statusColor() => switch (widget.receipt.uploadStatus) {
        'UPLOADED' => CitadelColors.success,
        'DRAFT' => CitadelColors.warning,
        _ => CitadelColors.textMuted,
      };

  Color _fileIconColor() {
    final name = widget.receipt.fileName.toLowerCase();
    if (name.endsWith('.pdf')) return CitadelColors.error;
    return CitadelColors.primary;
  }

  Color _fileIconBg() {
    final name = widget.receipt.fileName.toLowerCase();
    if (name.endsWith('.pdf')) return CitadelColors.error.withValues(alpha: 0.12);
    return CitadelColors.primary.withValues(alpha: 0.12);
  }

  Future<void> _viewReceipt() async {
    if (_viewing) return;
    setState(() => _viewing = true);

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: CitadelColors.primary),
        ),
      );
    }

    try {
      final downloadUrl = await _service.getPaymentReceiptDownloadUrl(widget.orderId, widget.receipt.id);

      // Download the file to a temp directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${widget.receipt.fileName}';
      await Dio().download(downloadUrl, filePath,
        options: Options(receiveTimeout: const Duration(seconds: 30)));

      // Verify the file was actually downloaded
      final file = File(filePath);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Downloaded file is empty or missing. The receipt file may no longer be available.');
      }

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Open viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ReceiptViewerScreen(
              filePath: filePath,
              fileName: widget.receipt.fileName,
            ),
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint('View receipt DioException: ${e.type} ${e.message}');
      if (mounted) {
        // Close loading dialog if open
        Navigator.of(context).pop();
        final message = e.response?.statusCode == 404
            ? 'This receipt file is no longer available. It may have been removed from storage.'
            : 'Could not download receipt. Please try again later.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message, style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.error,
        ));
      }
    } catch (e) {
      debugPrint('View receipt error: $e');
      if (mounted) {
        // Close loading dialog if open
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not view receipt. Please try again later.', style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _viewing = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CitadelColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Receipt?', style: GoogleFonts.jost(fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
        content: Text('This will permanently delete "${widget.receipt.fileName}". This action cannot be undone.',
            style: GoogleFonts.jost(color: CitadelColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.jost(color: CitadelColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.jost(color: CitadelColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _service.deletePaymentReceipt(widget.orderId, widget.receipt.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Receipt deleted', style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.success,
        ));
        widget.onDeleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete receipt: ${e.toString()}', style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // File type icon (colored by file type, not status)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _fileIconBg(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_fileIcon(), color: _fileIconColor(), size: 22),
          ),
          const SizedBox(width: 12),
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receipt.fileName,
                    style: GoogleFonts.jost(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CitadelColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                    widget.receipt.createdAt != null
                        ? 'Uploaded ${_formatDate(widget.receipt.createdAt!)}'
                        : widget.receipt.uploadStatusLabel,
                    style: GoogleFonts.jost(
                        fontSize: 12, color: CitadelColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(widget.receipt.uploadStatusLabel,
                    style: GoogleFonts.jost(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ],
            ),
          ),
          // Action buttons
          if (widget.receipt.isUploaded) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 34,
              height: 34,
              child: IconButton(
                onPressed: _viewing ? null : _viewReceipt,
                icon: _viewing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: CitadelColors.primary))
                    : const Icon(Icons.visibility_outlined, size: 18, color: CitadelColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: CitadelColors.primary.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
          if (widget.canDelete) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              onPressed: _deleting ? null : _confirmDelete,
              icon: _deleting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: CitadelColors.error))
                  : const Icon(Icons.delete_outline, size: 18, color: CitadelColors.error),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: CitadelColors.error.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Receipt Viewer (PDF / Image)
// ═══════════════════════════════════════════════════════════════════════

class _ReceiptViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const _ReceiptViewerScreen({required this.filePath, required this.fileName});

  @override
  Widget build(BuildContext context) {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: CitadelColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(fileName,
            style: GoogleFonts.jost(fontSize: 16, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: isPdf
          ? PDFView(
              filePath: filePath,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: false,
              pageFling: true,
              onError: (error) {
                debugPrint('PDF view error: $error');
              },
            )
          : Center(
              child: Image.file(
                File(filePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image_outlined, size: 48, color: CitadelColors.textMuted),
                    const SizedBox(height: 12),
                    Text('Failed to load image',
                        style: GoogleFonts.jost(color: CitadelColors.textSecondary)),
                  ],
                ),
              ),
            ),
    );
  }
}