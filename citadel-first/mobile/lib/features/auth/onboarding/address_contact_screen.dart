import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';
import '../widgets/signup_progress_bar.dart' show SignupProgressBar;
import 'package:citadel_first/core/theme/citadel_colors.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────────

class AddressContactScreen extends StatefulWidget {
  const AddressContactScreen({super.key});

  @override
  State<AddressContactScreen> createState() => _AddressContactScreenState();
}

class _AddressContactScreenState extends State<AddressContactScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _residentialCtrl = TextEditingController();
  final _mailingCtrl = TextEditingController();
  final _homePhoneCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _sameAsResidential = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _originalEmail = '';

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _residentialCtrl.addListener(_onResidentialChanged);
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final email = await SecureStorage.getEmail();
    if (email != null && email.isNotEmpty && mounted) {
      _emailCtrl.text = email;
      _originalEmail = email;
    }
  }

  void _onResidentialChanged() {
    if (_sameAsResidential) {
      _mailingCtrl.text = _residentialCtrl.text;
    }
  }

  @override
  void dispose() {
    _residentialCtrl.removeListener(_onResidentialChanged);
    _animCtrl.dispose();
    _residentialCtrl.dispose();
    _mailingCtrl.dispose();
    _homePhoneCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _onSameAsResidentialChanged(bool? value) {
    setState(() {
      _sameAsResidential = value ?? false;
      if (_sameAsResidential) {
        _mailingCtrl.text = _residentialCtrl.text;
      } else {
        _mailingCtrl.clear();
      }
    });
  }

  Future<void> _onContinue() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _errorMessage = 'Please fill in all required fields.');
      return;
    }

    final newEmail = _emailCtrl.text.trim().toLowerCase();
    final oldEmail = _originalEmail.toLowerCase();

    if (newEmail != oldEmail && _originalEmail.isNotEmpty) {
      final confirmed = await _showEmailChangeDialog(oldEmail, newEmail);
      if (confirmed == false) {
        // User chose to keep original — revert email field and continue
        _emailCtrl.text = _originalEmail;
      } else if (confirmed != true) {
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
        'residential_address': _residentialCtrl.text.trim(),
        'mobile_number': _mobileCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      };
      if (_sameAsResidential) {
        data['mailing_address'] = _residentialCtrl.text.trim();
      } else {
        data['mailing_address'] = _mailingCtrl.text.trim();
      }
      if (_homePhoneCtrl.text.trim().isNotEmpty) {
        data['home_telephone'] = _homePhoneCtrl.text.trim();
      }

      await ApiClient().patch(ApiEndpoints.addressContact, data: data);
      if (!mounted) return;
      context.push('/signup/client/employment-details');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String?;
      setState(() => _errorMessage = msg ?? 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showEmailChangeDialog(String oldEmail, String newEmail) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CitadelColors.border, width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: CitadelColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'Email Change Detected',
              style: GoogleFonts.jost(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CitadelColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The email you previously entered was:',
              style: GoogleFonts.jost(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: CitadelColors.textBody,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CitadelColors.border.withAlpha(60), width: 1),
              ),
              child: Text(
                oldEmail,
                style: GoogleFonts.jost(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: CitadelColors.textMuted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to change it to:',
              style: GoogleFonts.jost(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: CitadelColors.textBody,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: CitadelColors.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CitadelColors.primary.withAlpha(60), width: 1),
              ),
              child: Text(
                newEmail,
                style: GoogleFonts.jost(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: CitadelColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will update your login email. Please use the new email the next time you sign in.',
              style: GoogleFonts.jost(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: CitadelColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CitadelColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Keep Original',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jost(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CitadelColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Change Email',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jost(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      body: Stack(
        children: [
          const _PageBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(onBack: () => Navigator.of(context).pop()),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SignupProgressBar(currentStep: 4),
                              const SizedBox(height: 20),

                              // ── Decorative header ──────────────────────────────
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [CitadelColors.primary, CitadelColors.primaryDark],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CitadelColors.primary.withAlpha(40),
                                            blurRadius: 24,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.location_on_outlined,
                                        size: 34,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Address & Contact',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.bodoniModa(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: CitadelColors.textPrimary,
                                        letterSpacing: -0.3,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Provide your residential address and contact details so we can reach you.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.jost(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w300,
                                        color: CitadelColors.textMuted,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // ── Card 1: Residential Address ─────────────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: CitadelColors.border.withAlpha(60),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Section header
                                    Row(
                                      children: [
                                        const Icon(Icons.home_outlined, size: 20, color: CitadelColors.primary),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Residential Address',
                                          style: GoogleFonts.jost(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: CitadelColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    _FieldLabel(label: 'Residential Address', required: true),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _residentialCtrl,
                                      hint: 'Enter your residential address',
                                      prefixIcon: Icons.home_outlined,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Residential address is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // Same as residential checkbox
                                    GestureDetector(
                                      onTap: () => _onSameAsResidentialChanged(!_sameAsResidential),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Checkbox(
                                              value: _sameAsResidential,
                                              onChanged: _onSameAsResidentialChanged,
                                              activeColor: CitadelColors.primary,
                                              checkColor: Colors.white,
                                              side: const BorderSide(color: CitadelColors.border, width: 1.5),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Same as residential address',
                                            style: GoogleFonts.jost(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: CitadelColors.textBody,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    _FieldLabel(label: 'Mailing Address', required: true),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _mailingCtrl,
                                      hint: 'Enter your mailing address',
                                      prefixIcon: Icons.markunread_mailbox_outlined,
                                      enabled: !_sameAsResidential,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Mailing address is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Card 2: Contact Details ─────────────────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: CitadelColors.border.withAlpha(60),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Section header
                                    Row(
                                      children: [
                                        const Icon(Icons.contact_phone_outlined, size: 20, color: CitadelColors.primary),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Contact Details',
                                          style: GoogleFonts.jost(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: CitadelColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    // Mobile Number
                                    _FieldLabel(label: 'Mobile Number', required: true),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _mobileCtrl,
                                      hint: 'e.g. +6012-345 6789',
                                      prefixIcon: Icons.smartphone_outlined,
                                      keyboardType: TextInputType.phone,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Mobile number is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // Home Telephone
                                    _FieldLabel(label: 'Home Telephone (optional)'),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _homePhoneCtrl,
                                      hint: 'e.g. +603-1234 5678',
                                      prefixIcon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 20),

                                    // Email
                                    _FieldLabel(label: 'Email', required: true),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _emailCtrl,
                                      hint: 'you@example.com',
                                      prefixIcon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Email is required';
                                        }
                                        final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                        if (!emailRe.hasMatch(v.trim())) {
                                          return 'Enter a valid email address';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Error banner
                              if (_errorMessage != null) ...[
                                _ErrorBanner(message: _errorMessage!),
                                const SizedBox(height: 16),
                              ],

                              const SizedBox(height: 8),

                              // CTA
                              _CtaButton(
                                isLoading: _isLoading,
                                onPressed: _onContinue,
                              ),

                              const SizedBox(height: 28),
                              Center(
                                child: Text(
                                  '© ${DateTime.now().year} Citadel Group. All rights reserved.',
                                  style: GoogleFonts.jost(
                                    fontSize: 10,
                                    color: CitadelColors.textMuted.withAlpha(110),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page background ──────────────────────────────────────────────────────────

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: [
          // Upper-left radial glow
          Positioned(
            top: size.height * 0.10,
            left: size.width * 0.05,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CitadelColors.primary.withAlpha(22),
                    CitadelColors.primaryDark.withAlpha(8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Center glow
          Positioned(
            top: size.height * 0.18,
            left: size.width * 0.28,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [CitadelColors.primary.withAlpha(15), Colors.transparent],
                ),
              ),
            ),
          ),
          // Lower-right glow
          Positioned(
            bottom: size.height * 0.1,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [CitadelColors.primaryDark.withAlpha(15), Colors.transparent],
                ),
              ),
            ),
          ),
          // Logo watermark
          Align(
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [CitadelColors.primary.withAlpha(20), Colors.transparent],
                    ),
                  ),
                ),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                  child: Opacity(
                    opacity: 0.06,
                    child: Image.asset(
                      'assets/images/launcher_icon.png',
                      width: 200,
                      fit: BoxFit.contain,
                    ),
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

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CitadelColors.border, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: CitadelColors.textPrimary,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.jost(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.3,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          Text(
            '*',
            style: GoogleFonts.jost(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CitadelColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Input field ──────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final IconData prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    required this.prefixIcon,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      style: GoogleFonts.jost(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFF94A3B8),
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          prefixIcon,
          size: 18,
          color: enabled ? CitadelColors.textMuted : CitadelColors.textMuted.withAlpha(80),
        ),
        hintStyle: GoogleFonts.jost(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: CitadelColors.textMuted.withAlpha(80),
        ),
        labelStyle: GoogleFonts.jost(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: CitadelColors.textMuted,
        ),
        filled: true,
        fillColor: enabled
            ? Colors.white.withAlpha(8)
            : Colors.white.withAlpha(4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CitadelColors.border, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CitadelColors.border.withAlpha(60), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CitadelColors.primary.withAlpha(180), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CitadelColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CitadelColors.error, width: 1.5),
        ),
        errorStyle: GoogleFonts.jost(fontSize: 12, color: CitadelColors.error),
      ),
    );
  }
}

// ── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CitadelColors.error.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.error.withAlpha(75), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: CitadelColors.error, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jost(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: CitadelColors.error,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CTA button ───────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CtaButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLoading ? 0.38 : 1.0,
      duration: const Duration(milliseconds: 260),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E6DA4), Color(0xFF1B4F7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: CitadelColors.primary.withAlpha(55),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: CitadelColors.primaryDark.withAlpha(25),
                blurRadius: 48,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.jost(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}