import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import 'widgets/signup_progress_bar.dart';

// ── Brand tokens ───────────────────────────────────────────────────────────────
const _bgPrimary   = Color(0xFF0A0F1E);
const _bgCard      = Color(0xFF111827);
const _cyan        = Color(0xFF29ABE2);
const _cyanDim     = Color(0xFF1A7BA8);
const _textHeading = Color(0xFFE2E8F0);
const _textBody    = Color(0xFFCBD5E1);
const _textMuted   = Color(0xFF94A3B8);
const _inputBorder = Color(0xFF1E2D40);
const _inputFill   = Color(0xFF0D1B2E);
const _errorRed    = Color(0xFFEF4444);

class TrustFormB6Screen extends StatefulWidget {
  const TrustFormB6Screen({super.key});

  @override
  State<TrustFormB6Screen> createState() => _TrustFormB6ScreenState();
}

class _TrustFormB6ScreenState extends State<TrustFormB6Screen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  DateTime? _trustDeedDate;
  final _amountCtrl     = TextEditingController();
  final _advisorNameCtrl = TextEditingController();
  final _advisorNricCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _amountCtrl.dispose();
    _advisorNameCtrl.dispose();
    _advisorNricCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _trustDeedDate ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _cyan,
            onPrimary: Colors.white,
            surface: _bgCard,
            onSurface: _textHeading,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: _bgPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _trustDeedDate = picked;
        _errorMessage = null;
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _toIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _onSubmit() async {
    setState(() => _errorMessage = null);

    if (_trustDeedDate == null) {
      setState(() => _errorMessage = 'Please select the date of trust deed.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient().post(
        ApiEndpoints.trustFormB6,
        data: {
          'trust_deed_date'    : _toIsoDate(_trustDeedDate!),
          'trust_asset_amount' : _amountCtrl.text.trim(),
          'advisor_name'       : _advisorNameCtrl.text.trim(),
          'advisor_nric'       : _advisorNricCtrl.text.trim(),
        },
      );
      final recordId = (response.data['id'] as num).toInt();
      if (mounted) context.push('/signup/client/trust-form-b6-pdf', extra: recordId);
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
      backgroundColor: _bgPrimary,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _textMuted,
                          size: 20,
                        ),
                        tooltip: 'Back',
                      ),
                    ],
                  ),
                ),

                // ── Scrollable body ─────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SignupProgressBar(currentStep: 7),
                          const SizedBox(height: 14),

                          // ── Heading ────────────────────────────────────
                          Text(
                            'Asset Allocation Form',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: _textHeading,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please complete Form B6 — Asset Allocation Direction Form '
                            'with your trust and advisor details.',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              color: _textMuted,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Trust Information section ──────────────────
                          _SectionLabel(label: 'Trust Information'),
                          const SizedBox(height: 12),

                          _DatePickerField(
                            label: 'Date of Trust Deed Signed',
                            value: _trustDeedDate != null
                                ? _formatDate(_trustDeedDate!)
                                : null,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 24),

                          // ── Form B6 section ────────────────────────────
                          _SectionLabel(label: 'Form B6 — Asset Allocation Details'),
                          const SizedBox(height: 12),

                          _FormField(
                            controller: _amountCtrl,
                            label: 'Trust Asset Amount (MYR)',
                            hint: 'e.g. 500000.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Amount is required';
                              final parsed = double.tryParse(v.trim());
                              if (parsed == null || parsed <= 0) return 'Enter a valid amount greater than zero';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _FormField(
                            controller: _advisorNameCtrl,
                            label: 'Advisor Name',
                            hint: 'Full name as per NRIC',
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Advisor name is required' : null,
                          ),
                          const SizedBox(height: 16),

                          _FormField(
                            controller: _advisorNricCtrl,
                            label: 'Advisor NRIC',
                            hint: 'e.g. 801231-14-5678',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d\-]')),
                              LengthLimitingTextInputFormatter(14),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Advisor NRIC is required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Error banner ───────────────────────────────
                          if (_errorMessage != null) ...[
                            _ErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 16),
                          ],

                          const SizedBox(height: 24),

                          // ── CTA ────────────────────────────────────────
                          _CtaButton(
                            isLoading: _isLoading,
                            onPressed: _onSubmit,
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
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 3, height: 16,
            decoration: BoxDecoration(
              color: _cyan,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textBody,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Date picker field ──────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null ? _cyan.withAlpha(100) : _inputBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                color: value != null ? _cyan : _textMuted, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value ?? 'Select date',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: value != null ? FontWeight.w500 : FontWeight.w400,
                      color: value != null ? _textHeading : _textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Text form field ────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.ibmPlexSans(fontSize: 14, color: _textHeading),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.ibmPlexSans(fontSize: 13, color: _textMuted),
        hintStyle: GoogleFonts.ibmPlexSans(fontSize: 13, color: _textMuted.withAlpha(120)),
        filled: true,
        fillColor: _inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _inputBorder, width: 1),
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
        errorStyle: GoogleFonts.ibmPlexSans(fontSize: 12, color: _errorRed),
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
        color: _errorRed.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errorRed.withAlpha(80), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _errorRed, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13, color: _errorRed, height: 1.5,
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
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_cyan, _cyanDim],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: _cyan.withAlpha(55),
              blurRadius: 18,
              offset: const Offset(0, 4),
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
              borderRadius: BorderRadius.circular(13),
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
              : Text(
                  'Submit & Continue',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
        ),
      ),
    );
  }
}
