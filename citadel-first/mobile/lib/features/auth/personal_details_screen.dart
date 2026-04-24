import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import 'widgets/signup_progress_bar.dart' show SignupProgressBar;
import 'widgets/dropdown_data.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────────
const _bgPrimary   = Color(0xFF0C1829);
const _cyan         = Color(0xFF29ABE2);
const _cyanDim      = Color(0xFF1A7BA8);
const _textHeading  = Color(0xFFE2E8F0);
const _textBody     = Color(0xFFCBD5E1);
const _textMuted    = Color(0xFF64748B);
const _borderGlass  = Color(0xFF1E3A5F);
const _errorRed     = Color(0xFFEF4444);
const _ctaTop       = Color(0xFF2E6DA4);
const _ctaBottom    = Color(0xFF1B4F7A);
const _inputBg      = Color(0xFF0F172A);

// ── Signup service (placeholder) ──────────────────────────────────────────────

class SignupService {
  static final _api = ApiClient();

  static Future<void> submitPersonalDetails({
    required String title,
    required String maritalStatus,
    String? passportExpiry,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      'marital_status': maritalStatus,
    };
    if (passportExpiry != null) {
      data['passport_expiry'] = passportExpiry;
    }
    await _api.patch('/signup/personal-details', data: data);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PersonalDetailsScreen extends StatefulWidget {
  /// Nationality from OCR. If not "Malaysian" (or "MY"), passport expiry is shown.
  final String nationality;

  const PersonalDetailsScreen({super.key, required this.nationality});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String? _selectedTitle;
  String? _selectedMaritalStatus;
  DateTime? _passportExpiry;
  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  bool get _isNonMalaysian {
    final n = widget.nationality.toLowerCase();
    return n != 'malaysian' && n != 'my' && n != 'malaysia';
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await SignupService.submitPersonalDetails(
        title: _selectedTitle!,
        maritalStatus: _selectedMaritalStatus!,
        passportExpiry: _isNonMalaysian && _passportExpiry != null
            ? '${_passportExpiry!.year.toString().padLeft(4, '0')}-'
                '${_passportExpiry!.month.toString().padLeft(2, '0')}-'
                '${_passportExpiry!.day.toString().padLeft(2, '0')}'
            : null,
      );

      if (!mounted) return;
      context.push('/signup/client/address-contact');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String?;
      setState(() => _errorMessage = msg ?? 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPassportExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 20, 12, 31),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _cyan,
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
              onSurface: _textBody,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _passportExpiry = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: _bgPrimary,
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
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
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
                                          colors: [_cyan, _cyanDim],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _cyan.withAlpha(40),
                                            blurRadius: 24,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 34,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Personal Details',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.bodoniModa(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: _textHeading,
                                        letterSpacing: -0.3,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please confirm your title and marital status.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.jost(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w300,
                                        color: _textMuted,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // ── Card 1: Identity Information ────────────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _borderGlass.withAlpha(60),
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
                                        const Icon(Icons.badge_outlined, size: 20, color: _cyan),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Identity Information',
                                          style: GoogleFonts.jost(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _textHeading,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    // Title dropdown
                                    _FieldLabel(label: 'Title', required: true),
                                    const SizedBox(height: 6),
                                    _DropdownField(
                                      value: _selectedTitle,
                                      hint: 'Select title',
                                      items: kTitleOptions,
                                      prefixIcon: Icons.badge_outlined,
                                      onChanged: (v) => setState(() => _selectedTitle = v),
                                      validator: (v) =>
                                          v == null ? 'Please select a title' : null,
                                    ),
                                    const SizedBox(height: 20),

                                    // Marital status dropdown
                                    _FieldLabel(label: 'Marital Status', required: true),
                                    const SizedBox(height: 6),
                                    _DropdownField(
                                      value: _selectedMaritalStatus,
                                      hint: 'Select marital status',
                                      items: kMaritalStatusOptions,
                                      prefixIcon: Icons.favorite_outline_rounded,
                                      onChanged: (v) =>
                                          setState(() => _selectedMaritalStatus = v),
                                      validator: (v) =>
                                          v == null ? 'Please select your marital status' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Card 2: Passport Details (non-Malaysian only) ──
                              if (_isNonMalaysian) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _borderGlass.withAlpha(60),
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
                                          const Icon(Icons.flight_outlined, size: 20, color: _cyan),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Passport Details',
                                            style: GoogleFonts.jost(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _textHeading,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),

                                      // Passport expiry date
                                      _FieldLabel(label: 'Passport Expiry Date', required: true),
                                      const SizedBox(height: 6),
                                      _PassportExpiryField(
                                        expiryDate: _passportExpiry,
                                        onTap: _pickPassportExpiry,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // ── Error banner ──
                              if (_errorMessage != null) ...[
                                _ErrorBanner(message: _errorMessage!),
                                const SizedBox(height: 16),
                              ],

                              const SizedBox(height: 8),

                              // ── CTA ──
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
                                    color: _textMuted.withAlpha(110),
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
      ),
    );
  }
}

// ── Page background ────────────────────────────────────────────────────────────

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: [
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
                    _cyan.withAlpha(22),
                    _cyanDim.withAlpha(8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.18,
            left: size.width * 0.28,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_cyan.withAlpha(15), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_cyanDim.withAlpha(15), Colors.transparent],
                ),
              ),
            ),
          ),
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
                      colors: [_cyan.withAlpha(20), Colors.transparent],
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

// ── Top bar ────────────────────────────────────────────────────────────────────

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
                border: Border.all(color: _borderGlass, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textHeading,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

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
              color: _cyan,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Dropdown field ─────────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final IconData prefixIcon;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.prefixIcon,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(
        hint,
        style: GoogleFonts.jost(fontSize: 14, color: const Color(0xFF475569)),
      ),
      icon: const Icon(Icons.expand_more_rounded, color: _textMuted, size: 20),
      decoration: InputDecoration(
        prefixIcon: Icon(prefixIcon, size: 18, color: _textMuted),
        filled: true,
        fillColor: _inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderGlass, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _cyan.withAlpha(180), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1.5),
        ),
        errorStyle: GoogleFonts.jost(fontSize: 12, color: _errorRed),
      ),
      style: GoogleFonts.jost(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFF8FAFC),
      ),
      dropdownColor: const Color(0xFF0F172A),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

// ── Passport expiry field ──────────────────────────────────────────────────────

class _PassportExpiryField extends StatelessWidget {
  final DateTime? expiryDate;
  final VoidCallback onTap;

  const _PassportExpiryField({
    required this.expiryDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = expiryDate != null
        ? '${expiryDate!.day.toString().padLeft(2, '0')}/'
            '${expiryDate!.month.toString().padLeft(2, '0')}/'
            '${expiryDate!.year}'
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expiryDate != null
                ? _cyan.withAlpha(180)
                : _borderGlass,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: _textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText.isEmpty ? 'Select expiry date' : displayText,
                style: GoogleFonts.jost(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: displayText.isEmpty
                      ? const Color(0xFF475569)
                      : const Color(0xFFF8FAFC),
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, color: _textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _errorRed.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errorRed.withAlpha(75), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _errorRed, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jost(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: _errorRed,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CTA button ─────────────────────────────────────────────────────────────────

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
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_ctaTop, _ctaBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _cyan.withAlpha(50),
                blurRadius: 22,
                offset: const Offset(0, 5),
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
                borderRadius: BorderRadius.circular(14),
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
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
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