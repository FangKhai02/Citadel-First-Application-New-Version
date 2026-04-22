import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _gold      = Color(0xFFCA8A04);
const _textMuted = Color(0xFF78716C);
const _trackDim  = Color(0xFF44403C);

class SignupProgressBar extends StatelessWidget {
  final int currentStep; // 0-indexed

  static const _steps = ['Profile', 'Declare', 'Terms', 'ID Verify', 'Information'];

  const SignupProgressBar({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            for (int i = 0; i < _steps.length; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= currentStep
                        ? _gold
                        : _trackDim.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: i == currentStep
                        ? [BoxShadow(color: _gold.withAlpha(100), blurRadius: 8)]
                        : [],
                  ),
                ),
              ),
              if (i < _steps.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            for (int i = 0; i < _steps.length; i++) ...[
              Expanded(
                child: Text(
                  _steps[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jost(
                    fontSize: 11,
                    fontWeight: i == currentStep
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: i == currentStep
                        ? _gold
                        : i < currentStep
                            ? _textMuted
                            : _textMuted.withAlpha(90),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
