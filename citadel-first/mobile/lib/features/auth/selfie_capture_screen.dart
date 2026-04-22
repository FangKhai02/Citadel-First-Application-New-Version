import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/face_verification_service.dart';
import 'widgets/signup_progress_bar.dart' show SignupProgressBar;

// ── Brand tokens ─────────────────────────────────────────────────────────────
const _bgPrimary   = Color(0xFF0C1829);
const _cyan        = Color(0xFF29ABE2);
const _cyanDim     = Color(0xFF1A7BA8);
const _textHeading = Color(0xFFE2E8F0);
const _textMuted   = Color(0xFF64748B);
const _borderGlass = Color(0xFF1E3A5F);

class SelfieCaptureScreen extends StatefulWidget {
  final String docImageKey;
  final VoidCallback onVerificationSuccess;
  final VoidCallback onVerificationFailed;

  const SelfieCaptureScreen({
    super.key,
    required this.docImageKey,
    required this.onVerificationSuccess,
    required this.onVerificationFailed,
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
  bool _isUploading = false;
  bool _isVerifying = false;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
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
    setState(() {
      _capturedImage = null;
      _error = null;
    });
  }

  Future<void> _confirmAndVerify() async {
    if (_capturedImage == null) return;
    final file = File(_capturedImage!.path);

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final svc = FaceVerificationService();

      // 1. Get presigned URL
      final presigned = await svc.getSelfiePresignedUrl(
        filename: 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final uploadUrl = presigned['upload_url']!;
      final selfieKey = presigned['key']!;

      // 2. Upload to S3
      await svc.uploadSelfieToS3(file, uploadUrl);

      setState(() {
        _isUploading = false;
        _isVerifying = true;
      });

      // 3. Face verification
      final result = await svc.verifyFace(
        selfieImageKey: selfieKey,
        docImageKey: widget.docImageKey,
      );

      setState(() => _isVerifying = false);

      if (result.isMatch) {
        widget.onVerificationSuccess();
      } else {
        if (!result.selfieFaceDetected) {
          setState(() => _error = 'No face detected in your selfie. Please retake.');
        } else if (!result.docFaceDetected) {
          setState(() => _error = 'No face detected in your ID document. Please contact support.');
        } else {
          setState(() => _error = 'Verification failed. Your selfie does not match your ID photo.');
        }
      }
    } catch (e) {
      debugPrint('[SelfieCapture] Verification error: $e');
      setState(() {
        _isUploading = false;
        _isVerifying = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Stack(
        children: [
          const _PageBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  _TopBar(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: _capturedImage != null
                        ? _buildPreview()
                        : _buildCameraView(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
              color: _textHeading,
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
              color: _textMuted,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Camera preview
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
                            size: 48, color: _textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _cameraError!,
                          style: GoogleFonts.jost(
                              fontSize: 14, color: _textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: _cyan),
                ),
              // Face oval overlay
              const _FaceOvalOverlay(),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ErrorBanner(message: _error!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _CaptureButton(onCapture: _capturePhoto),
        ),
      ],
    );
  }

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
              color: _textHeading,
              letterSpacing: -0.3,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cyan.withAlpha(60), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Image.file(
                  File(_capturedImage!.path),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _ErrorBanner(message: _error!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: _isUploading || _isVerifying
              ? _buildLoadingButton()
              : _buildConfirmButtons(),
        ),
      ],
    );
  }

  Widget _buildLoadingButton() {
    final label = _isVerifying ? 'Verifying your identity...' : 'Uploading selfie...';
    return SizedBox(
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
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.jost(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                  color: _cyan.withAlpha(50),
                  blurRadius: 22,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _confirmAndVerify,
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
                    'Verify Identity',
                    style: GoogleFonts.jost(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.verified_user_outlined,
                      size: 17, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: _retakePhoto,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded,
                    size: 15, color: _textMuted),
                const SizedBox(width: 6),
                Text(
                  'Retake Photo',
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _textMuted,
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

    // Dark overlay with oval cutout
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

    // Oval border
    final borderPaint = Paint()
      ..color = _cyan.withAlpha(120)
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
          border: Border.all(color: _cyan, width: 4),
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
                border: Border.all(color: _borderGlass, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textHeading,
                size: 17,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
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
                  colors: [_cyan.withAlpha(18), _cyanDim.withAlpha(6), Colors.transparent],
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
                  colors: [_cyanDim.withAlpha(12), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}