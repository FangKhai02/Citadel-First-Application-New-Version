import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/citadel_colors.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    try {
      final api = ApiClient();
      final res = await api.get(ApiEndpoints.trustProductCwdDeckUrl);
      final downloadUrl = res.data['download_url'] as String;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cwd_trust_deck.pdf');

      await Dio().download(downloadUrl, file.path);

      if (mounted) {
        setState(() {
          _localPath = file.path;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load document. Please try again.';
          _loading = false;
        });
      }
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
          icon: const Icon(Icons.arrow_back_ios_new, color: CitadelColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'CWD Trust',
          style: GoogleFonts.jost(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CitadelColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: _loading || _error != null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _totalPages > 0 ? (_currentPage + 1) / _totalPages : 0,
                  backgroundColor: CitadelColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation(CitadelColors.primary),
                ),
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: CitadelColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading document...',
              style: GoogleFonts.jost(
                fontSize: 14,
                color: CitadelColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: CitadelColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  fontSize: 14,
                  color: CitadelColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _fetchPdf();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CitadelColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Retry', style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    return PDFView(
      filePath: _localPath,
      enableSwipe: true,
      autoSpacing: true,
      pageFling: true,
      onRender: (pages) {
        setState(() => _totalPages = pages ?? 0);
      },
      onViewCreated: (controller) {},
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
        });
      },
      onError: (error) {
        setState(() => _error = 'Error displaying document.');
      },
    );
  }
}