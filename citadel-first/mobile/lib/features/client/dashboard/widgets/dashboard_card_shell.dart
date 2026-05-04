import 'package:flutter/material.dart';
import '../../../../core/theme/citadel_colors.dart';

class DashboardCardShell extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final BoxShadow? shadow;

  const DashboardCardShell({
    super.key,
    required this.child,
    this.gradient,
    this.borderColor,
    this.padding,
    this.borderRadius = 16,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient ??
            const LinearGradient(
              colors: [CitadelColors.surfaceLight, CitadelColors.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? CitadelColors.border),
        boxShadow: shadow != null ? [shadow!] : null,
      ),
      child: child,
    );
  }
}