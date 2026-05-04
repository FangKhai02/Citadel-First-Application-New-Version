import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/citadel_colors.dart';
import '../../../models/app_notification.dart';
import 'widgets/notification_tile.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _api = ApiClient();
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get(ApiEndpoints.notifications);
      final list = (res.data['notifications'] as List?) ?? [];
      final count = res.data['unread_count'] as int? ?? 0;
      setState(() {
        _notifications = list.map((e) => AppNotification.fromJson(e)).toList();
        _unreadCount = count;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications';
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await _api.patch('${ApiEndpoints.notifications}/$id/read');
      setState(() {
        _notifications = [
          for (final n in _notifications)
            if (n.id == id)
              AppNotification(
                id: n.id,
                title: n.title,
                message: n.message,
                type: n.type,
                isRead: true,
                createdAt: n.createdAt,
              )
            else
              n,
        ];
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _api.post(ApiEndpoints.notificationReadAll);
      setState(() {
        _notifications = [
          for (final n in _notifications)
            AppNotification(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              isRead: true,
              createdAt: n.createdAt,
            ),
        ];
        _unreadCount = 0;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.jost(
            color: CitadelColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: GoogleFonts.jost(
                  color: CitadelColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: CitadelColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CitadelColors.primary))
          : _error != null
              ? Center(
                  child: Text(_error!, style: GoogleFonts.jost(color: CitadelColors.textSecondary, fontSize: 16)))
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: CitadelColors.primary,
                      backgroundColor: CitadelColors.surface,
                      onRefresh: _fetchNotifications,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => NotificationTile(
                          notification: _notifications[i],
                          onTap: () {
                            if (!_notifications[i].isRead) _markAsRead(_notifications[i].id);
                          },
                        ),
                      ),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: CitadelColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.jost(color: CitadelColors.textSecondary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see updates and reminders here',
            style: GoogleFonts.jost(color: CitadelColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

extension on BuildContext {
  void pop() => Navigator.of(this).pop();
}