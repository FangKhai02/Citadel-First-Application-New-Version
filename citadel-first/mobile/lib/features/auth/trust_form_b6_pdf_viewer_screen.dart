import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

// ── Brand tokens ───────────────────────────────────────────────────────────────
const _bgPrimary   = Color(0xFF0A0F1E);
const _bgCard      = Color(0xFF111827);
const _cyan        = Color(0xFF29ABE2);
const _cyanDim     = Color(0xFF1A7BA8);
const _textHeading = Color(0xFFE2E8F0);
const _textMuted   = Color(0xFF94A3B8);
const _errorRed    = Color(0xFFEF4444);

class TrustFormB6PdfViewerScreen extends StatefulWidget {
  final int recordId;

  const TrustFormB6PdfViewerScreen({super.key, required this.recordId});

  @override
  State<TrustFormB6PdfViewerScreen> createState() =>
      _TrustFormB6PdfViewerScreenState();
}

class _TrustFormB6PdfViewerScreenState
    extends State<TrustFormB6PdfViewerScreen> {
  String? _localPath;
  String? _errorMessage;
  bool _isLoading = true;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    try {
      final response = await ApiClient().dio.get(
        ApiEndpoints.trustFormB6Pdf(widget.recordId),
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      final cacheDir = await getTemporaryDirectory();
      final tempFile = File('${cacheDir.path}/b6_form_${widget.recordId}.pdf');

      // Always write fresh — never show a stale cached file
      if (await tempFile.exists()) await tempFile.delete();
      await tempFile.writeAsBytes(bytes);

      if (mounted) {
        setState(() {
          _localPath = tempFile.path;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.response?.data?['detail'] as String? ??
              'Failed to load PDF. Please try again.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load PDF. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _textMuted,
                      size: 20,
                    ),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Form B6 — Preview',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _textHeading,
                      ),
                    ),
                  ),
                  if (_totalPages > 0)
                    Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: _textMuted,
                      ),
                    ),
                ],
              ),
            ),

            // ── Divider ───────────────────────────────────────────────
            Container(height: 1, color: const Color(0xFF1E2D40), margin: const EdgeInsets.only(top: 12)),

            // ── PDF area ──────────────────────────────────────────────
            Expanded(
              child: _buildBody(),
            ),

            // ── Bottom CTA ────────────────────────────────────────────
            _BottomBar(onContinue: () => context.push('/signup/client/ekyc-pending')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _cyan, strokeWidth: 2),
            const SizedBox(height: 16),
            Text(
              'Loading your B6 form…',
              style: GoogleFonts.ibmPlexSans(fontSize: 14, color: _textMuted),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: _errorRed, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(fontSize: 14, color: _errorRed, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _fetchPdf();
                },
                child: Text(
                  'Retry',
                  style: GoogleFonts.ibmPlexSans(fontSize: 14, color: _cyan),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      child: PDFView(
        filePath: _localPath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        backgroundColor: _bgPrimary,
        onRender: (pages) => setState(() => _totalPages = pages ?? 0),
        onPageChanged: (page, total) => setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
        }),
        onError: (_) => setState(() {
          _errorMessage = 'Failed to render PDF.';
        }),
      ),
    );
  }
}

// ── Bottom bar ─────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onContinue;
  const _BottomBar({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(top: BorderSide(color: const Color(0xFF1E2D40), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: _cyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your B6 form has been submitted and saved.',
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: _textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_cyan, _cyanDim],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: _cyan.withAlpha(55),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
