import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/citadel_colors.dart';

class SideDrawerOverlay extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String userName;
  final int unreadNotificationCount;
  final VoidCallback onNavigateProfile;
  final VoidCallback onNavigateBeneficiaries;
  final VoidCallback onNavigateNotifications;
  final VoidCallback onNavigatePortfolio;
  final VoidCallback onNavigateTrustProducts;
  final VoidCallback onLogout;

  const SideDrawerOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.userName,
    required this.unreadNotificationCount,
    required this.onNavigateProfile,
    required this.onNavigateBeneficiaries,
    required this.onNavigateNotifications,
    required this.onNavigatePortfolio,
    required this.onNavigateTrustProducts,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * 0.72;
    final displayName = userName.isNotEmpty ? userName : 'Client';
    final initial = displayName[0].toUpperCase();

    return IgnorePointer(
      ignoring: !isOpen,
      child: Stack(
        children: [
          // Scrim
          GestureDetector(
            onTap: onClose,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            color: Colors.black.withValues(alpha: isOpen ? 0.5 : 0.0),
          ),
        ),
        // Drawer panel
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(isOpen ? 0 : -drawerWidth, 0, 0),
          width: drawerWidth,
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            color: CitadelColors.background,
            boxShadow: [
              BoxShadow(color: Color(0x4D000000), offset: Offset(4, 0), blurRadius: 16),
            ],
          ),
          child: IgnorePointer(
            ignoring: !isOpen,
            child: Column(
              children: [
                // Header
                _DrawerHeader(initial: initial, name: displayName, onTap: onNavigateProfile),
                const Divider(color: CitadelColors.border, height: 1, thickness: 1),
                // Menu sections
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _DrawerSection(title: 'TRUST'),
                      _DrawerMenuItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'My Portfolio',
                        onTap: onNavigatePortfolio,
                      ),
                      _DrawerMenuItem(
                        icon: Icons.shield_outlined,
                        label: 'Trust Products',
                        onTap: onNavigateTrustProducts,
                      ),
                      _DrawerMenuItem(
                        icon: Icons.people_outline_rounded,
                        label: 'Beneficiaries',
                        onTap: onNavigateBeneficiaries,
                      ),
                      const Divider(color: CitadelColors.border, height: 1, thickness: 1),
                      _DrawerSection(title: 'ACCOUNT'),
                      _DrawerMenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        badge: unreadNotificationCount,
                        onTap: onNavigateNotifications,
                      ),
                      _DrawerMenuItem(
                        icon: Icons.person_outline,
                        label: 'Profile & Settings',
                        onTap: onNavigateProfile,
                      ),
                      _DrawerMenuItem(
                        icon: Icons.lock_outline_rounded,
                        label: 'Change Password',
                        onTap: () => _showComingSoon(context, 'Change Password'),
                      ),
                      _DrawerMenuItem(
                        icon: Icons.contact_support_outlined,
                        label: 'Contact Us',
                        onTap: () => _showComingSoon(context, 'Contact Us'),
                      ),
                      const Divider(color: CitadelColors.border, height: 1, thickness: 1),
                      _DrawerSection(title: 'LEGAL'),
                      _DrawerMenuItem(
                        icon: Icons.description_outlined,
                        label: 'Terms & Conditions',
                        onTap: () => _showComingSoon(context, 'Terms & Conditions'),
                      ),
                      _DrawerMenuItem(
                        icon: Icons.shield_outlined,
                        label: 'Privacy Policy',
                        onTap: () => _showComingSoon(context, 'Privacy Policy'),
                      ),
                    ],
                  ),
                ),
                // Logout
                const Divider(color: CitadelColors.border, height: 1, thickness: 1),
                _DrawerMenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  iconColor: CitadelColors.error,
                  labelColor: CitadelColors.error,
                  onTap: onLogout,
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: CitadelColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final String initial;
  final String name;
  final VoidCallback onTap;

  const _DrawerHeader({required this.initial, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
        color: CitadelColors.surface,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [CitadelColors.primary, CitadelColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: CitadelColors.border),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.jost(fontSize: 24, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.jost(fontSize: 18, fontWeight: FontWeight.w700, color: CitadelColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Client',
                    style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textMuted, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: CitadelColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  const _DrawerSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: GoogleFonts.jost(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: CitadelColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final Color? iconColor;
  final Color? labelColor;

  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.iconColor,
    this.labelColor,
  });

  @override
  State<_DrawerMenuItem> createState() => _DrawerMenuItemState();
}

class _DrawerMenuItemState extends State<_DrawerMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ?? CitadelColors.textSecondary;
    final labelColor = widget.labelColor ?? CitadelColors.textPrimary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _pressed ? CitadelColors.surfaceHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                children: [
                  Icon(widget.icon, color: iconColor, size: 22),
                  if (widget.badge > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: CitadelColors.error, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.label,
                style: GoogleFonts.jost(fontSize: 15, fontWeight: FontWeight.w500, color: labelColor),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: CitadelColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}