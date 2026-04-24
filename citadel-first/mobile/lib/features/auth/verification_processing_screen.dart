import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/face_verification_service.dart';
import '../../models/document_upload.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────────
const _bgPrimary   = Color(0xFF0C1829);
const _cyan        = Color(0xFF29ABE2);
const _cyanDim     = Color(0xFF1A7BA8);
const _textHeading = Color(0xFFE2E8F0);
const _textMuted   = Color(0xFF64748B);

class VerificationProcessingScreen extends StatefulWidget {
  final String selfieImagePath;
  final String docImageKey;
  final DocumentUploadResult docUploadResult;
  final VoidCallback onSuccess;
  final VoidCallback onFailure;

  const VerificationProcessingScreen({
    super.key,
    required this.selfieImagePath,
    required this.docImageKey,
    required this.docUploadResult,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<VerificationProcessingScreen> createState() =>
      _VerificationProcessingScreenState();
}

class _VerificationProcessingScreenState
    extends State<VerificationProcessingScreen>
    with SingleTickerProviderStateMixin {
  String _statusMessage = 'Uploading your selfie...';

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _startVerification();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startVerification() async {
    try {
      final svc = FaceVerificationService();
      final file = File(widget.selfieImagePath);

      // 1. Get presigned URL
      final presigned = await svc.getSelfiePresignedUrl(
        filename: 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final uploadUrl = presigned['upload_url']!;
      final selfieKey = presigned['key']!;

      if (!mounted) return;

      setState(() => _statusMessage = 'Comparing your face with your ID photo...');

      // 2. Upload to S3
      await svc.uploadSelfieToS3(file, uploadUrl);

      if (!mounted) return;

      // 3. Face verification
      final result = await svc.verifyFace(
        selfieImageKey: selfieKey,
        docImageKey: widget.docImageKey,
      );

      if (!mounted) return;

      if (result.isMatch) {
        widget.onSuccess();
      } else {
        widget.onFailure();
      }
    } catch (e) {
      debugPrint('[VerificationProcessing] Error: $e');
      if (mounted) {
        widget.onFailure();
      }
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
            child: Column(
              children: [
                // No back button — prevent navigation away during processing
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated pulse circle
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnim.value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _cyan.withAlpha(90), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: _cyan.withAlpha(40),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: _cyan,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'Verifying Your Identity',
                          style: GoogleFonts.bodoniModa(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: _textHeading,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _statusMessage,
                              key: ValueKey(_statusMessage),
                              style: GoogleFonts.jost(
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                color: _textMuted,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            'Please do not close this page',
                            style: GoogleFonts.jost(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: _textMuted.withAlpha(150),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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

// ── Page background ──────────────────────────────────────────────────────────

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
                    _cyan.withAlpha(22),
                    _cyanDim.withAlpha(8),
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
                  colors: [_cyanDim.withAlpha(15), Colors.transparent],
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
                      colors: [_cyan.withAlpha(15), Colors.transparent],
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