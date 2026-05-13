import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../../models/document_upload.dart';
import '../../../services/document_upload_service.dart';
import '../widgets/signup_progress_bar.dart' show SignupProgressBar;
import 'package:citadel_first/core/theme/citadel_colors.dart';

// ── Brand tokens — Liquid Glass Dark (Citadel Navy) ──────────────────────────

class DocumentUploadScreen extends StatefulWidget {
  final void Function(DocumentUploadResult result) onDocumentCaptured;

  const DocumentUploadScreen({super.key, required this.onDocumentCaptured});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen>
    with SingleTickerProviderStateMixin {
  final _svc = DocumentUploadService();
  final _picker = ImagePicker();

  DocumentType _selectedType = DocumentType.mykad;
  XFile? _frontImage;
  XFile? _backImage;
  bool _isUploading = false;
  String? _error;
  bool _dropdownExpanded = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      body: Stack(
        children: [
          const _PageBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(onBack: () => Navigator.of(context).pop()),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SignupProgressBar(currentStep: 3),
                            const SizedBox(height: 16),

                            Text(
                              'Upload Your ID',
                              style: GoogleFonts.bodoniModa(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: CitadelColors.textPrimary,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Select your document type and capture both sides.',
                              style: GoogleFonts.jost(
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                color: CitadelColors.textMuted,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Document type dropdown selector
                            _DocumentTypeDropdown(
                              selectedType: _selectedType,
                              expanded: _dropdownExpanded,
                              onToggle: () => setState(() {
                                _dropdownExpanded = !_dropdownExpanded;
                              }),
                              onSelect: (type) => setState(() {
                                _selectedType = type;
                                _frontImage = null;
                                _backImage = null;
                                _error = null;
                                _dropdownExpanded = false;
                              }),
                            ),

                            const SizedBox(height: 28),

                            // Capture section header
                            _SectionHeader(
                              title: _selectedType.requiresBackCapture
                                  ? 'Capture Both Sides'
                                  : 'Capture Document',
                              subtitle: _selectedType.requiresBackCapture
                                  ? 'Front and back of your ID'
                                  : 'Clear photo of your ID',
                            ),

                            const SizedBox(height: 20),

                            // Front capture card
                            _CaptureCard(
                              label: 'Front Side',
                              image: _frontImage,
                              icon: _getIconForType(_selectedType),
                              onCapture: () => _pickImage(side: 'front'),
                            ),

                            if (_selectedType.requiresBackCapture) ...[
                              const SizedBox(height: 16),
                              _CaptureCard(
                                label: 'Back Side',
                                image: _backImage,
                                icon: Icons.flip_outlined,
                                onCapture: () => _pickImage(side: 'back'),
                              ),
                            ],

                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              _ErrorBanner(message: _error!),
                            ],

                            const SizedBox(height: 40),

                            _CtaButton(
                              enabled: _canSubmit && !_isUploading,
                              isLoading: _isUploading,
                              onPressed: _onSubmit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(DocumentType type) {
    return switch (type) {
      DocumentType.mykad    => Icons.badge_outlined,
      DocumentType.passport => Icons.flight_outlined,
      DocumentType.mytentera => Icons.shield_outlined,
    };
  }

  bool get _canSubmit {
    if (_selectedType.requiresBackCapture) {
      return _frontImage != null && _backImage != null;
    }
    return _frontImage != null;
  }

  Future<void> _pickImage({required String side}) async {
    // Capture screen size before any async gap so context is safe.
    final screenSize = MediaQuery.of(context).size;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A2D47),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SourcePickerSheet(
        onCamera: () => Navigator.pop(context, ImageSource.camera),
        onGallery: () => Navigator.pop(context, ImageSource.gallery),
      ),
    );
    if (source == null) return;
    if (!mounted) return;

    if (source == ImageSource.camera) {
      // Use custom camera
      final XFile? captured = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _CameraScreen(
            onCaptured: (file) {
              Navigator.pop(context, file);
            },
          ),
        ),
      );
      if (captured == null) return;

      // Crop the image to exactly the frame region so the card thumbnail
      // shows only what was inside the boundary box.
      final cropped = await _cropToFrame(captured, screenSize);

      setState(() {
        if (side == 'front') {
          _frontImage = cropped;
        } else {
          _backImage = cropped;
        }
        _error = null;
      });
    } else {
      // Gallery - simple pick without crop
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;
      setState(() {
        if (side == 'front') {
          _frontImage = picked;
        } else {
          _backImage = picked;
        }
        _error = null;
      });
    }
  }

  /// Crops [original] to exactly the region that was inside the on-screen
  /// boundary frame, using the same geometry constants as [_DocumentFrameOverlay].
  static Future<XFile> _cropToFrame(XFile original, Size screenSize) async {
    final bytes = await File(original.path).readAsBytes();

    // decodeImage auto-applies EXIF orientation so the decoded image is
    // always portrait-upright regardless of how the sensor stored it.
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    final imgW = decoded.width.toDouble();
    final imgH = decoded.height.toDouble();

    // Reproduce the BoxFit.cover scaling that the camera preview uses.
    // The preview SizedBox has logical size (previewH × previewW) after the
    // portrait swap, but after decodeImage the pixel dimensions already
    // reflect the upright portrait size, so we can use them directly.
    final scaleX = screenSize.width / imgW;
    final scaleY = screenSize.height / imgH;
    final coverScale = math.max(scaleX, scaleY);

    // How much of the image is visible on-screen (in image pixels).
    final visW = screenSize.width / coverScale;
    final visH = screenSize.height / coverScale;

    // Offset from the image edge to the visible region (centred crop).
    final visOriginX = (imgW - visW) / 2;
    final visOriginY = (imgH - visH) / 2;

    // Frame geometry — must match _DocumentFrameOverlay exactly.
    const aspectRatio = 1.586;
    final frameWScreen = screenSize.width * 0.82;
    final frameHScreen = frameWScreen / aspectRatio;
    final frameLeftScreen = (screenSize.width - frameWScreen) / 2;
    final frameTopScreen = (screenSize.height - frameHScreen) / 2 - 20;

    // Convert frame screen coords → image pixel coords.
    final cropX = (visOriginX + frameLeftScreen / coverScale).round();
    final cropY = (visOriginY + frameTopScreen / coverScale).round();
    final cropW = (frameWScreen / coverScale).round();
    final cropH = (frameHScreen / coverScale).round();

    // Clamp to image bounds.
    final safeX = cropX.clamp(0, decoded.width - 1);
    final safeY = cropY.clamp(0, decoded.height - 1);
    final safeW = cropW.clamp(1, decoded.width - safeX);
    final safeH = cropH.clamp(1, decoded.height - safeY);

    final cropped = img.copyCrop(
      decoded,
      x: safeX,
      y: safeY,
      width: safeW,
      height: safeH,
    );

    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/id_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(outPath).writeAsBytes(img.encodeJpg(cropped, quality: 90));

    return XFile(outPath);
  }

  Future<void> _onSubmit() async {
    if (!_canSubmit) return;
    setState(() => _isUploading = true);

    try {
      String frontKey;
      String? backKey;

      final frontPresigned = await _svc.getPresignedUrl(
        filename: '${DateTime.now().millisecondsSinceEpoch}_front_${_selectedType.apiValue}.jpg',
      );
      await _svc.uploadFileToS3(File(_frontImage!.path), frontPresigned.uploadUrl);
      frontKey = frontPresigned.key;

      if (_backImage != null) {
        final backPresigned = await _svc.getPresignedUrl(
          filename: '${DateTime.now().millisecondsSinceEpoch}_back_${_selectedType.apiValue}.jpg',
        );
        await _svc.uploadFileToS3(File(_backImage!.path), backPresigned.uploadUrl);
        backKey = backPresigned.key;
      }

      await _svc.submitDocumentKeys(
        docType: _selectedType,
        frontImageKey: frontKey,
        backImageKey: backKey,
      );

      final ocr = await _svc.runOcr(docType: _selectedType, imageKey: frontKey);

      if (!mounted) return;

      widget.onDocumentCaptured(DocumentUploadResult(
        docType: _selectedType,
        frontImageKey: frontKey,
        backImageKey: backKey,
        ocrResult: ocr,
        frontLocalPath: _frontImage!.path,
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

// ── Document type dropdown selector ─────────────────────────────────────────────

class _DocumentTypeDropdown extends StatelessWidget {
  final DocumentType selectedType;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(DocumentType) onSelect;

  const _DocumentTypeDropdown({
    required this.selectedType,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document Type',
          style: GoogleFonts.jost(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CitadelColors.textBody,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        // Main dropdown button
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: expanded ? CitadelColors.primary : CitadelColors.border,
                width: expanded ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: CitadelColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: CitadelColors.primary.withAlpha(40), width: 1),
                  ),
                  child: Icon(
                    _getIcon(selectedType),
                    color: CitadelColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedType.label,
                        style: GoogleFonts.jost(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CitadelColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedType.description,
                        style: GoogleFonts.jost(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: CitadelColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: expanded ? CitadelColors.primary : CitadelColors.textMuted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Dropdown options
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: expanded
              ? _buildDropdownOptions()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  IconData _getIcon(DocumentType type) {
    return switch (type) {
      DocumentType.mykad    => Icons.badge_outlined,
      DocumentType.passport => Icons.flight_outlined,
      DocumentType.mytentera => Icons.shield_outlined,
    };
  }

  Widget _buildDropdownOptions() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CitadelColors.border.withAlpha(60), width: 1),
          ),
          child: Column(
            children: DocumentType.values.map((type) {
              final isSelected = type == selectedType;
              return GestureDetector(
                onTap: () => onSelect(type),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? CitadelColors.primary.withAlpha(12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CitadelColors.primary.withAlpha(20)
                              : CitadelColors.primary.withAlpha(8),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _getIcon(type),
                          color: isSelected ? CitadelColors.primary : CitadelColors.textMuted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.label,
                              style: GoogleFonts.jost(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? CitadelColors.textPrimary : CitadelColors.textBody,
                              ),
                            ),
                            Text(
                              type.description,
                              style: GoogleFonts.jost(
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                                color: CitadelColors.textBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: CitadelColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: CitadelColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.jost(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CitadelColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.jost(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: CitadelColors.textBody,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Capture card ───────────────────────────────────────────────────────────────

class _CaptureCard extends StatelessWidget {
  final String label;
  final XFile? image;
  final IconData icon;
  final VoidCallback onCapture;

  const _CaptureCard({
    required this.label,
    required this.image,
    required this.icon,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCapture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: image != null
              ? CitadelColors.primary.withAlpha(8)
              : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: image != null ? CitadelColors.primary.withAlpha(90) : CitadelColors.border,
            width: image != null ? 1.5 : 1,
          ),
        ),
        child: image != null ? _capturedState() : _emptyState(),
      ),
    );
  }

  // Compact row shown before photo is taken.
  Widget _emptyState() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        child: Row(
          children: [
            // ID-card silhouette — communicates the expected document shape
            Container(
              width: 52,
              height: 36,
              decoration: BoxDecoration(
                color: CitadelColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: CitadelColors.primary.withAlpha(60), width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: CitadelColors.primary.withAlpha(180), size: 16),
                  const SizedBox(height: 2),
                  Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: CitadelColors.primary.withAlpha(50),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Label & instruction
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.jost(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CitadelColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Tap to photograph',
                    style: GoogleFonts.jost(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: CitadelColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Camera action pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: CitadelColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CitadelColors.primary.withAlpha(50), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined, color: CitadelColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Capture',
                    style: GoogleFonts.jost(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CitadelColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Thumbnail shown after photo is taken.
  Widget _capturedState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        children: [
          // Thumbnail — use contain so the cropped ID is always fully visible
          SizedBox(
            height: 118,
            width: double.infinity,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withAlpha(15),
                BlendMode.srcATop,
              ),
              child: Image.file(
                File(image!.path),
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Bottom gradient for button legibility
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 44,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(140), Colors.transparent],
                ),
              ),
            ),
          ),
          // Label badge — top-left
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(110),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 11, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Green check — top-right
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            ),
          ),
          // Retake pill — bottom-right
          Positioned(
            right: 10,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: CitadelColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: CitadelColors.primary.withAlpha(70),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 11, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Retake',
                    style: GoogleFonts.jost(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Source picker sheet ────────────────────────────────────────────────────────

class _SourcePickerSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _SourcePickerSheet({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CitadelColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Source',
              style: GoogleFonts.jost(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CitadelColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _SheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              onTap: onCamera,
            ),
            const SizedBox(height: 10),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: onGallery,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CitadelColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: CitadelColors.primary, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.jost(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CitadelColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jost(fontSize: 12, color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared background ──────────────────────────────────────────────────────────

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: size.height * 0.10,
            left: size.width * 0.05,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CitadelColors.primary.withAlpha(22),
                    CitadelColors.primaryDark.withAlpha(8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [CitadelColors.primaryDark.withAlpha(15), Colors.transparent],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [CitadelColors.primary.withAlpha(15), Colors.transparent],
                    ),
                  ),
                ),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                  child: Opacity(
                    opacity: 0.06,
                    child: Image.asset(
                      'assets/images/launcher_icon.png',
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CitadelColors.border, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: CitadelColors.textPrimary,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Camera screen ─────────────────────────────────────────────────────────

class _CameraScreen extends StatefulWidget {
  final void Function(XFile file) onCaptured;

  const _CameraScreen({required this.onCaptured});

  @override
  State<_CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<_CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  String? _error;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _error = 'No cameras available');
        return;
      }

      final backCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      setState(() => _error = 'Failed to initialize camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile image = await _controller!.takePicture();
      widget.onCaptured(image);
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview - fills entire screen
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize!.height,
                  height: _controller!.value.previewSize!.width,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else if (_error != null)
            Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF29ABE2)),
            ),

          // Document boundary frame overlay
          if (_isInitialized)
            const Positioned.fill(child: _DocumentFrameOverlay()),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(180), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Align your ID within the frame',
                    style: GoogleFonts.jost(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24, top: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(180), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isInitialized && !_isCapturing ? _captureImage : null,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey : Colors.white,
                        ),
                        child: _isCapturing
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0C1829),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Document frame overlay ────────────────────────────────────────────────────

class _DocumentFrameOverlay extends StatefulWidget {
  const _DocumentFrameOverlay();

  @override
  State<_DocumentFrameOverlay> createState() => _DocumentFrameOverlayState();
}

class _DocumentFrameOverlayState extends State<_DocumentFrameOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanCtrl;
  late final Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Standard ID card aspect ratio: 85.6 × 53.98 mm → ~1.586:1
        const aspectRatio = 1.586;
        final frameW = w * 0.82;
        final frameH = frameW / aspectRatio;
        final frameLeft = (w - frameW) / 2;
        final frameTop = (h - frameH) / 2 - 20;
        final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameW, frameH);

        return Stack(
          children: [
            AnimatedBuilder(
              animation: _scanAnim,
              builder: (_, _) => CustomPaint(
                size: Size(w, h),
                painter: _FramePainter(
                  frameRect: frameRect,
                  scanProgress: _scanAnim.value,
                ),
              ),
            ),
            // "Fit your document here" hint below the frame
            Positioned(
              top: frameRect.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Fit your ID card within the frame',
                    style: GoogleFonts.jost(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FramePainter extends CustomPainter {
  final Rect frameRect;
  final double scanProgress;

  const _FramePainter({required this.frameRect, required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    // Darkened overlay outside the frame cutout
    final overlayPaint = Paint()..color = Colors.black.withAlpha(150);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(14)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Subtle frame border
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(14)),
      Paint()
        ..color = const Color(0xFF29ABE2).withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Corner brackets
    final cp = Paint()
      ..color = const Color(0xFF29ABE2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const arm = 22.0;
    const r = 14.0;
    final l = frameRect.left;
    final t = frameRect.top;
    final rr = frameRect.right;
    final b = frameRect.bottom;

    // Top-left
    canvas.drawArc(Rect.fromLTWH(l, t, r * 2, r * 2), math.pi, math.pi / 2, false, cp);
    canvas.drawLine(Offset(l + r, t), Offset(l + r + arm, t), cp);
    canvas.drawLine(Offset(l, t + r), Offset(l, t + r + arm), cp);

    // Top-right
    canvas.drawArc(Rect.fromLTWH(rr - r * 2, t, r * 2, r * 2), -math.pi / 2, math.pi / 2, false, cp);
    canvas.drawLine(Offset(rr - r - arm, t), Offset(rr - r, t), cp);
    canvas.drawLine(Offset(rr, t + r), Offset(rr, t + r + arm), cp);

    // Bottom-left
    canvas.drawArc(Rect.fromLTWH(l, b - r * 2, r * 2, r * 2), math.pi / 2, math.pi / 2, false, cp);
    canvas.drawLine(Offset(l + r, b), Offset(l + r + arm, b), cp);
    canvas.drawLine(Offset(l, b - r - arm), Offset(l, b - r), cp);

    // Bottom-right
    canvas.drawArc(Rect.fromLTWH(rr - r * 2, b - r * 2, r * 2, r * 2), 0, math.pi / 2, false, cp);
    canvas.drawLine(Offset(rr - r - arm, b), Offset(rr - r, b), cp);
    canvas.drawLine(Offset(rr, b - r - arm), Offset(rr, b - r), cp);

    // Animated scan line (fades at edges)
    final scanY = frameRect.top + frameRect.height * scanProgress;
    if (scanY > frameRect.top + 2 && scanY < frameRect.bottom - 2) {
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF29ABE2).withAlpha(210),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromLTWH(frameRect.left, scanY - 1, frameRect.width, 2),
        );
      canvas.drawRect(
        Rect.fromLTWH(frameRect.left + 14, scanY - 1, frameRect.width - 28, 2),
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.scanProgress != scanProgress || old.frameRect != frameRect;
}

// ── CTA button ─────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _CtaButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF2E6DA4), Color(0xFF1B4F7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade800, Colors.grey.shade900],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [BoxShadow(color: CitadelColors.primary.withAlpha(50), blurRadius: 22, offset: const Offset(0, 5))]
              : null,
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Upload',
                      style: GoogleFonts.jost(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                  ],
                ),
        ),
      ),
    );
  }
}
