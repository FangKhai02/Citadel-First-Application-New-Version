import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../widgets/dropdown_data.dart';
import '../widgets/signup_progress_bar.dart' show SignupProgressBar;
import 'package:citadel_first/core/theme/citadel_colors.dart';

// ── Brand tokens — Liquid Glass Dark (Citadel Navy) ──────────────────────────

class EmploymentDetailsScreen extends StatefulWidget {
  const EmploymentDetailsScreen({super.key});

  @override
  State<EmploymentDetailsScreen> createState() =>
      _EmploymentDetailsScreenState();
}

class _EmploymentDetailsScreenState extends State<EmploymentDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String? _employmentType;
  String? _occupation;
  final _otherOccupationCtrl = TextEditingController();
  final _workTitleCtrl   = TextEditingController();
  String? _natureOfBusiness;
  final _otherNatureOfBusinessCtrl = TextEditingController();
  final _employerNameCtrl = TextEditingController();
  final _employerAddrCtrl = TextEditingController();
  final _employerPhoneCtrl = TextEditingController();
  final _annualIncomeCtrl = TextEditingController();
  final _netWorthCtrl = TextEditingController();

  bool _isLoading    = false;
  String? _errorMessage;

  bool get _isOccupationOther => _occupation == 'Other';
  bool get _isNatureOfBusinessOther => _natureOfBusiness == 'Other';

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _otherOccupationCtrl.dispose();
    _otherNatureOfBusinessCtrl.dispose();
    _workTitleCtrl.dispose();
    _employerNameCtrl.dispose();
    _employerAddrCtrl.dispose();
    _employerPhoneCtrl.dispose();
    _annualIncomeCtrl.dispose();
    _netWorthCtrl.dispose();
    super.dispose();
  }

  bool get _showEmployerFields =>
      _employmentType != null &&
      kEmploymentTypesWithoutEmployer.contains(_employmentType) == false;

  Future<void> _onContinue() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _errorMessage = 'Please fill in all required fields.');
      return;
    }

    if (_isNatureOfBusinessOther && _otherNatureOfBusinessCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please specify your nature of business.');
      return;
    }

    if (_showEmployerFields && _employerNameCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Employer name is required for your employment type.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final occupationValue = _isOccupationOther
          ? _otherOccupationCtrl.text.trim()
          : _occupation;
      final natureOfBusinessValue = _isNatureOfBusinessOther
          ? _otherNatureOfBusinessCtrl.text.trim()
          : _natureOfBusiness;
      final data = <String, dynamic>{
        'employment_type': _employmentType,
        'occupation': occupationValue,
        'work_title': _workTitleCtrl.text.trim(),
        'nature_of_business': natureOfBusinessValue,
        'annual_income_range': _annualIncomeCtrl.text.trim().isNotEmpty ? _annualIncomeCtrl.text.trim() : null,
        'estimated_net_worth': _netWorthCtrl.text.trim().isNotEmpty ? _netWorthCtrl.text.trim() : null,
      };
      if (_showEmployerFields) {
        data['employer_name']     = _employerNameCtrl.text.trim();
        data['employer_address']  = _employerAddrCtrl.text.trim();
        data['employer_telephone'] = _employerPhoneCtrl.text.trim();
      }

      await ApiClient().patch(ApiEndpoints.employmentDetails, data: data);
      if (mounted) context.push('/signup/client/kyc-crs');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String?;
      setState(() => _errorMessage = msg ?? 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                              const SizedBox(height: 24),

                              // ── Decorative header ─────────────────────────
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
                                            color: CitadelColors.primary.withAlpha(60),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.work_outline_rounded,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Employment & Financial Details',
                                      style: GoogleFonts.bodoniModa(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: CitadelColors.textPrimary,
                                        letterSpacing: -0.3,
                                        height: 1.15,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Provide your employment and financial information to complete your profile.',
                                      style: GoogleFonts.jost(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w300,
                                        color: CitadelColors.textMuted,
                                        height: 1.6,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // ── Card 1: Employment Information ─────────────
                              _GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                      icon: Icons.work_outline_rounded,
                                      label: 'Employment Information',
                                    ),
                                    const SizedBox(height: 20),

                                    _FieldLabel(label: 'Employment Type', required: true),
                                    const SizedBox(height: 6),
                                    _DropdownField(
                                      value: _employmentType,
                                      hint: 'Select employment type',
                                      items: kEmploymentTypeOptions,
                                      icon: Icons.work_outline_rounded,
                                      validator: (v) =>
                                          v == null ? 'Employment type is required' : null,
                                      onChanged: (v) {
                                        setState(() {
                                          _employmentType = v;
                                          if (!_showEmployerFields) {
                                            _employerNameCtrl.clear();
                                            _employerAddrCtrl.clear();
                                            _employerPhoneCtrl.clear();
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    _FieldLabel(label: 'Occupation', required: true),
                                    const SizedBox(height: 6),
                                    _DropdownField(
                                      value: _occupation,
                                      hint: 'Select occupation',
                                      items: kOccupationOptions,
                                      icon: Icons.badge_outlined,
                                      validator: (v) =>
                                          v == null ? 'Occupation is required' : null,
                                      onChanged: (v) => setState(() {
                                        _occupation = v;
                                        if (v != 'Other') {
                                          _otherOccupationCtrl.clear();
                                        }
                                      }),
                                    ),
                                    if (_isOccupationOther) ...[
                                      const SizedBox(height: 12),
                                      _FieldLabel(label: 'Please specify your occupation', required: true),
                                      const SizedBox(height: 6),
                                      _InputField(
                                        controller: _otherOccupationCtrl,
                                        hint: 'e.g. Marine Biologist',
                                        prefixIcon: Icons.badge_outlined,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Please specify your occupation';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 20),

                                    _FieldLabel(label: 'Work Title', required: true),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _workTitleCtrl,
                                      hint: 'e.g. Senior Analyst',
                                      prefixIcon: Icons.title_outlined,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Work title is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    _FieldLabel(label: 'Nature of Business', required: true),
                                    const SizedBox(height: 6),
                                    _DropdownField(
                                      value: _natureOfBusiness,
                                      hint: 'Select nature of business',
                                      items: kNatureOfBusinessOptions,
                                      icon: Icons.business_outlined,
                                      validator: (v) =>
                                          v == null ? 'Nature of business is required' : null,
                                      onChanged: (v) => setState(() {
                                        _natureOfBusiness = v;
                                        if (v != 'Other') {
                                          _otherNatureOfBusinessCtrl.clear();
                                        }
                                      }),
                                    ),
                                    if (_isNatureOfBusinessOther) ...[
                                      const SizedBox(height: 12),
                                      _FieldLabel(label: 'Please specify your nature of business', required: true),
                                      const SizedBox(height: 6),
                                      _InputField(
                                        controller: _otherNatureOfBusinessCtrl,
                                        hint: 'e.g. Renewable Energy',
                                        prefixIcon: Icons.business_outlined,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Please specify your nature of business';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Card 2: Employer Details (conditional) ──────
                              AnimatedSize(
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: AnimatedOpacity(
                                  opacity: _showEmployerFields ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: !_showEmployerFields
                                      ? const SizedBox.shrink()
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _GlassCard(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _SectionHeader(
                                                    icon: Icons.apartment_outlined,
                                                    label: 'Employer Details',
                                                  ),
                                                  const SizedBox(height: 20),

                                                  _FieldLabel(label: 'Employer Name', required: true),
                                                  const SizedBox(height: 6),
                                                  _InputField(
                                                    controller: _employerNameCtrl,
                                                    hint: 'Company or organisation name',
                                                    prefixIcon: Icons.apartment_outlined,
                                                    validator: (v) {
                                                      if (v == null || v.trim().isEmpty) {
                                                        return 'Employer name is required';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                  const SizedBox(height: 20),

                                                  _FieldLabel(label: 'Employer Address (optional)'),
                                                  const SizedBox(height: 6),
                                                  _InputField(
                                                    controller: _employerAddrCtrl,
                                                    hint: 'Employer street address',
                                                    prefixIcon: Icons.location_on_outlined,
                                                  ),
                                                  const SizedBox(height: 20),

                                                  _FieldLabel(label: 'Employer Telephone (optional)'),
                                                  const SizedBox(height: 6),
                                                  _InputField(
                                                    controller: _employerPhoneCtrl,
                                                    hint: '+60 3-1234 5678',
                                                    prefixIcon: Icons.phone_outlined,
                                                    keyboardType: TextInputType.phone,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        ),
                                ),
                              ),

                              // ── Card 3: Financial Information ──────────────
                              _GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                      icon: Icons.account_balance_wallet_outlined,
                                      label: 'Financial Information',
                                    ),
                                    const SizedBox(height: 20),

                                    _FieldLabel(label: 'Annual Income (RM)', required: true),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _annualIncomeCtrl,
                                      hint: 'e.g. 75000',
                                      prefixIcon: Icons.payments_outlined,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Annual income is required';
                                        }
                                        final val = double.tryParse(v.trim().replaceAll(',', ''));
                                        if (val == null || val <= 0) {
                                          return 'Enter a valid amount';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    _FieldLabel(label: 'Estimated Net Worth (RM)', required: true),
                                    const SizedBox(height: 6),
                                    _InputField(
                                      controller: _netWorthCtrl,
                                      hint: 'e.g. 300000',
                                      prefixIcon: Icons.account_balance_wallet_outlined,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Estimated net worth is required';
                                        }
                                        final val = double.tryParse(v.trim().replaceAll(',', ''));
                                        if (val == null || val <= 0) {
                                          return 'Enter a valid amount';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Error banner ────────────────────────────────
                              if (_errorMessage != null) ...[
                                _ErrorBanner(message: _errorMessage!),
                                const SizedBox(height: 16),
                              ],

                              const SizedBox(height: 16),

                              // ── CTA ────────────────────────────────────────
                              _CtaButton(
                                isLoading: _isLoading,
                                onPressed: _onContinue,
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

// ── Glass card wrapper ────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CitadelColors.border.withAlpha(60), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: CitadelColors.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.jost(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CitadelColors.textPrimary,
          ),
        ),
      ],
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
                    CitadelColors.primary.withAlpha(22),
                    CitadelColors.primaryDark.withAlpha(8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
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
                  colors: [CitadelColors.primaryDark.withAlpha(15), Colors.transparent],
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
                      colors: [CitadelColors.primary.withAlpha(15), Colors.transparent],
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

// ── Field label ────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.jost(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8), letterSpacing: 0.3)),
        if (required) ...[
          const SizedBox(width: 3),
          Text('*', style: GoogleFonts.jost(fontSize: 12, fontWeight: FontWeight.w600, color: CitadelColors.primary)),
        ],
      ],
    );
  }
}

// ── Input field ────────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.jost(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFF8FAFC),
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefixIcon, size: 18, color: CitadelColors.textMuted),
        hintStyle: GoogleFonts.jost(fontSize: 14, color: const Color(0xFF475569)),
        filled: true,
        fillColor: CitadelColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CitadelColors.border, width: 1),
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

// ── Dropdown field ─────────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final IconData icon;
  final String? Function(String?)? validator;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.icon,
    this.validator,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(hint,
          style: GoogleFonts.jost(fontSize: 14, color: const Color(0xFF475569))),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item,
                    style: GoogleFonts.jost(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFF8FAFC),
                    )),
              ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      icon: Icon(Icons.expand_more_rounded, color: CitadelColors.textMuted, size: 20),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: CitadelColors.textMuted),
        filled: true,
        fillColor: CitadelColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CitadelColors.border, width: 1),
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
      dropdownColor: const Color(0xFF0F172A),
      style: GoogleFonts.jost(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFF8FAFC),
      ),
      isExpanded: true,
      menuMaxHeight: 280,
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
              colors: [CitadelColors.ctaGradientTop, CitadelColors.ctaGradientBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: CitadelColors.primary.withAlpha(50),
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