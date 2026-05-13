import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/document_upload.dart';
import '../../../services/document_upload_service.dart';
import '../widgets/signup_progress_bar.dart' show SignupProgressBar;
import 'package:citadel_first/core/theme/citadel_colors.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────────
const _warnAmber   = Color(0xFFF59E0B);

class DocumentReviewScreen extends StatefulWidget {
  final DocumentUploadResult result;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;

  const DocumentReviewScreen({
    super.key,
    required this.result,
    required this.onConfirm,
    required this.onRetry,
  });

  @override
  State<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends State<DocumentReviewScreen>
    with SingleTickerProviderStateMixin {
  final _svc     = DocumentUploadService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _icCtrl;
  DateTime? _dobValue;

  String? _nationalityValue;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  String? _genderValue;
  bool _isSaving = false;
  String? _error;

  // Per-field inline validation errors — populated on first submit attempt.
  final Map<String, String?> _fieldErrors = {
    'name':        null,
    'ic':          null,
    'dob':         null,
    'gender':      null,
    'nationality': null,
  };

  @override
  void initState() {
    super.initState();
    final ocr = widget.result.ocrResult;

    _nameCtrl    = TextEditingController(text: '');
    _icCtrl      = TextEditingController(text: ocr?.identityNumber ?? '');
    _genderValue = _normalizeGender(ocr?.gender);

    // Pre-select nationality — try direct name match first, then ISO alpha-3 lookup.
    final ocrNat = (ocr?.nationality ?? '').trim().toUpperCase();
    if (ocrNat.isNotEmpty) {
      final direct = _kAllCountries.firstWhere(
        (c) => c.toUpperCase() == ocrNat,
        orElse: () => '',
      );
      _nationalityValue = direct.isNotEmpty ? direct : null;
    }

    // Store DOB as DateTime instead of controller text
    _dobValue = ocr?.dateOfBirth;

    // Clear per-field error as the user edits each input.
    _nameCtrl.addListener(()        { if (_fieldErrors['name']        != null) setState(() => _fieldErrors['name']        = null); });
    _icCtrl.addListener(()          { if (_fieldErrors['ic']          != null) setState(() => _fieldErrors['ic']          = null); });

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _icCtrl.dispose();
    super.dispose();
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
                  children: [
                    _TopBar(onBack: () => Navigator.of(context).pop()),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Progress bar at step 3 = "ID Verify" ──────────
                            const SignupProgressBar(currentStep: 3),
                            const SizedBox(height: 18),

                            // ── Page heading ─────────────────────────────────
                            Text(
                              'Review Details',
                              style: GoogleFonts.bodoniModa(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: CitadelColors.textPrimary,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Please verify all information and correct any errors before continuing.',
                              style: GoogleFonts.jost(
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: CitadelColors.textMuted,
                                height: 1.6,
                              ),
                            ),

                            const SizedBox(height: 14),
                            const _VerifyNotice(),

                            const SizedBox(height: 22),

                            // ── Document preview card ─────────────────────────
                            _DocPreviewCard(
                              localPath: widget.result.frontLocalPath,
                              docType: widget.result.docType,
                            ),

                            const SizedBox(height: 28),

                            // ── Section: Personal Information ─────────────────
                            _SectionHeader(
                              icon: Icons.person_outline_rounded,
                              title: 'Personal Information',
                            ),
                            const SizedBox(height: 16),

                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _FieldRow(
                                    icon: Icons.badge_outlined,
                                    label: 'Full Name',
                                    controller: _nameCtrl,
                                    hint: 'As shown on document',
                                    textCapitalization: TextCapitalization.characters,
                                    error: _fieldErrors['name'],
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldRow(
                                    icon: Icons.credit_card_outlined,
                                    label: widget.result.docType == DocumentType.passport
                                        ? 'Passport Number'
                                        : 'IC / ID Number',
                                    controller: _icCtrl,
                                    hint: 'e.g. 801231-14-5678',
                                    textCapitalization: TextCapitalization.characters,
                                    error: _fieldErrors['ic'],
                                  ),
                                  const SizedBox(height: 14),
                                  _DatePickerField(
                                    value: _dobValue,
                                    error: _fieldErrors['dob'],
                                    onChanged: (date) => setState(() {
                                      _dobValue = date;
                                      _fieldErrors['dob'] = null;
                                    }),
                                  ),
                                  const SizedBox(height: 14),
                                  _GenderPicker(
                                    value: _genderValue,
                                    error: _fieldErrors['gender'],
                                    onChanged: (v) => setState(() {
                                      _genderValue = v;
                                      _fieldErrors['gender'] = null;
                                    }),
                                  ),
                                  const SizedBox(height: 14),
                                  _CountryPickerField(
                                    value: _nationalityValue,
                                    error: _fieldErrors['nationality'],
                                    onChanged: (country) => setState(() {
                                      _nationalityValue = country;
                                      _fieldErrors['nationality'] = null;
                                    }),
                                  ),

                                  // Registered Address section is handled separately in a later step
                                ],
                              ),
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              _ErrorBanner(message: _error!),
                            ],

                            const SizedBox(height: 32),

                            _ConfirmButton(
                              isLoading: _isSaving,
                              onConfirm: _onConfirm,
                              onRetry: widget.onRetry,
                            ),
                          ],
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

  /// Returns a map of field key → error message for every empty required field.
  Map<String, String> _validateFields() {
    final errors = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty)        errors['name']        = 'Full name is required';
    if (_icCtrl.text.trim().isEmpty)          errors['ic']          = 'IC / ID number is required';
    if (_dobValue == null)                    errors['dob']         = 'Date of birth is required';
    if (_genderValue == null)                 errors['gender']      = 'Please select your gender';
    if (_nationalityValue == null)           errors['nationality'] = 'Nationality is required';
    return errors;
  }

  Future<void> _onConfirm() async {
    // Run inline validation before calling the API.
    final errors = _validateFields();
    if (errors.isNotEmpty) {
      setState(() => _fieldErrors.addAll(errors));
      return;
    }

    setState(() { _isSaving = true; _error = null; });

    try {
      // Address is collected separately in a later step
      await _svc.confirmUserDetails(
        name:               _nameCtrl.text.trim(),
        identityCardNumber: _icCtrl.text.trim(),
        dob:                _dobValue,
        gender:             _genderValue,
        nationality:        _nationalityValue,
        address:            null,
      );
      widget.onConfirm();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: CitadelColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: CitadelColors.primary, size: 16),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.jost(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CitadelColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Document preview card ─────────────────────────────────────────────────────

class _DocPreviewCard extends StatelessWidget {
  final String? localPath;
  final DocumentType docType;

  const _DocPreviewCard({required this.localPath, required this.docType});

  @override
  Widget build(BuildContext context) {
    final file = localPath != null ? File(localPath!) : null;
    final fileExists = file != null && file.existsSync();

    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CitadelColors.primary.withAlpha(60), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Row(
          children: [
            // Thumbnail — 60% of card width
            Expanded(
              flex: 6,
              child: SizedBox(
                height: 110,
                child: fileExists
                    ? Image.file(file, fit: BoxFit.cover)
                    : Container(
                        color: CitadelColors.border,
                        child: Center(
                          child: Icon(_docIcon(docType), color: CitadelColors.textMuted, size: 28),
                        ),
                      ),
              ),
            ),
            // Divider line
            Container(width: 1, height: double.infinity, color: CitadelColors.border),
            // Doc type info — 40% of card width
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: CitadelColors.primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: CitadelColors.primary.withAlpha(50)),
                      ),
                      child: Text(
                        docType.label,
                        style: GoogleFonts.jost(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CitadelColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      docType.description,
                      style: GoogleFonts.jost(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: CitadelColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Captured',
                          style: GoogleFonts.jost(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: CitadelColors.textBody,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _docIcon(DocumentType type) => switch (type) {
    DocumentType.mykad     => Icons.badge_outlined,
    DocumentType.passport  => Icons.flight_outlined,
    DocumentType.mytentera => Icons.shield_outlined,
  };
}

// ── Verify notice ─────────────────────────────────────────────────────────────

class _VerifyNotice extends StatelessWidget {
  const _VerifyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _warnAmber.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warnAmber.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _warnAmber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Please verify all fields carefully and fill in the required information manually.',
              style: GoogleFonts.jost(fontSize: 12, color: _warnAmber),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field row ─────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;
  final String? error;

  // ignore: unused_element_parameter
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    // ignore: unused_element_parameter
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    // ignore: unused_element_parameter
    this.maxLines = 1,
    // ignore: unused_element_parameter
    this.minLines,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: hasError ? Colors.red.shade400 : CitadelColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.jost(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasError ? Colors.red.shade400 : CitadelColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: hasError ? Colors.red.withAlpha(10) : Colors.white.withAlpha(6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? Colors.red.withAlpha(120) : CitadelColors.border,
              width: hasError ? 1.2 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            minLines: minLines,
            style: GoogleFonts.jost(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: CitadelColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.jost(fontSize: 14, color: CitadelColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 12, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                error!,
                style: GoogleFonts.jost(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Gender picker ─────────────────────────────────────────────────────────────

class _GenderPicker extends StatelessWidget {
  final String? value;
  final String? error;
  final ValueChanged<String?> onChanged;

  const _GenderPicker({
    required this.value,
    required this.onChanged,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.wc_outlined, size: 13, color: hasError ? Colors.red.shade400 : CitadelColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'Gender',
              style: GoogleFonts.jost(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasError ? Colors.red.shade400 : CitadelColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            _GenderChip(
              label: 'Male',
              value: 'MALE',
              selected: value == 'MALE',
              hasError: hasError,
              onTap: () => onChanged('MALE'),
            ),
            const SizedBox(width: 10),
            _GenderChip(
              label: 'Female',
              value: 'FEMALE',
              selected: value == 'FEMALE',
              hasError: hasError,
              onTap: () => onChanged('FEMALE'),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 12, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                error!,
                style: GoogleFonts.jost(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    Color textColor;

    if (selected) {
      borderColor = CitadelColors.primary;
      bgColor     = CitadelColors.primary.withAlpha(28);
      textColor   = CitadelColors.primary;
    } else if (hasError) {
      borderColor = Colors.red.withAlpha(120);
      bgColor     = Colors.red.withAlpha(10);
      textColor   = CitadelColors.textBody;
    } else {
      borderColor = CitadelColors.border;
      bgColor     = Colors.white.withAlpha(6);
      textColor   = CitadelColors.textBody;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: hasError && !selected ? 1.2 : 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.jost(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ── Confirm button ────────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;

  const _ConfirmButton({
    required this.isLoading,
    required this.onConfirm,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E6DA4), Color(0xFF1B4F7A)],
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
              onPressed: isLoading ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirm & Continue',
                          style: GoogleFonts.jost(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: onRetry,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded, size: 15, color: CitadelColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Retry Scan',
                  style: GoogleFonts.jost(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CitadelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Date picker field ─────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final DateTime? value;
  final String? error;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.value,
    required this.onChanged,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final isEmpty = value == null;

    String displayText() {
      if (value == null) return '';
      return '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 13, color: hasError ? Colors.red.shade400 : CitadelColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'Date of Birth',
              style: GoogleFonts.jost(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasError ? Colors.red.shade400 : CitadelColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: () => _openPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: hasError ? Colors.red.withAlpha(10) : Colors.white.withAlpha(6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? Colors.red.withAlpha(120) : CitadelColors.border,
                width: hasError ? 1.2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEmpty ? 'YYYY-MM-DD' : displayText(),
                    style: GoogleFonts.jost(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isEmpty ? CitadelColors.textMuted : CitadelColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_month_rounded,
                  color: hasError ? Colors.red.shade400 : CitadelColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 12, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                error!,
                style: GoogleFonts.jost(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: CitadelColors.primary,
              onPrimary: Colors.white,
              surface: Color(0xFF0F2035),
              onSurface: CitadelColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0F2035),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}

// ── OCR normalisation helpers ─────────────────────────────────────────────────

String? _normalizeGender(String? raw) {
  if (raw == null) return null;
  switch (raw.trim().toUpperCase()) {
    case 'M':
    case 'MALE':
      return 'MALE';
    case 'F':
    case 'FEMALE':
      return 'FEMALE';
    default:
      return null;
  }
}

// ── Country list ─────────────────────────────────────────────────────────────

const _kAllCountries = <String>[
  'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola',
  'Antigua and Barbuda', 'Argentina', 'Armenia', 'Australia', 'Austria',
  'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados',
  'Belarus', 'Belgium', 'Belize', 'Benin', 'Bhutan',
  'Bolivia', 'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'Brunei',
  'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia',
  'Cameroon', 'Canada', 'Central African Republic', 'Chad', 'Chile',
  'China', 'Colombia', 'Comoros', 'Congo', 'Costa Rica',
  'Croatia', 'Cuba', 'Cyprus', 'Czech Republic', 'Denmark',
  'Djibouti', 'Dominica', 'Dominican Republic', 'Ecuador', 'Egypt',
  'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini',
  'Ethiopia', 'Fiji', 'Finland', 'France', 'Gabon',
  'Gambia', 'Georgia', 'Germany', 'Ghana', 'Greece',
  'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana',
  'Haiti', 'Honduras', 'Hungary', 'Iceland', 'India',
  'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel',
  'Italy', 'Jamaica', 'Japan', 'Jordan', 'Kazakhstan',
  'Kenya', 'Kiribati', 'Kuwait', 'Kyrgyzstan', 'Laos',
  'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya',
  'Liechtenstein', 'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi',
  'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands',
  'Mauritania', 'Mauritius', 'Mexico', 'Micronesia', 'Moldova',
  'Monaco', 'Mongolia', 'Montenegro', 'Morocco', 'Mozambique',
  'Myanmar', 'Namibia', 'Nauru', 'Nepal', 'Netherlands',
  'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'North Korea',
  'North Macedonia', 'Norway', 'Oman', 'Pakistan', 'Palau',
  'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru',
  'Philippines', 'Poland', 'Portugal', 'Qatar', 'Romania',
  'Russia', 'Rwanda', 'Saint Kitts and Nevis', 'Saint Lucia',
  'Saint Vincent and the Grenadines', 'Samoa', 'San Marino',
  'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia',
  'Seychelles', 'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia',
  'Solomon Islands', 'Somalia', 'South Africa', 'South Korea', 'South Sudan',
  'Spain', 'Sri Lanka', 'Sudan', 'Suriname', 'Sweden',
  'Switzerland', 'Syria', 'Taiwan', 'Tajikistan', 'Tanzania',
  'Thailand', 'Timor-Leste', 'Togo', 'Tonga', 'Trinidad and Tobago',
  'Tunisia', 'Turkey', 'Turkmenistan', 'Tuvalu', 'Uganda',
  'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States',
  'Uruguay', 'Uzbekistan', 'Vanuatu', 'Vatican City', 'Venezuela',
  'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe',
];

// ── Country picker field ──────────────────────────────────────────────────────

class _CountryPickerField extends StatelessWidget {
  final String? value;
  final String? error;
  final ValueChanged<String> onChanged;

  const _CountryPickerField({
    required this.value,
    required this.onChanged,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final isEmpty  = value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined,
                size: 13, color: hasError ? Colors.red.shade400 : CitadelColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'Nationality',
              style: GoogleFonts.jost(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasError ? Colors.red.shade400 : CitadelColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: () => _openPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: hasError ? Colors.red.withAlpha(10) : Colors.white.withAlpha(6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? Colors.red.withAlpha(120) : CitadelColors.border,
                width: hasError ? 1.2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEmpty ? 'Select country' : value!,
                    style: GoogleFonts.jost(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isEmpty ? CitadelColors.textMuted : CitadelColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: hasError ? Colors.red.shade400 : CitadelColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 12, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                error!,
                style: GoogleFonts.jost(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(
        current: value,
        onSelected: (country) {
          Navigator.pop(context);
          onChanged(country);
        },
      ),
    );
  }
}

// ── Country picker sheet ──────────────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  final String? current;
  final ValueChanged<String> onSelected;

  const _CountryPickerSheet({required this.current, required this.onSelected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = _kAllCountries;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _kAllCountries
          : _kAllCountries
              .where((c) => c.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + bottomInset,
      decoration: const BoxDecoration(
        color: Color(0xFF0F2035),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: CitadelColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: GoogleFonts.jost(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, color: CitadelColors.textMuted, size: 16),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CitadelColors.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: GoogleFonts.jost(fontSize: 14, color: CitadelColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search country…',
                  hintStyle: GoogleFonts.jost(fontSize: 14, color: CitadelColors.textMuted),
                  prefixIcon:
                      const Icon(Icons.search, color: CitadelColors.textMuted, size: 18),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Country list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: GoogleFonts.jost(
                          fontSize: 13, color: CitadelColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final country  = _filtered[i];
                      final selected = country == widget.current;
                      return GestureDetector(
                        onTap: () => widget.onSelected(country),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: selected
                                ? CitadelColors.primary.withAlpha(18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  country,
                                  style: GoogleFonts.jost(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selected ? CitadelColors.primary : CitadelColors.textBody,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(Icons.check_rounded,
                                    color: CitadelColors.primary, size: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          SizedBox(height: bottomInset + 12),
        ],
      ),
    );
  }
}

// ── Page background ───────────────────────────────────────────────────────────

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
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [CitadelColors.primary.withAlpha(18), CitadelColors.primaryDark.withAlpha(6), Colors.transparent],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [CitadelColors.primaryDark.withAlpha(12), Colors.transparent],
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
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [CitadelColors.primary.withAlpha(12), Colors.transparent],
                    ),
                  ),
                ),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                  child: Opacity(
                    opacity: 0.05,
                    child: Image.asset(
                      'assets/images/launcher_icon.png',
                      width: 180,
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

// ── Top bar ───────────────────────────────────────────────────────────────────

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

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jost(fontSize: 12, color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
  }
}
