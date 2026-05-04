import 'package:flutter/material.dart';

import '../../../../core/theme/citadel_colors.dart';

class GreetingBar extends StatelessWidget {
  final VoidCallback? onHamburgerTap;
  final VoidCallback? onNotificationTap;
  final bool hasNotifications;

  const GreetingBar({
    super.key,
    this.onHamburgerTap,
    this.onNotificationTap,
    this.hasNotifications = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Hamburger button
          GestureDetector(
            onTap: onHamburgerTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CitadelColors.surfaceLight,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CitadelColors.border),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: CitadelColors.textSecondary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Citadel logo
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Notification bell
          GestureDetector(
            onTap: onNotificationTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CitadelColors.surfaceLight,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CitadelColors.border),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      color: CitadelColors.textSecondary,
                      size: 22,
                    ),
                  ),
                  if (hasNotifications)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: CitadelColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CitadelColors.surfaceLight,
                            width: 1.5,
                          ),
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