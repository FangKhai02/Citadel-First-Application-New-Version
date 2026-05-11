import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/citadel_colors.dart';

class TrustSubmissionSuccessScreen extends StatelessWidget {
  const TrustSubmissionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: CitadelColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: CitadelColors.success,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Application Submitted!',
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: CitadelColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vanguard Trustee Berhad will be reviewing your application soon. Once approved, you will be notified and can proceed with the trust placement.',
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  fontSize: 14,
                  color: CitadelColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/client/dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CitadelColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back to Dashboard',
                    style: GoogleFonts.jost(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}