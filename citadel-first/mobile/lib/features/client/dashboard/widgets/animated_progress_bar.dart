import 'package:flutter/material.dart';
import '../../../../core/theme/citadel_colors.dart';

class AnimatedProgressBar extends StatelessWidget {
  final int completedSteps;
  final int totalSteps;
  final double stepSize;
  final double lineThickness;

  const AnimatedProgressBar({
    super.key,
    required this.completedSteps,
    this.totalSteps = 2,
    this.stepSize = 10,
    this.lineThickness = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isEven) {
          final stepIndex = i ~/ 2;
          final isCompleted = stepIndex < completedSteps;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            width: stepSize,
            height: stepSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? CitadelColors.primary : Colors.transparent,
              border: Border.all(
                color: isCompleted
                    ? CitadelColors.primary
                    : CitadelColors.textMuted,
                width: isCompleted ? 0 : 1.5,
              ),
              boxShadow: isCompleted
                  ? [
                      BoxShadow(
                        color: CitadelColors.primary.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          );
        } else {
          final lineIndex = i ~/ 2;
          final isLineActive = lineIndex < completedSteps - 1;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              height: lineThickness,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isLineActive
                    ? CitadelColors.primary
                    : CitadelColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }
      }),
    );
  }
}