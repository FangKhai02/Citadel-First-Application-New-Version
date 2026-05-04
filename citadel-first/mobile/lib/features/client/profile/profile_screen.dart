import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_bloc.dart';
import '../../../core/auth/auth_event.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/citadel_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final userName = authState is AuthAuthenticated ? (authState.name ?? 'Client') : 'Client';

    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        title: Text('Profile', style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(name: userName),
          const SizedBox(height: 24),
          _MenuSection(
            title: 'Trust',
            items: [
              _MenuItem(
                icon: Icons.people_outline_rounded,
                label: 'Beneficiaries',
                onTap: () => _navigateToBeneficiaries(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MenuSection(
            title: 'Account',
            items: [
              _MenuItem(
                icon: Icons.lock_outline_rounded,
                label: 'Change Password',
                onTap: () {
                  // TODO: Navigate to change password
                },
              ),
              _MenuItem(
                icon: Icons.contact_support_outlined,
                label: 'Contact Us',
                onTap: () {
                  // TODO: Navigate to contact us
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MenuSection(
            title: 'Legal',
            items: [
              _MenuItem(
                icon: Icons.description_outlined,
                label: 'Terms & Conditions',
                onTap: () {
                  // TODO: Navigate to terms
                },
              ),
              _MenuItem(
                icon: Icons.shield_outlined,
                label: 'Privacy Policy',
                onTap: () {
                  // TODO: Navigate to privacy policy
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          _LogoutButton(onPressed: () => _logout(context)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _navigateToBeneficiaries(BuildContext context) {
    Navigator.pushNamed(context, '/client/beneficiary-summary');
  }

  void _logout(BuildContext context) {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;

  const _ProfileHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CitadelColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: CitadelColors.primary.withValues(alpha:0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'C',
              style: GoogleFonts.jost(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CitadelColors.primary,
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
                  style: GoogleFonts.jost(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Client',
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    color: CitadelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.jost(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CitadelColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: CitadelColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CitadelColors.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  Divider(height: 1, color: CitadelColors.border, indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: CitadelColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.jost(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: CitadelColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: CitadelColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LogoutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text('Log Out', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          foregroundColor: CitadelColors.error,
          side: const BorderSide(color: CitadelColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}