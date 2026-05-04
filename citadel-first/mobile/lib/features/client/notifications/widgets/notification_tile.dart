import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/citadel_colors.dart';
import '../../../../models/app_notification.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForType(notification.type);
    final iconColor = _colorForType(notification.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? CitadelColors.surface
                : CitadelColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? CitadelColors.cardBorder
                  : CitadelColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.jost(
                              color: CitadelColors.textPrimary,
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: CitadelColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: GoogleFonts.jost(
                        color: CitadelColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(notification.createdAt!),
                        style: GoogleFonts.jost(
                          color: CitadelColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
        'success' => Icons.check_circle_outline,
        'warning' => Icons.warning_amber_outlined,
        _ => Icons.info_outline_rounded,
      };

  Color _colorForType(String type) => switch (type) {
        'success' => CitadelColors.success,
        'warning' => CitadelColors.warning,
        'info' => CitadelColors.primary,
        _ => CitadelColors.textSecondary,
      };

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}