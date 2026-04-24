import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../models/pep_declaration.dart';
import '../../services/document_upload_service.dart';
import 'widgets/dropdown_data.dart';
import 'widgets/signup_progress_bar.dart' show SignupProgressBar;

// ── Brand tokens — Liquid Glass Dark (Citadel Navy) ──────────────────────────
const _bgPrimary   = Color(0xFF0C1829);
const _cyan        = Color(0xFF29ABE2);
const _cyanDim     = Color(0xFF1A7BA8);
const _textHeading = Color(0xFFE2E8F0);
const _textBody    = Color(0xFFCBD5E1);
const _textMuted   = Color(0xFF64748B);
const _borderGlass = Color(0xFF1E3A5F);
const _errorRed    = Color(0xFFEF4444);
const _ctaTop      = Color(0xFF2E6DA4);
const _ctaBottom   = Color(0xFF1B4F7A);

// ── Glass card decoration helper ────────────────────────────────────────────
BoxDecoration _glassCardDecoration() => BoxDecoration(
  color: Colors.white.withAlpha(6),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _borderGlass.withAlpha(60), width: 1),
);

// ── Section header row ───────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _cyan),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.jost(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textHeading,
          ),
        ),
      ],
    );
  }
}

class PepDeclarationScreen extends StatefulWidget {
  const PepDeclarationScreen({super.key});

  @override
  State<PepDeclarationScreen> createState() => _PepDeclarationScreenState();
}

class _PepDeclarationScreenState extends State<PepDeclarationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  bool? _isPep; // null = unselected, true = Yes, false = No
  String? _relationship;
  final _nameCtrl        = TextEditingController();
  final _positionCtrl    = TextEditingController();
  final _organisationCtrl = TextEditingController();

  bool _isLoading    = false;
  String? _errorMessage;

  // Supporting document upload state
  final _uploadService = DocumentUploadService();
  String? _supportingDocKey;
  String? _supportingDocName;
  bool _isUploadingDoc = false;

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
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _organisationCtrl.dispose();
    super.dispose();
  }

  bool get _showPepFields => _isPep == true;
  bool get _showNameField =>
      _showPepFields &&
      _relationship != null &&
      _relationship != 'Self';

  String? _nameLabel() {
    if (_relationship == 'Immediate Family Member') {
      return 'Full Name of Immediate Family';
    }
    if (_relationship == 'Close Associate') {
      return 'Full Name of Close Associate';
    }
    return null;
  }

  Future<void> _pickAndUploadDocument() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    final filename = xFile.name;

    setState(() {
      _isUploadingDoc = true;
      _errorMessage = null;
    });

    try {
      // 1. Get presigned URL
      final presigned = await _uploadService.getPresignedUrl(
        filename: 'pep_doc_${DateTime.now().millisecondsSinceEpoch}_$filename',
        contentType: 'image/jpeg',
      );

      // 2. Upload to S3
      await _uploadService.uploadFileToS3(file, presigned.uploadUrl);

      // 3. Store the S3 key
      setState(() {
        _supportingDocKey = presigned.key;
        _supportingDocName = filename;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Document upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploadingDoc = false);
    }
  }

  Future<void> _onContinue() async {
    setState(() => _errorMessage = null);

    if (_isPep == null) {
      setState(() => _errorMessage = 'Please select Yes or No to continue.');
      return;
    }

    if (_isPep == true && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final data = PepDeclarationData(
        isPep: _isPep!,
        relationship: _isPep! ? _relationshipFromSelection() : null,
        name: _isPep! && _showNameField ? _nameCtrl.text.trim() : null,
        position: _isPep! ? _positionCtrl.text.trim() : null,
        organisation: _isPep! ? _organisationCtrl.text.trim() : null,
        supportingDocKey: _isPep! ? _supportingDocKey : null,
      );

      await ApiClient().patch(ApiEndpoints.pepDeclaration, data: data.toJson());

      if (mounted) context.push('/signup/client/onboarding-agreement');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ?? 'Something went wrong. Please try again.';
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  PepRelationship? _relationshipFromSelection() {
    switch (_relationship) {
      case 'Self':
        return PepRelationship.self;
      case 'Immediate Family Member':
        return PepRelationship.familyMember;
      case 'Close Associate':
        return PepRelationship.closeAssociate;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                              // ── Decorative header ──────────────────────────
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
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.gavel_outlined,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'PEP Declaration',
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
                                      'Are you a politically exposed person? (PEP)',
                                      style: GoogleFonts.jost(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: _textBody,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        'A senior military, government or political official of any '
                                        'country? A senior executive of a state-owned corporation, or '
                                        'an immediate family member or close associate of such a person?',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.jost(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w300,
                                          color: _textMuted,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // ── Card 1: PEP Status ──────────────────────────
                              Container(
                                decoration: _glassCardDecoration(),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionHeader(
                                      icon: Icons.check_circle_outline,
                                      title: 'PEP Status',
                                    ),
                                    const SizedBox(height: 16),
                                    _PepToggle(
                                      isPep: _isPep,
                                      onSelected: (v) => setState(() {
                                        _isPep = v;
                                        _errorMessage = null;
                                        if (!v) {
                                          _relationship = null;
                                          _nameCtrl.clear();
                                          _positionCtrl.clear();
                                          _organisationCtrl.clear();
                                          _supportingDocKey = null;
                                          _supportingDocName = null;
                                        }
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Card 2: PEP Details (conditional) ───────────
                              AnimatedSize(
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: AnimatedOpacity(
                                  opacity: _showPepFields ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: !_showPepFields
                                      ? const SizedBox.shrink()
                                      : Container(
                                          decoration: _glassCardDecoration(),
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const _SectionHeader(
                                                icon: Icons.person_outline,
                                                title: 'PEP Details',
                                              ),
                                              const SizedBox(height: 16),

                                              // ── Relationship ───────────────────
                                              _FieldLabel(
                                                label: 'Relationship',
                                                required: true,
                                              ),
                                              const SizedBox(height: 6),
                                              _DropdownField(
                                                value: _relationship,
                                                hint: 'Select relationship',
                                                items: kPepRelationshipOptions,
                                                icon: Icons
                                                    .person_outline_rounded,
                                                validator: (v) => v == null
                                                    ? 'Relationship is required'
                                                    : null,
                                                onChanged: (v) => setState(() {
                                                  _relationship = v;
                                                  _nameCtrl.clear();
                                                }),
                                              ),
                                              const SizedBox(height: 20),

                                              // ── Full Name (conditional) ────────
                                              AnimatedSize(
                                                duration: const Duration(
                                                    milliseconds: 380),
                                                curve: Curves.easeOutCubic,
                                                alignment: Alignment.topCenter,
                                                child: AnimatedOpacity(
                                                  opacity: _showNameField
                                                      ? 1.0
                                                      : 0.0,
                                                  duration: const Duration(
                                                      milliseconds: 300),
                                                  child: !_showNameField
                                                      ? const SizedBox.shrink()
                                                      : Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            _FieldLabel(
                                                              label:
                                                                  _nameLabel() ?? 'Full Name',
                                                              required: true,
                                                            ),
                                                            const SizedBox(
                                                                height: 6),
                                                            _InputField(
                                                              controller:
                                                                  _nameCtrl,
                                                              hint:
                                                                  'Enter full name',
                                                              prefixIcon: Icons
                                                                  .badge_outlined,
                                                              validator: (v) => (v ==
                                                                          null ||
                                                                      v.trim()
                                                                          .isEmpty)
                                                                  ? 'Name is required'
                                                                  : null,
                                                            ),
                                                            const SizedBox(
                                                                height: 20),
                                                          ],
                                                        ),
                                                ),
                                              ),

                                              // ── Current Position ──────────────
                                              _FieldLabel(
                                                label:
                                                    'Current Position / Designation',
                                                required: true,
                                              ),
                                              const SizedBox(height: 6),
                                              _InputField(
                                                controller: _positionCtrl,
                                                hint:
                                                    'e.g. Minister of Finance',
                                                prefixIcon: Icons
                                                    .work_outline_rounded,
                                                validator: (v) => (v == null ||
                                                        v.trim().isEmpty)
                                                    ? 'Position is required'
                                                    : null,
                                              ),
                                              const SizedBox(height: 20),

                                              // ── Organisation / Entity ────────
                                              _FieldLabel(
                                                label:
                                                    'Organisation / Entity',
                                                required: true,
                                              ),
                                              const SizedBox(height: 6),
                                              _InputField(
                                                controller: _organisationCtrl,
                                                hint:
                                                    'e.g. Ministry of Finance',
                                                prefixIcon: Icons
                                                    .apartment_outlined,
                                                validator: (v) => (v == null ||
                                                        v.trim().isEmpty)
                                                    ? 'Organisation is required'
                                                    : null,
                                              ),
                                              const SizedBox(height: 20),

                                              // ── Supporting Document Upload ──
                                              _FieldLabel(
                                                label:
                                                    'Supporting Document (membership, ID, etc.)',
                                              ),
                                              const SizedBox(height: 6),
                                              _DocumentUploadButton(
                                                isUploading: _isUploadingDoc,
                                                uploadedFileName: _supportingDocName,
                                                onTap: _isUploadingDoc
                                                    ? null
                                                    : _pickAndUploadDocument,
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),

                              // ── Error banner ──────────────────────────────────
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                _ErrorBanner(message: _errorMessage!),
                              ],

                              const SizedBox(height: 24),

                              // ── CTA ──────────────────────────────────────────
                              _CtaButton(
                                enabled: _isPep != null,
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

// ── PEP Yes/No toggle ────────────────────────────────────────────────────────

class _PepToggle extends StatelessWidget {
  final bool? isPep;
  final ValueChanged<bool> onSelected;

  const _PepToggle({required this.isPep, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleOption(
            label: 'Yes',
            selected: isPep == true,
            onTap: () => onSelected(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleOption(
            label: 'No',
            selected: isPep == false,
            onTap: () => onSelected(false),
          ),
        ),
      ],
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? _cyan.withAlpha(18) : Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _cyan.withAlpha(120) : _borderGlass.withAlpha(45),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: _cyan.withAlpha(35), blurRadius: 16, offset: const Offset(0, 4))]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.jost(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? _cyan : _textMuted,
              letterSpacing: 0.3,
            ),
          ),
        ),
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
                      colors: [_cyan.withAlpha(15), Colors.transparent],
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
              color: _cyan,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Input field ─────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: GoogleFonts.jost(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFF8FAFC),
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefixIcon, size: 18, color: _textMuted),
        hintStyle: GoogleFonts.jost(fontSize: 14, color: const Color(0xFF475569)),
        filled: true,
        fillColor: Colors.white.withAlpha(8),
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
    );
  }
}

// ── Dropdown field ──────────────────────────────────────────────────────────

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
      icon: Icon(Icons.expand_more_rounded, color: _textMuted, size: 20),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: _textMuted),
        filled: true,
        fillColor: Colors.white.withAlpha(8),
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
      dropdownColor: const Color(0xFF0F172A),
      style: GoogleFonts.jost(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFF8FAFC),
      ),
      menuMaxHeight: 280,
    );
  }
}

// ── Document upload button ───────────────────────────────────────────────────

class _DocumentUploadButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isUploading;
  final String? uploadedFileName;

  const _DocumentUploadButton({
    required this.onTap,
    this.isUploading = false,
    this.uploadedFileName,
  });

  @override
  Widget build(BuildContext context) {
    final isUploaded = uploadedFileName != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isUploaded
              ? _cyan.withAlpha(12)
              : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUploaded
                ? _cyan.withAlpha(80)
                : _borderGlass.withAlpha(60),
            width: 1,
          ),
        ),
        child: isUploading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _cyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Uploading...',
                    style: GoogleFonts.jost(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _textBody,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isUploaded
                        ? Icons.check_circle_outline_rounded
                        : Icons.upload_file_rounded,
                    size: 18,
                    color: isUploaded ? _cyan : _cyan,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isUploaded
                          ? uploadedFileName!
                          : 'Upload Supporting Document',
                      style: GoogleFonts.jost(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isUploaded ? _cyan : _textBody,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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

// ── CTA button ──────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _CtaButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.38,
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
            boxShadow: enabled
                ? [BoxShadow(color: _cyan.withAlpha(50), blurRadius: 22, offset: const Offset(0, 5))]
                : [],
          ),
          child: ElevatedButton(
            onPressed: (enabled && !isLoading) ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                      const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}