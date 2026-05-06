import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/constants/malaysian_banks.dart';
import '../../../core/theme/citadel_colors.dart';
import '../../../models/beneficiary.dart';
import '../../../models/settlor_profile.dart';
import 'widgets/document_upload_card.dart';

class BeneficiaryFormScreen extends StatefulWidget {
  final String beneficiaryType;
  final int? existingBeneficiaryId;
  final Beneficiary? existingBeneficiary;
  final double maxAllowedShare;
  final bool autoAssignShare;

  const BeneficiaryFormScreen({
    super.key,
    required this.beneficiaryType,
    this.existingBeneficiaryId,
    this.existingBeneficiary,
    this.maxAllowedShare = 100.0,
    this.autoAssignShare = false,
  });

  @override
  State<BeneficiaryFormScreen> createState() => _BeneficiaryFormScreenState();
}

class _BeneficiaryFormScreenState extends State<BeneficiaryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _api = ApiClient();

  // Controllers
  final _fullNameCtrl = TextEditingController();
  final _nricCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _residentialAddressCtrl = TextEditingController();
  final _mailingAddressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactNumberCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankSwiftCodeCtrl = TextEditingController();
  final _bankAddressCtrl = TextEditingController();
  final _sharePercentageCtrl = TextEditingController();

  String? _selectedGender;
  String? _selectedRelationship;
  String _selectedIdType = 'nric'; // 'nric' or 'passport'
  MalaysianBank _selectedBank = otherBank;
  bool _sameAsSettlor = false;
  bool _mailingSameAsResidential = false;
  bool _isLoading = false;
  bool _showValidation = false;
  bool _settlorProfileLoading = true;
  String? _settlorProfileError;
  SettlorProfile? _settlorProfile;

  // Accordion: only one section open at a time
  String _expandedSection = 'personal';

  // S3 upload keys
  String? _settlorNricKey;
  String? _proofOfAddressKey;
  String? _beneficiaryIdKey;
  String? _bankStatementKey;

  static const List<String> _genderOptions = ['Male', 'Female'];
  static const List<Map<String, String>> _relationshipOptions = [
    {'value': 'SPOUSE', 'label': 'Spouse'},
    {'value': 'CHILD', 'label': 'Child'},
    {'value': 'PARENT', 'label': 'Parent'},
    {'value': 'PARENTS', 'label': 'Parents'},
    {'value': 'SIBLING', 'label': 'Sibling'},
    {'value': 'GRANDPARENT', 'label': 'Grandparent'},
    {'value': 'GRAND_SON', 'label': 'Grandson'},
    {'value': 'GRAND_DAUGHTER', 'label': 'Granddaughter'},
    {'value': 'NIECE', 'label': 'Niece'},
    {'value': 'NEPHEW', 'label': 'Nephew'},
    {'value': 'PARTNER', 'label': 'Partner'},
    {'value': 'FIANCE', 'label': 'Fiancé/Fiancée'},
    {'value': 'FRIEND', 'label': 'Friend'},
    {'value': 'GUARDIAN', 'label': 'Guardian'},
    {'value': 'GOD_PARENT', 'label': 'Godparent'},
    {'value': 'MOTHER_IN_LAW', 'label': 'Mother-in-law'},
    {'value': 'FATHER_IN_LAW', 'label': 'Father-in-law'},
    {'value': 'SON_IN_LAW', 'label': 'Son-in-law'},
    {'value': 'DAUGHTER_IN_LAW', 'label': 'Daughter-in-law'},
    {'value': 'ASSOCIATE', 'label': 'Associate'},
    {'value': 'ADMINISTRATOR', 'label': 'Administrator'},
  ];

  Color get _typeColor => widget.beneficiaryType == 'pre_demise' ? CitadelColors.primary : CitadelColors.warning;
  bool get _isEditing => widget.existingBeneficiaryId != null;

  // ── Section completion checks ──────────────────────────────────────────────

  bool get _personalComplete {
    if (_sameAsSettlor) return true;
    return _fullNameCtrl.text.trim().isNotEmpty &&
        _selectedGender != null &&
        _dobCtrl.text.isNotEmpty &&
        _selectedRelationship != null &&
        _residentialAddressCtrl.text.trim().isNotEmpty &&
        _emailCtrl.text.trim().isNotEmpty &&
        _contactNumberCtrl.text.trim().isNotEmpty;
  }

  bool get _bankComplete {
    return _bankAccountNameCtrl.text.trim().isNotEmpty &&
        _bankAccountNumberCtrl.text.trim().isNotEmpty &&
        _bankNameCtrl.text.trim().isNotEmpty;
  }

  bool get _shareComplete {
    final v = double.tryParse(_sharePercentageCtrl.text);
    return v != null && v > 0 && v <= widget.maxAllowedShare + 0.01;
  }

  bool get _attachmentsComplete {
    return _settlorNricKey != null &&
        _proofOfAddressKey != null &&
        _beneficiaryIdKey != null &&
        _bankStatementKey != null;
  }

  @override
  void initState() {
    super.initState();
    _sharePercentageCtrl.addListener(_onShareChanged);
    if (_isEditing && widget.existingBeneficiary != null) {
      _populateFromExisting();
    } else if (widget.autoAssignShare) {
      _sharePercentageCtrl.text = widget.maxAllowedShare.toStringAsFixed(widget.maxAllowedShare == widget.maxAllowedShare.roundToDouble() ? 0 : 1);
    }
    _fetchSettlorProfile();
  }

  Future<void> _fetchSettlorProfile() async {
    try {
      final res = await _api.get(ApiEndpoints.userMeDetails);
      if (mounted && res.data != null) {
        setState(() {
          _settlorProfile = SettlorProfile.fromJson(res.data);
          _settlorProfileLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _settlorProfileError = 'Could not load settlor profile';
          _settlorProfileLoading = false;
        });
      }
    }
  }

  void _populateFromExisting() {
    final b = widget.existingBeneficiary!;
    _fullNameCtrl.text = b.fullName ?? '';
    _nricCtrl.text = b.nric ?? '';
    _idNumberCtrl.text = b.idNumber ?? '';
    if (b.nric != null && b.nric!.isNotEmpty) {
      _selectedIdType = 'nric';
    } else if (b.idNumber != null && b.idNumber!.isNotEmpty) {
      _selectedIdType = 'passport';
    }
    _selectedGender = b.gender;
    _dobCtrl.text = b.dob != null ? _formatDate(b.dob!) : '';
    _selectedRelationship = b.relationshipToSettlor;
    _residentialAddressCtrl.text = b.residentialAddress ?? '';
    _mailingAddressCtrl.text = b.mailingAddress ?? '';
    _emailCtrl.text = b.email ?? '';
    _contactNumberCtrl.text = b.contactNumber ?? '';
    _bankAccountNameCtrl.text = b.bankAccountName ?? '';
    _bankAccountNumberCtrl.text = b.bankAccountNumber ?? '';
    _bankNameCtrl.text = b.bankName ?? '';
    _bankSwiftCodeCtrl.text = b.bankSwiftCode ?? '';
    _selectedBank = malaysianBanks.where((bk) => bk.name == b.bankName).firstOrNull ?? otherBank;
    _bankAddressCtrl.text = b.bankAddress ?? '';
    _sharePercentageCtrl.text = b.sharePercentage?.toStringAsFixed(0) ?? '';
    _sameAsSettlor = b.sameAsSettlor;
    _settlorNricKey = b.settlorNricKey;
    _proofOfAddressKey = b.proofOfAddressKey;
    _beneficiaryIdKey = b.beneficiaryIdKey;
    _bankStatementKey = b.bankStatementKey;
  }

  void _applySettlorProfile() {
    final p = _settlorProfile;
    if (p == null) return;

    _fullNameCtrl.text = p.name ?? '';
    _selectedGender = p.gender;
    if (p.dob != null) _dobCtrl.text = _formatDate(p.dob!);
    _residentialAddressCtrl.text = p.residentialAddress ?? '';
    _mailingSameAsResidential = p.mailingSameAsResidential ?? false;
    if (_mailingSameAsResidential) {
      _mailingAddressCtrl.text = p.residentialAddress ?? '';
    } else {
      _mailingAddressCtrl.text = p.mailingAddress ?? '';
    }
    _emailCtrl.text = p.email ?? '';
    _contactNumberCtrl.text = p.mobileNumber ?? '';
    _selectedRelationship = 'SELF';

    if (p.isMyKadOrMyTentera) {
      _selectedIdType = 'nric';
      _nricCtrl.text = p.identityCardNumber ?? '';
      _idNumberCtrl.clear();
    } else if (p.isPassport) {
      _selectedIdType = 'passport';
      _idNumberCtrl.text = p.identityCardNumber ?? '';
      _nricCtrl.clear();
    } else {
      _selectedIdType = 'nric';
      if (p.identityCardNumber != null) {
        _nricCtrl.text = p.identityCardNumber ?? '';
      }
    }
  }

  void _clearSettlorFields() {
    _fullNameCtrl.clear();
    _nricCtrl.clear();
    _idNumberCtrl.clear();
    _selectedIdType = 'nric';
    _selectedGender = null;
    _dobCtrl.clear();
    _selectedRelationship = null;
    _residentialAddressCtrl.clear();
    _mailingAddressCtrl.clear();
    _mailingSameAsResidential = false;
    _emailCtrl.clear();
    _contactNumberCtrl.clear();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fullNameCtrl.dispose();
    _nricCtrl.dispose();
    _idNumberCtrl.dispose();
    _dobCtrl.dispose();
    _residentialAddressCtrl.dispose();
    _mailingAddressCtrl.dispose();
    _emailCtrl.dispose();
    _contactNumberCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankSwiftCodeCtrl.dispose();
    _bankAddressCtrl.dispose();
    _sharePercentageCtrl.removeListener(_onShareChanged);
    _sharePercentageCtrl.dispose();
    super.dispose();
  }

  void _onShareChanged() => setState(() {});

  // ── Shared InputDecoration ────────────────────────────────────────────────

  InputDecoration _fieldDecoration(
    String label, {
    Widget? suffixIcon,
    String? suffixText,
    Widget? prefixIcon,
    bool isRequired = false,
  }) {
    final displayLabel = isRequired ? '$label *' : label;
    return InputDecoration(
      labelText: displayLabel,
      labelStyle: GoogleFonts.jost(color: CitadelColors.textMuted, fontSize: 13, fontWeight: FontWeight.w400),
      floatingLabelStyle: GoogleFonts.jost(color: _typeColor, fontSize: 12, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: CitadelColors.background,
      hoverColor: CitadelColors.surfaceLight,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: GoogleFonts.jost(color: CitadelColors.textMuted),
      prefixIcon: prefixIcon,
      contentPadding: prefixIcon != null
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CitadelColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CitadelColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _typeColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CitadelColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CitadelColors.error, width: 1.5),
      ),
      errorStyle: GoogleFonts.jost(fontSize: 12, color: CitadelColors.error),
    );
  }

  // ── ID Type Button Option ──────────────────────────────────────────────────

  Widget _idTypeButton(String label, String value, IconData icon) {
    final isSelected = _selectedIdType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedIdType = value;
          _nricCtrl.clear();
          _idNumberCtrl.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _typeColor.withValues(alpha: 0.1) : CitadelColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _typeColor : CitadelColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? _typeColor : CitadelColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.jost(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? _typeColor : CitadelColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stepped group card ───────────────────────────────────────────────────

  Widget _steppedGroupCard({
    required String label,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(color: accentColor.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 14, color: accentColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: GoogleFonts.jost(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor.withValues(alpha: 0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Date Picker ───────────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: CitadelColors.primary,
              surface: CitadelColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dobCtrl.text = _formatDate(picked));
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveBeneficiary() async {
    setState(() => _isLoading = true);

    setState(() => _expandedSection = '_all');
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    if (!_showValidation) {
      setState(() => _showValidation = true);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      // Show specific error only when the ID field is filled but invalid;
      // otherwise use generic message for missing required fields
      String errorMsg = 'Please fill in all required fields';
      if (_selectedIdType == 'nric' && _nricCtrl.text.trim().isNotEmpty && _nricCtrl.text.trim().length != 12) {
        errorMsg = 'NRIC must be exactly 12 digits';
      }

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: CitadelColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final body = <String, dynamic>{
      'beneficiary_type': widget.beneficiaryType,
      'same_as_settlor': _sameAsSettlor,
      if (!_sameAsSettlor) ...{
        'full_name': _fullNameCtrl.text.trim(),
        'nric': _selectedIdType == 'nric' ? (_nricCtrl.text.trim().isEmpty ? null : _nricCtrl.text.trim()) : null,
        'id_number': _selectedIdType == 'passport' ? (_idNumberCtrl.text.trim().isEmpty ? null : _idNumberCtrl.text.trim()) : null,
        'gender': _selectedGender,
        if (_dobCtrl.text.isNotEmpty) 'dob': _parseDob(_dobCtrl.text),
        'relationship_to_settlor': _selectedRelationship,
        'residential_address': _residentialAddressCtrl.text.trim().isEmpty ? null : _residentialAddressCtrl.text.trim(),
        'mailing_address': _mailingSameAsResidential ? _residentialAddressCtrl.text.trim() : (_mailingAddressCtrl.text.trim().isEmpty ? null : _mailingAddressCtrl.text.trim()),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'contact_number': _contactNumberCtrl.text.trim().isEmpty ? null : _contactNumberCtrl.text.trim(),
      },
      'bank_account_name': _bankAccountNameCtrl.text.trim().isEmpty ? null : _bankAccountNameCtrl.text.trim(),
      'bank_account_number': _bankAccountNumberCtrl.text.trim().isEmpty ? null : _bankAccountNumberCtrl.text.trim(),
      'bank_name': _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      'bank_swift_code': _bankSwiftCodeCtrl.text.trim().isEmpty ? null : _bankSwiftCodeCtrl.text.trim(),
      'bank_address': _bankAddressCtrl.text.trim().isEmpty ? null : _bankAddressCtrl.text.trim(),
      'share_percentage': double.tryParse(_sharePercentageCtrl.text),
      if (_settlorNricKey != null) 'settlor_nric_key': _settlorNricKey,
      if (_proofOfAddressKey != null) 'proof_of_address_key': _proofOfAddressKey,
      if (_beneficiaryIdKey != null) 'beneficiary_id_key': _beneficiaryIdKey,
      if (_bankStatementKey != null) 'bank_statement_key': _bankStatementKey,
    };

    try {
      if (_isEditing) {
        await _api.patch('${ApiEndpoints.beneficiaries}/${widget.existingBeneficiaryId}', data: body);
      } else {
        await _api.post(ApiEndpoints.beneficiaries, data: body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Beneficiary updated successfully' : 'Beneficiary added successfully'),
            backgroundColor: CitadelColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save beneficiary: $e'), backgroundColor: CitadelColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '$d/$m/$y';
  }

  String? _parseDob(String dob) {
    try {
      final parts = dob.split('/');
      if (parts.length != 3) return null;
      final date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      return date.toIso8601String().split('T')[0];
    } catch (_) {
      return null;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        foregroundColor: CitadelColors.textPrimary,
        automaticallyImplyLeading: false,
        title: Text(
          _isEditing ? 'Edit Beneficiary' : 'Add Beneficiary',
          style: GoogleFonts.jost(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _showValidation ? AutovalidateMode.always : AutovalidateMode.disabled,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            const SizedBox(height: 4),

            _buildAccordionSection(
              key: 'personal',
              title: 'Personal Details',
              icon: Icons.person_outline_rounded,
              isComplete: _personalComplete,
              child: _buildPersonalDetailsContent(),
            ),
            const SizedBox(height: 12),

            _buildAccordionSection(
              key: 'bank',
              title: 'Bank Details',
              icon: Icons.account_balance_outlined,
              isComplete: _bankComplete,
              child: _bankDetailsFields(),
            ),
            const SizedBox(height: 12),

            _buildAccordionSection(
              key: 'share',
              title: 'Share Percentage',
              icon: Icons.pie_chart_outline_rounded,
              isComplete: _shareComplete,
              child: _sharePercentageFields(),
            ),
            const SizedBox(height: 12),

            _buildAccordionSection(
              key: 'attachments',
              title: 'Attachments',
              icon: Icons.attach_file_rounded,
              isComplete: _attachmentsComplete,
              child: _attachmentsFields(),
            ),
            const SizedBox(height: 36),

            _saveButton(),
            const SizedBox(height: 44),
          ],
        ),
      ),
    );
  }

  // ── Accordion Section ─────────────────────────────────────────────────────

  Widget _buildAccordionSection({
    required String key,
    required String title,
    required IconData icon,
    required bool isComplete,
    required Widget child,
  }) {
    final isExpanded = _expandedSection == key || _expandedSection == '_all';
    final accentColor = isComplete ? CitadelColors.success : _typeColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CitadelColors.surfaceLight, CitadelColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? accentColor.withValues(alpha: 0.4) : CitadelColors.border,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expandedSection = isExpanded ? '' : key),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Stack(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: Colors.white, size: 20),
                          ),
                          if (isComplete)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: CitadelColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: CitadelColors.surface, width: 2),
                                ),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.jost(fontSize: 16, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 250),
                      turns: isExpanded ? 0.5 : 0,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: isExpanded ? accentColor : CitadelColors.textMuted,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 18),
              child: child,
            ),
        ],
      ),
    );
  }

  // ── Personal Details Content ─────────────────────────────────────────────

  Widget _buildPersonalDetailsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettlorToggle(),
        const SizedBox(height: 14),
        Divider(color: CitadelColors.border.withValues(alpha: 0.5), height: 1),
        const SizedBox(height: 14),
        if (_sameAsSettlor) _buildSettlorPreview() else _buildPersonalDetailsFields(),
      ],
    );
  }

  // ── Same as Settlor Toggle ────────────────────────────────────────────────

  Widget _buildSettlorToggle() {
    final isDisabled = _settlorProfileLoading || _settlorProfileError != null;
    return GestureDetector(
      onTap: isDisabled ? null : () {
        setState(() {
          _sameAsSettlor = !_sameAsSettlor;
          if (_sameAsSettlor) {
            _applySettlorProfile();
          } else {
            _clearSettlorFields();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _sameAsSettlor ? _typeColor.withValues(alpha: 0.08) : CitadelColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _sameAsSettlor ? _typeColor.withValues(alpha: 0.4) : CitadelColors.border),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sameAsSettlor ? _typeColor : Colors.transparent,
                border: Border.all(color: _sameAsSettlor ? _typeColor : CitadelColors.textMuted, width: 2),
              ),
              child: _sameAsSettlor ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Same as Settlor', style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
                  const SizedBox(height: 1),
                  Text(
                    isDisabled ? 'Settlor profile unavailable' : 'Auto-fill personal details from your profile',
                    style: GoogleFonts.jost(fontSize: 11, color: isDisabled ? CitadelColors.error : CitadelColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Settlor Profile Preview ──────────────────────────────────────────────

  Widget _buildSettlorPreview() {
    final p = _settlorProfile;
    if (p == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _typeColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _typeColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _typeColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Personal details will be pre-filled from your settlor profile. Only bank details and share percentage are required.',
                style: GoogleFonts.jost(fontSize: 12, color: CitadelColors.textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    String? idLabel;
    String? idValue;
    if (p.isMyKadOrMyTentera) {
      idLabel = p.identityDocType == 'MYTENTERA' ? 'MyTentera' : 'NRIC';
      idValue = p.identityCardNumber;
    } else if (p.isPassport) {
      idLabel = 'Passport No.';
      idValue = p.identityCardNumber;
    } else {
      idLabel = 'IC Number';
      idValue = p.identityCardNumber;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.lock_outline_rounded, color: _typeColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settlor Profile', style: GoogleFonts.jost(fontSize: 14, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
                  Text('Read-only — from your registered profile', style: GoogleFonts.jost(fontSize: 10, color: CitadelColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _profileRow('Full Name', p.name),
        if (idValue != null) _profileRow(idLabel, idValue),
        _profileRow('Gender', p.gender),
        _profileRow('Date of Birth', p.dob != null ? _formatDate(p.dob!) : null),
        _profileRow('Relationship', 'Self'),
        _profileRow('Residential Address', p.residentialAddress),
        if (p.mailingSameAsResidential != true && p.mailingAddress != null) _profileRow('Mailing Address', p.mailingAddress),
        _profileRow('Email', p.email),
        _profileRow('Contact Number', p.mobileNumber),
      ],
    );
  }

  Widget _profileRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.jost(fontSize: 10, fontWeight: FontWeight.w500, color: CitadelColors.textMuted, letterSpacing: 0.3)),
                const SizedBox(height: 1),
                Text(
                  value ?? 'N/A',
                  style: GoogleFonts.jost(fontSize: 13, color: value != null ? CitadelColors.textPrimary : CitadelColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Personal Details Fields ──────────────────────────────────────────────

  Widget _buildPersonalDetailsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Identity group ──
        _steppedGroupCard(
          label: 'Identity',
          icon: Icons.badge_outlined,
          accentColor: _typeColor,
          children: [
            TextFormField(
              controller: _fullNameCtrl,
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(
                'Full Name (as per ID)',
                isRequired: true,
                prefixIcon: const Icon(Icons.person_outline_rounded, color: CitadelColors.textMuted, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter full name' : null,
            ),
            const SizedBox(height: 12),

            // ID type button selector
            Row(
              children: [
                _idTypeButton('NRIC', 'nric', Icons.badge_outlined),
                const SizedBox(width: 10),
                _idTypeButton('Passport', 'passport', Icons.flight_outlined),
              ],
            ),
            const SizedBox(height: 12),

            // Conditional ID field based on selection
            if (_selectedIdType == 'nric')
              TextFormField(
                key: const Key('nric_field'),
                controller: _nricCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 12,
                style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
                decoration: _fieldDecoration(
                  'NRIC Number',
                  isRequired: true,
                  prefixIcon: const Icon(Icons.badge_outlined, color: CitadelColors.textMuted, size: 18),
                ).copyWith(counterText: ''),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter NRIC number';
                  if (v.trim().length != 12) return 'NRIC must be exactly 12 digits';
                  return null;
                },
              )
            else
              TextFormField(
                key: const Key('passport_field'),
                controller: _idNumberCtrl,
                style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
                decoration: _fieldDecoration(
                  'Passport Number',
                  isRequired: true,
                  prefixIcon: const Icon(Icons.flight_outlined, color: CitadelColors.textMuted, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter passport number' : null,
              ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: ValueKey('gender_$_selectedGender'),
              initialValue: _selectedGender,
              decoration: _fieldDecoration('Gender', isRequired: true),
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              dropdownColor: CitadelColors.surface,
              items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.jost()))).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
              validator: (v) => v == null ? 'Please select gender' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dobCtrl,
              readOnly: true,
              onTap: () => _selectDate(context),
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(
                'Date of Birth',
                isRequired: true,
                suffixIcon: const Icon(Icons.calendar_today_rounded, color: CitadelColors.textMuted, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please select date of birth' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: ValueKey('relationship_$_selectedRelationship'),
              initialValue: _selectedRelationship,
              decoration: _fieldDecoration('Relationship to Settlor', isRequired: true),
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              dropdownColor: CitadelColors.surface,
              items: _relationshipOptions.map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!, style: GoogleFonts.jost()))).toList(),
              onChanged: (v) => setState(() => _selectedRelationship = v),
              validator: (v) => v == null ? 'Please select relationship' : null,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Address group ──
        _steppedGroupCard(
          label: 'Address',
          icon: Icons.home_outlined,
          accentColor: _typeColor,
          children: [
            TextFormField(
              controller: _residentialAddressCtrl,
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              maxLines: 2,
              decoration: _fieldDecoration(
                'Residential Address',
                isRequired: true,
                prefixIcon: const Icon(Icons.home_outlined, color: CitadelColors.textMuted, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter residential address' : null,
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: () => setState(() => _mailingSameAsResidential = !_mailingSameAsResidential),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _mailingSameAsResidential ? _typeColor : Colors.transparent,
                      border: Border.all(color: _mailingSameAsResidential ? _typeColor : CitadelColors.textMuted, width: 2),
                    ),
                    child: _mailingSameAsResidential ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                  ),
                  const SizedBox(width: 8),
                  Text('Same as residential address', style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textSecondary)),
                ],
              ),
            ),
            if (!_mailingSameAsResidential) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _mailingAddressCtrl,
                style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
                maxLines: 2,
                decoration: _fieldDecoration('Mailing Address'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // ── Contact group ──
        _steppedGroupCard(
          label: 'Contact',
          icon: Icons.contact_phone_outlined,
          accentColor: CitadelColors.success,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(
                'Email',
                isRequired: true,
                prefixIcon: const Icon(Icons.email_outlined, color: CitadelColors.textMuted, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactNumberCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              decoration: _fieldDecoration(
                'Contact Number',
                isRequired: true,
                prefixIcon: const Icon(Icons.phone_outlined, color: CitadelColors.textMuted, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter contact number' : null,
            ),
          ],
        ),
      ],
    );
  }

  // ── Bank Details Fields ──────────────────────────────────────────────────

  Widget _bankDetailsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Account group ──
        _steppedGroupCard(
          label: 'Account',
          icon: Icons.account_balance_wallet_outlined,
          accentColor: _typeColor,
          children: [
            TextFormField(
              controller: _bankAccountNameCtrl,
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              decoration: _fieldDecoration('Account Name', isRequired: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter account name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankAccountNumberCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              decoration: _fieldDecoration('Account Number', isRequired: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter account number' : null,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Bank info group ──
        _steppedGroupCard(
          label: 'Bank Info',
          icon: Icons.account_balance_outlined,
          accentColor: _typeColor,
          children: [
            DropdownButtonFormField<MalaysianBank>(
              key: ValueKey('bank_${_selectedBank.name}'),
              initialValue: _selectedBank,
              isExpanded: true,
              decoration: _fieldDecoration('Bank Name', isRequired: true),
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              dropdownColor: CitadelColors.surface,
              items: [
                ...malaysianBanks.map((b) => DropdownMenuItem(
                  value: b,
                  child: Text(b.name, style: GoogleFonts.jost()),
                )),
                DropdownMenuItem(
                  value: otherBank,
                  child: Text('Other', style: GoogleFonts.jost(fontStyle: FontStyle.italic)),
                ),
              ],
              onChanged: (b) {
                setState(() {
                  _selectedBank = b ?? otherBank;
                  _bankNameCtrl.text = _selectedBank.name == 'Other' ? '' : _selectedBank.name;
                  _bankSwiftCodeCtrl.text = _selectedBank.swiftCode;
                });
              },
              validator: (v) => v == null ? 'Please select a bank' : null,
            ),
            if (_selectedBank.name == 'Other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _bankNameCtrl,
                style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
                decoration: _fieldDecoration('Bank Name', isRequired: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter bank name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bankSwiftCodeCtrl,
                style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
                decoration: _fieldDecoration('SWIFT Code'),
              ),
            ] else if (_selectedBank.swiftCode.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _bankSwiftCodeCtrl,
                readOnly: true,
                style: GoogleFonts.jost(color: CitadelColors.textMuted, fontSize: 14),
                decoration: _fieldDecoration('SWIFT Code'),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankAddressCtrl,
              style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 14),
              maxLines: 2,
              decoration: _fieldDecoration('Bank Address'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Share Percentage Fields ──────────────────────────────────────────────

  Widget _sharePercentageFields() {
    final maxShare = widget.maxAllowedShare;
    final isAutoAssigned = widget.autoAssignShare;
    final currentVal = double.tryParse(_sharePercentageCtrl.text) ?? 0;
    final displayPct = (currentVal / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circular percentage ring
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: displayPct,
                        strokeWidth: 6,
                        backgroundColor: CitadelColors.border,
                        valueColor: AlwaysStoppedAnimation(_typeColor),
                      ),
                    ),
                    Text(
                      '${currentVal.toStringAsFixed(currentVal == currentVal.roundToDouble() ? 0 : 1)}%',
                      style: GoogleFonts.jost(fontSize: 18, fontWeight: FontWeight.w700, color: _typeColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'of ${maxShare.toStringAsFixed(maxShare == maxShare.roundToDouble() ? 0 : 1)}% max',
                style: GoogleFonts.jost(fontSize: 11, color: CitadelColors.textMuted),
              ),
            ],
          ),
        ),

        if (isAutoAssigned) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _typeColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _typeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Auto-assigned: remaining ${maxShare.toStringAsFixed(maxShare == maxShare.roundToDouble() ? 0 : 1)}%',
                    style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w500, color: _typeColor),
                  ),
                ),
              ],
            ),
          ),
        ] else if (maxShare < 100.0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: CitadelColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CitadelColors.warning.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: CitadelColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maximum ${maxShare.toStringAsFixed(maxShare == maxShare.roundToDouble() ? 0 : 1)}% remaining',
                    style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w500, color: CitadelColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        TextFormField(
          controller: _sharePercentageCtrl,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          style: GoogleFonts.jost(
            color: isAutoAssigned ? CitadelColors.textMuted : CitadelColors.textPrimary,
            fontSize: 14,
          ),
          readOnly: isAutoAssigned,
          decoration: _fieldDecoration('Share Percentage', suffixText: '%', isRequired: true),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter share percentage';
            final val = double.tryParse(v);
            if (val == null || val <= 0) return 'Must be greater than 0';
            if (val > maxShare + 0.01) return 'Maximum ${maxShare.toStringAsFixed(maxShare == maxShare.roundToDouble() ? 0 : 1)}% remaining';
            return null;
          },
        ),
      ],
    );
  }

  // ── Attachments Fields ───────────────────────────────────────────────────

  Widget _attachmentsFields() {
    return Column(
      children: [
        DocumentUploadCard(
          label: "Copy of Settlor's NRIC",
          hintMessage: 'Please ensure the image is high resolution and without glare.',
          s3Key: _settlorNricKey,
          onUploaded: (key) => setState(() => _settlorNricKey = key),
        ),
        const SizedBox(height: 10),
        DocumentUploadCard(
          label: 'Proof of Address',
          hintMessage: 'Please provide a document within 3 months, such as a utilities bill or bank statement.',
          s3Key: _proofOfAddressKey,
          onUploaded: (key) => setState(() => _proofOfAddressKey = key),
        ),
        const SizedBox(height: 10),
        DocumentUploadCard(
          label: 'Copy of Beneficiary ID',
          hintMessage: 'Please ensure the image is high resolution and without glare.',
          s3Key: _beneficiaryIdKey,
          onUploaded: (key) => setState(() => _beneficiaryIdKey = key),
        ),
        const SizedBox(height: 10),
        DocumentUploadCard(
          label: 'Beneficiary Bank Statement',
          hintMessage: 'Please ensure the 1st page shows the bank name, account name and account number.',
          s3Key: _bankStatementKey,
          onUploaded: (key) => setState(() => _bankStatementKey = key),
        ),
      ],
    );
  }

  // ── Save Button ──────────────────────────────────────────────────────────

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2E6DA4), Color(0xFF1B4F7A)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: CitadelColors.primary.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveBeneficiary,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isEditing ? 'Update Beneficiary' : 'Save Beneficiary',
                      style: GoogleFonts.jost(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ),
        ),
      ),
    );
  }
}