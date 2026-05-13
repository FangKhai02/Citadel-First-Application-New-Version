import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/signup_progress_bar.dart' show SignupProgressBar;
import 'package:citadel_first/core/theme/citadel_colors.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────────

class SelfieCaptureScreen extends StatefulWidget {
  final String docImageKey;
  final void Function(String selfieImagePath) onUpload;
  final VoidCallback onBack;

  const SelfieCaptureScreen({
    super.key,
    required this.docImageKey,
    required this.onUpload,
    required this.onBack,
  });

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;

  XFile? _capturedImage;

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
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _initCamera();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Camera unavailable. Please check permissions.';
          _isCameraReady = false;
        });
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    final file = await _cameraController!.takePicture();
    setState(() => _capturedImage = file);
  }

  void _retakePhoto() {
    setState(() => _capturedImage = null);
  }

  void _onUploadTapped() {
    if (_capturedImage == null) return;
    widget.onUpload(_capturedImage!.path);
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
                  children: [
                    _TopBar(onBack: widget.onBack),
                    Expanded(
                      child: _capturedImage != null
                          ? _buildPreview()
                          : _buildCameraView(),
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

  // ── Camera view (before capture) ──────────────────────────────────────────

  Widget _buildCameraView() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: SignupProgressBar(currentStep: 3),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Take a Selfie',
            style: GoogleFonts.bodoniModa(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: CitadelColors.textPrimary,
              letterSpacing: -0.3,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Position your face within the oval and hold steady.',
            style: GoogleFonts.jost(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: CitadelColors.textMuted,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isCameraReady && _cameraController != null)
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                )
              else if (_cameraError != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_outlined,
                            size: 48, color: CitadelColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _cameraError!,
                          style: GoogleFonts.jost(
                              fontSize: 14, color: CitadelColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: CitadelColors.primary),
                ),
              const _FaceOvalOverlay(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _CaptureButton(onCapture: _capturePhoto),
        ),
      ],
    );
  }

  // ── Confirm preview (after capture) ───────────────────────────────────────

  Widget _buildPreview() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: SignupProgressBar(currentStep: 3),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Confirm Your Selfie',
            style: GoogleFonts.bodoniModa(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: CitadelColors.textPrimary,
              letterSpacing: -0.3,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Make sure your face is clearly visible and well-lit.',
            style: GoogleFonts.jost(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: CitadelColors.textMuted,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Circular selfie preview
        Expanded(
          child: Center(
            child: _CircularSelfiePreview(imagePath: _capturedImage!.path),
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: _buildConfirmButtons(),
        ),
      ],
    );
  }

  Widget _buildConfirmButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary CTA: Upload
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E6DA4), Color(0xFF1B4F7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: CitadelColors.primary.withAlpha(50),
                  blurRadius: 22,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _onUploadTapped,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
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
                  const Icon(Icons.cloud_upload_outlined,
                      size: 17, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Secondary: Retake
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: _retakePhoto,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded,
                    size: 15, color: CitadelColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Retake Photo',
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CitadelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Circular selfie preview with glow ──────────────────────────────────────

class _CircularSelfiePreview extends StatelessWidget {
  final String imagePath;
  const _CircularSelfiePreview({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [CitadelColors.primary.withAlpha(25), Colors.transparent],
          stops: const [0.7, 1.0],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: CitadelColors.primary.withAlpha(90), width: 2),
          boxShadow: [
            BoxShadow(
              color: CitadelColors.primary.withAlpha(40),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

// ── Face oval overlay ──────────────────────────────────────────────────────────

class _FaceOvalOverlay extends StatelessWidget {
  const _FaceOvalOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FaceOvalPainter(),
      size: Size.infinite,
    );
  }
}

class _FaceOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * 0.65;
    final ovalHeight = ovalWidth * 1.35;

    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );
    final ovalPath = Path()..addOval(ovalRect);
    final cutoutPath = Path.combine(PathOperation.difference, overlayPath, ovalPath);

    canvas.drawPath(
      cutoutPath,
      Paint()..color = Colors.black.withAlpha(140),
    );

    final borderPaint = Paint()
      ..color = CitadelColors.primary.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Capture button ────────────────────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  final VoidCallback onCapture;
  const _CaptureButton({required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCapture,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: CitadelColors.primary, width: 4),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────

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

// ── Page background ────────────────────────────────────────────────────────────

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
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [CitadelColors.primary.withAlpha(18), CitadelColors.primaryDark.withAlpha(6), Colors.transparent],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [CitadelColors.primaryDark.withAlpha(12), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}