import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../models/crs_tax_residency.dart';
import 'widgets/dropdown_data.dart';
import 'widgets/signup_progress_bar.dart' show SignupProgressBar;

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
const _inputFill    = Color(0xFF0F172A);

// ── Country list (comprehensive for searchable picker) ──────────────────────
const _allCountries = [
  'Afghanistan', 'Albania', 'Algeria', 'Argentina', 'Armenia', 'Australia',
  'Austria', 'Azerbaijan', 'Bahrain', 'Bangladesh', 'Belarus', 'Belgium',
  'Bolivia', 'Bosnia and Herzegovina', 'Brazil', 'Brunei', 'Bulgaria',
  'Cambodia', 'Cameroon', 'Canada', 'Chile', 'China', 'Colombia',
  'Costa Rica', 'Croatia', 'Cuba', 'Czech Republic', 'Denmark',
  'Dominican Republic', 'Ecuador', 'Egypt', 'Estonia', 'Ethiopia',
  'Fiji', 'Finland', 'France', 'Georgia', 'Germany', 'Ghana', 'Greece',
  'Guatemala', 'Honduras', 'Hong Kong', 'Hungary', 'Iceland', 'India',
  'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica',
  'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kuwait', 'Laos', 'Latvia',
  'Lebanon', 'Libya', 'Lithuania', 'Luxembourg', 'Macau', 'Madagascar',
  'Malaysia', 'Maldives', 'Mauritius', 'Mexico', 'Moldova', 'Mongolia',
  'Morocco', 'Mozambique', 'Myanmar', 'Nepal', 'Netherlands',
  'New Zealand', 'Nigeria', 'North Korea', 'Norway', 'Oman', 'Pakistan',
  'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru',
  'Philippines', 'Poland', 'Portugal', 'Qatar', 'Romania', 'Russia',
  'Rwanda', 'Saudi Arabia', 'Senegal', 'Serbia', 'Singapore',
  'Slovakia', 'Slovenia', 'South Africa', 'South Korea', 'Spain',
  'Sri Lanka', 'Sudan', 'Sweden', 'Switzerland', 'Syria', 'Taiwan',
  'Tanzania', 'Thailand', 'Tunisia', 'Turkey', 'Uganda', 'Ukraine',
  'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay',
  'Uzbekistan', 'Venezuela', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe',
];

// ── Jurisdiction options for CRS rows (limited) ─────────────────────────────
const _jurisdictionOptions = ['Malaysia', 'Singapore', 'Thailand', 'Indonesia', 'Others'];

// ── TIN reason display map (descriptive instead of codes) ────────────────────
const _tinReasonDisplay = {
  'A': 'A — I have not been issued a TIN by the relevant jurisdiction',
  'B': 'B — I am unable to obtain a TIN for reasons stated below',
  'C': 'C — The jurisdiction does not issue TINs to its residents',
};

// ── Glass card wrapper ───────────────────────────────────────────────────────
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
        border: Border.all(color: _borderGlass.withAlpha(60), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

// ── Section header (icon + label) ───────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _cyan),
        const SizedBox(width: 10),
        Text(
          label,
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

// ── Screen ────────────────────────────────────────────────────────────────────

class KycCrsScreen extends StatefulWidget {
  const KycCrsScreen({super.key});

  @override
  State<KycCrsScreen> createState() => _KycCrsScreenState();
}

class _KycCrsScreenState extends State<KycCrsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // KYC fields
  String? _sourceOfTrustFund;
  String? _sourceOfIncome;
  String? _countryOfBirth;
  bool? _physicallyPresent;
  final _incomeCapitalCtrl = TextEditingController();
  bool? _largeTransactions;
  final _maritalHistoryCtrl = TextEditingController();
  final _geoConnectionsCtrl = TextEditingController();
  final _otherInfoCtrl = TextEditingController();
  final _otherSourceOfFundCtrl = TextEditingController();
  final _otherSourceOfIncomeCtrl = TextEditingController();

  bool get _isSourceOfFundOther => _sourceOfTrustFund == 'Others';
  bool get _isSourceOfIncomeOther => _sourceOfIncome == 'Others';

  // CRS rows
  List<CrsTaxResidencyRow> _crsRows = [CrsTaxResidencyRow()];

  bool _isLoading = false;
  String? _errorMessage;
  bool _formSubmitted = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

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
    _incomeCapitalCtrl.dispose();
    _maritalHistoryCtrl.dispose();
    _geoConnectionsCtrl.dispose();
    _otherInfoCtrl.dispose();
    _otherSourceOfFundCtrl.dispose();
    _otherSourceOfIncomeCtrl.dispose();
    super.dispose();
  }

  void _addCrsRow() {
    if (_crsRows.length >= 5) return;
    setState(() {
      _crsRows = [..._crsRows, CrsTaxResidencyRow()];
    });
  }

  void _removeCrsRow(int index) {
    if (_crsRows.length <= 1) return;
    setState(() {
      final updated = <CrsTaxResidencyRow>[];
      for (int i = 0; i < _crsRows.length; i++) {
        if (i != index) updated.add(_crsRows[i]);
      }
      _crsRows = updated;
    });
  }

  void _updateCrsRow(int index, CrsTaxResidencyRow updated) {
    setState(() {
      _crsRows = [
        for (int i = 0; i < _crsRows.length; i++)
          i == index ? updated : _crsRows[i],
      ];
    });
  }

  Future<void> _onContinue() async {
    setState(() {
      _errorMessage = null;
      _formSubmitted = true;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Validate non-FormField fields
    if (_sourceOfTrustFund == null) {
      setState(() => _errorMessage = 'Source of trust fund is required.');
      return;
    }
    if (_isSourceOfFundOther && _otherSourceOfFundCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please specify the source of trust fund.');
      return;
    }
    if (_sourceOfIncome == null) {
      setState(() => _errorMessage = 'Source of income is required.');
      return;
    }
    if (_isSourceOfIncomeOther && _otherSourceOfIncomeCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please specify the source of income.');
      return;
    }
    if (_countryOfBirth == null) {
      setState(() => _errorMessage = 'Country of birth is required.');
      return;
    }

    // Validate CRS rows (inline errors shown via showErrors flag)
    for (int i = 0; i < _crsRows.length; i++) {
      final row = _crsRows[i];
      if (row.jurisdiction.isEmpty) { return; }
      if (row.jurisdiction == 'Others' &&
          (row.otherJurisdiction == null || row.otherJurisdiction!.trim().isEmpty)) { return; }
      if (row.tinStatus == null) { return; }
      if (row.tinStatus == 'have_tin' &&
          (row.tin == null || row.tin!.trim().isEmpty)) { return; }
      if (row.tinStatus == 'no_tin' && row.noTinReason == null) { return; }
      if (row.noTinReason == 'B' &&
          (row.reasonBExplanation == null || row.reasonBExplanation!.trim().isEmpty)) { return; }
    }

    setState(() => _isLoading = true);
    try {
      // 1. Save KYC fields
      final kycData = <String, dynamic>{
        'source_of_trust_fund': _isSourceOfFundOther
            ? _otherSourceOfFundCtrl.text.trim()
            : _sourceOfTrustFund,
        if (_sourceOfIncome != null)
          'source_of_income': _isSourceOfIncomeOther
              ? _otherSourceOfIncomeCtrl.text.trim()
              : _sourceOfIncome,
        if (_countryOfBirth != null) 'country_of_birth': _countryOfBirth,
        if (_physicallyPresent != null) 'physically_present': _physicallyPresent,
        if (_incomeCapitalCtrl.text.trim().isNotEmpty)
          'main_sources_of_income': _incomeCapitalCtrl.text.trim(),
        if (_largeTransactions != null) 'has_unusual_transactions': _largeTransactions,
        if (_maritalHistoryCtrl.text.trim().isNotEmpty)
          'marital_history': _maritalHistoryCtrl.text.trim(),
        if (_geoConnectionsCtrl.text.trim().isNotEmpty)
          'geographical_connections': _geoConnectionsCtrl.text.trim(),
        if (_otherInfoCtrl.text.trim().isNotEmpty)
          'other_relevant_info': _otherInfoCtrl.text.trim(),
      };
      await ApiClient().patch(ApiEndpoints.kycCrs, data: kycData);

      // 2. Save CRS tax residency rows (PUT — replaces all rows)
      final crsData = {
        'residencies': _crsRows.map((r) {
          final jurisdiction = r.jurisdiction == 'Others' ? (r.otherJurisdiction ?? '') : r.jurisdiction;
          final map = <String, dynamic>{
            'jurisdiction': jurisdiction,
            'tin_status': r.tinStatus,
          };
          if (r.tinStatus == 'have_tin' && r.tin != null && r.tin!.trim().isNotEmpty) {
            map['tin'] = r.tin!.trim();
          }
          if (r.noTinReason != null) {
            map['no_tin_reason'] = r.noTinReason;
          }
          if (r.reasonBExplanation != null && r.reasonBExplanation!.trim().isNotEmpty) {
            map['reason_b_explanation'] = r.reasonBExplanation!.trim();
          }
          return map;
        }).toList(),
      };
      await ApiClient().put(ApiEndpoints.crsTaxResidency, data: crsData);

      if (!mounted) return;
      context.push('/signup/client/pep-declaration');
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail']?.toString() ?? 'Something went wrong. Please try again.';
      setState(() => _errorMessage = msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                              const SizedBox(height: 20),

                              // ── Decorative header ──
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
                                            color: _cyan.withAlpha(60),
                                            blurRadius: 24,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.shield_outlined,
                                        size: 34,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'KYC & Tax Residency',
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
                                      'Provide your KYC information and CRS tax residency details '
                                      'as required by regulatory standards.',
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

                              // ═══════════════════════════════════════════════════
                              // Card 1 — KYC Information
                              // ═══════════════════════════════════════════════════
                              _GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionHeader(
                                      icon: Icons.fact_check_outlined,
                                      label: 'KYC Information',
                                    ),
                                    const SizedBox(height: 20),

                                    // ── Source of Trust Fund ──
                                    _FieldLabel(label: 'Source of Trust Fund', required: true),
                                    const SizedBox(height: 6),
                                    _DropdownField(
                                      value: _sourceOfTrustFund,
                                      hint: 'Select source of trust fund',
                                      items: kSourceOfFundOptions,
                                      prefixIcon: Icons.account_balance_outlined,
                                      onChanged: (v) {
                                        setState(() {
                                          _sourceOfTrustFund = v;
                                          if (v != 'Others') _otherSourceOfFundCtrl.clear();
                                        });
                                      },
                                      validator: (v) =>
                                          v == null ? 'This field is required' : null,
                                    ),
                                    if (_isSourceOfFundOther) ...[
                                      const SizedBox(height: 8),
                                      _FieldLabel(label: 'Specify Source of Trust Fund', required: true),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _otherSourceOfFundCtrl,
                                        style: GoogleFonts.jost(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: const Color(0xFFF8FAFC),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Enter source of trust fund',
                                          prefixIcon: Icon(Icons.edit_outlined, size: 18, color: _textMuted),
                                          hintStyle: GoogleFonts.jost(
                                              fontSize: 13, fontWeight: FontWeight.w300, color: const Color(0xFF475569)),
                                          filled: true,
                                          fillColor: _inputFill,
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
                                        validator: (_) => _formSubmitted && _otherSourceOfFundCtrl.text.trim().isEmpty
                                            ? 'Please specify the source of trust fund'
                                            : null,
                                        autovalidateMode: _formSubmitted
                                            ? AutovalidateMode.always
                                            : AutovalidateMode.disabled,
                                      ),
                                    ],
                                    const SizedBox(height: 22),

                                    // ── Source of Income (dropdown) ──
                                    _FieldLabel(label: 'Source of Income', required: true),
                                    const SizedBox(height: 6),
                                    _DropdownField(
                                      value: _sourceOfIncome,
                                      hint: 'Select source of income',
                                      items: kSourceOfIncomeOptions,
                                      prefixIcon: Icons.account_balance_wallet_outlined,
                                      onChanged: (v) {
                                        setState(() {
                                          _sourceOfIncome = v;
                                          if (v != 'Others') _otherSourceOfIncomeCtrl.clear();
                                        });
                                      },
                                      validator: (v) =>
                                          v == null ? 'This field is required' : null,
                                    ),
                                    if (_isSourceOfIncomeOther) ...[
                                      const SizedBox(height: 8),
                                      _FieldLabel(label: 'Specify Source of Income', required: true),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _otherSourceOfIncomeCtrl,
                                        style: GoogleFonts.jost(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: const Color(0xFFF8FAFC),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Enter source of income',
                                          prefixIcon: Icon(Icons.edit_outlined, size: 18, color: _textMuted),
                                          hintStyle: GoogleFonts.jost(
                                              fontSize: 13, fontWeight: FontWeight.w300, color: const Color(0xFF475569)),
                                          filled: true,
                                          fillColor: _inputFill,
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
                                        validator: (_) => _formSubmitted && _otherSourceOfIncomeCtrl.text.trim().isEmpty
                                            ? 'Please specify the source of income'
                                            : null,
                                        autovalidateMode: _formSubmitted
                                            ? AutovalidateMode.always
                                            : AutovalidateMode.disabled,
                                      ),
                                    ],
                                    const SizedBox(height: 22),

                                    // ── Country of Birth ──
                                    _FieldLabel(label: 'Country of Birth', required: true),
                                    const SizedBox(height: 6),
                                    _SearchableCountryPicker(
                                      value: _countryOfBirth,
                                      forceShowError: _formSubmitted,
                                      onChanged: (v) =>
                                          setState(() => _countryOfBirth = v),
                                      validator: (v) =>
                                          v == null ? 'This field is required' : null,
                                    ),
                                    const SizedBox(height: 22),

                                    // ── Client Physically Present ──
                                    _FieldLabel(
                                        label: 'Client Physically Present for Identification (optional)'),
                                    const SizedBox(height: 8),
                                    _YesNoToggle(
                                      value: _physicallyPresent,
                                      onChanged: (v) =>
                                          setState(() => _physicallyPresent = v),
                                    ),
                                    const SizedBox(height: 22),

                                    // ── Main Sources of Income & Capital ──
                                    _FieldLabel(
                                        label: 'Main Sources of Income & Capital (optional)'),
                                    const SizedBox(height: 6),
                                    _MultilineField(
                                      controller: _incomeCapitalCtrl,
                                      hint:
                                          'Describe your main sources of income and capital...',
                                    ),
                                    const SizedBox(height: 22),

                                    // ── Large / Complex / Unusual Transactions ──
                                    _FieldLabel(
                                        label:
                                            'Large / Complex / Unusual Transactions (optional)'),
                                    const SizedBox(height: 8),
                                    _YesNoToggle(
                                      value: _largeTransactions,
                                      onChanged: (v) =>
                                          setState(() => _largeTransactions = v),
                                    ),
                                    const SizedBox(height: 22),

                                    // ── Marital History / Dependents ──
                                    _FieldLabel(
                                        label: 'Marital History / Dependents (optional)'),
                                    const SizedBox(height: 6),
                                    _MultilineField(
                                      controller: _maritalHistoryCtrl,
                                      hint:
                                          'Provide details about marital history and dependents...',
                                    ),
                                    const SizedBox(height: 22),

                                    // ── Geographical Connections ──
                                    _FieldLabel(label: 'Geographical Connections (optional)'),
                                    const SizedBox(height: 6),
                                    _MultilineField(
                                      controller: _geoConnectionsCtrl,
                                      hint:
                                          'List countries with significant connections...',
                                    ),
                                    const SizedBox(height: 22),

                                    // ── Other Relevant Info ──
                                    _FieldLabel(label: 'Other Relevant Info (optional)'),
                                    const SizedBox(height: 6),
                                    _MultilineField(
                                      controller: _otherInfoCtrl,
                                      hint:
                                          'Any other relevant information you wish to provide...',
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ═══════════════════════════════════════════════════
                              // Card 2 — CRS Tax Residency
                              // ═══════════════════════════════════════════════════
                              _GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionHeader(
                                      icon: Icons.public_outlined,
                                      label: 'CRS Tax Residency',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Declare all jurisdictions where you are a tax resident. '
                                      'Add up to 5 jurisdictions.',
                                      style: GoogleFonts.jost(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300,
                                        color: _textMuted,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 18),

                                    // CRS rows
                                    ...List.generate(_crsRows.length, (i) {
                                      return _CrsRowCard(
                                        key: ValueKey('crs_row_$i'),
                                        index: i,
                                        row: _crsRows[i],
                                        canDelete: _crsRows.length > 1,
                                        showErrors: _formSubmitted,
                                        onUpdate: (updated) =>
                                            _updateCrsRow(i, updated),
                                        onDelete: () => _removeCrsRow(i),
                                      );
                                    }),

                                    // Add jurisdiction button
                                    if (_crsRows.length < 5)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: _AddJurisdictionButton(
                                          onPressed: _addCrsRow,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ── Error banner ──
                              if (_errorMessage != null) ...[
                                _ErrorBanner(message: _errorMessage!),
                                const SizedBox(height: 16),
                              ],

                              const SizedBox(height: 16),

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
    return RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.jost(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.3,
        ),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: GoogleFonts.jost(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _cyan,
                letterSpacing: 0.3,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Dropdown field ────────────────────────────────────────────────────────────

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
      key: ValueKey('dropdown_${value ?? 'null'}'),
      initialValue: value,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      isExpanded: true,
      hint: Text(
        hint,
        style: GoogleFonts.jost(fontSize: 14, color: const Color(0xFF475569)),
      ),
      icon: const Icon(Icons.expand_more_rounded, color: _textMuted, size: 20),
      decoration: InputDecoration(
        prefixIcon: Icon(prefixIcon, size: 18, color: _textMuted),
        filled: true,
        fillColor: _inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

// ── Yes / No toggle ─────────────────────────────────────────────────────────

class _YesNoToggle extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _YesNoToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _toggleChip(label: 'Yes', selected: value == true, onTap: () => onChanged(true)),
        const SizedBox(width: 12),
        _toggleChip(label: 'No', selected: value == false, onTap: () => onChanged(false)),
      ],
    );
  }

  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _cyan.withAlpha(30) : Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _cyan : _borderGlass,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jost(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w300,
            color: selected ? _cyan : _textBody,
          ),
        ),
      ),
    );
  }
}

// ── Multiline text field ─────────────────────────────────────────────────────

class _MultilineField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const _MultilineField({
    required this.controller,
    required this.hint,
    // ignore: unused_element_parameter
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      minLines: 2,
      validator: validator,
      style: GoogleFonts.jost(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFF8FAFC),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.jost(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: const Color(0xFF475569),
        ),
        filled: true,
        fillColor: _inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

// ── CRS row card ─────────────────────────────────────────────────────────────

class _CrsRowCard extends StatefulWidget {
  final int index;
  final CrsTaxResidencyRow row;
  final bool canDelete;
  final bool showErrors;
  final ValueChanged<CrsTaxResidencyRow> onUpdate;
  final VoidCallback onDelete;

  const _CrsRowCard({
    super.key,
    required this.index,
    required this.row,
    required this.canDelete,
    this.showErrors = false,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_CrsRowCard> createState() => _CrsRowCardState();
}

class _CrsRowCardState extends State<_CrsRowCard> {
  late TextEditingController _tinCtrl;
  late TextEditingController _reasonBCtrl;
  late TextEditingController _otherJurisdictionCtrl;

  @override
  void initState() {
    super.initState();
    _tinCtrl = TextEditingController(text: widget.row.tin ?? '');
    _reasonBCtrl =
        TextEditingController(text: widget.row.reasonBExplanation ?? '');
    _otherJurisdictionCtrl =
        TextEditingController(text: widget.row.otherJurisdiction ?? '');
  }

  @override
  void didUpdateWidget(covariant _CrsRowCard old) {
    super.didUpdateWidget(old);
    if (widget.row.tin != null && widget.row.tin != _tinCtrl.text) {
      _tinCtrl.text = widget.row.tin!;
    }
    if (widget.row.reasonBExplanation != null &&
        widget.row.reasonBExplanation != _reasonBCtrl.text) {
      _reasonBCtrl.text = widget.row.reasonBExplanation!;
    }
    if (widget.row.otherJurisdiction != null &&
        widget.row.otherJurisdiction != _otherJurisdictionCtrl.text) {
      _otherJurisdictionCtrl.text = widget.row.otherJurisdiction!;
    }
  }

  @override
  void dispose() {
    _tinCtrl.dispose();
    _reasonBCtrl.dispose();
    _otherJurisdictionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderGlass.withAlpha(80), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Jurisdiction ${widget.index + 1}',
                style: GoogleFonts.jost(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _cyan,
                  letterSpacing: 0.3,
                ),
              ),
              if (widget.canDelete)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _errorRed.withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _errorRed.withAlpha(60), width: 1),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _errorRed,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Jurisdiction dropdown
          _FieldLabel(label: 'Jurisdiction of Residence', required: true),
          const SizedBox(height: 6),
          _DropdownField(
            value: row.jurisdiction.isEmpty ? null : row.jurisdiction,
            hint: 'Select jurisdiction',
            items: _jurisdictionOptions,
            prefixIcon: Icons.public_outlined,
            onChanged: (v) {
              widget.onUpdate(row.copyWith(
                jurisdiction: v ?? '',
                otherJurisdiction: v == 'Others' ? (row.otherJurisdiction ?? '') : null,
              ));
            },
            validator: (v) => widget.showErrors && (v == null || v.isEmpty)
                ? 'Please select a jurisdiction'
                : null,
          ),

          // Show "Others" text field when "Others" is selected
          if (row.jurisdiction == 'Others') ...[
            const SizedBox(height: 8),
            _FieldLabel(label: 'Specify Jurisdiction', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _otherJurisdictionCtrl,
              style: GoogleFonts.jost(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFF8FAFC),
              ),
              decoration: InputDecoration(
                hintText: 'Enter jurisdiction name',
                prefixIcon: Icon(Icons.edit_location_outlined, size: 18, color: _textMuted),
                hintStyle: GoogleFonts.jost(
                    fontSize: 13, fontWeight: FontWeight.w300, color: const Color(0xFF475569)),
                filled: true,
                fillColor: _inputFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              validator: (_) => widget.showErrors &&
                  (_otherJurisdictionCtrl.text.trim().isEmpty)
                  ? 'Please enter the jurisdiction name'
                  : null,
              autovalidateMode: widget.showErrors
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              onChanged: (v) {
                widget.onUpdate(row.copyWith(otherJurisdiction: v));
              },
            ),
          ],
          const SizedBox(height: 14),

          // ── TIN Status Selection ──
          _FieldLabel(label: 'Tax Identification Number (TIN) Status', required: true),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _TinStatusChip(
                    label: 'I Possess a TIN',
                    selected: row.tinStatus == 'have_tin',
                    hasError: widget.showErrors && row.tinStatus == null,
                    onTap: () {
                      widget.onUpdate(row.copyWith(
                        tinStatus: 'have_tin',
                        noTinReason: null,
                        reasonBExplanation: null,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TinStatusChip(
                    label: 'I Do Not Possess a TIN',
                    selected: row.tinStatus == 'no_tin',
                    hasError: widget.showErrors && row.tinStatus == null,
                    onTap: () {
                      widget.onUpdate(row.copyWith(
                        tinStatus: 'no_tin',
                        tin: null,
                        noTinReason: null,
                        reasonBExplanation: null,
                      ));
                      _tinCtrl.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.showErrors && row.tinStatus == null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                'Please select your TIN status',
                style: GoogleFonts.jost(fontSize: 12, color: _errorRed),
              ),
            ),

          // ── Conditional: TIN Number (when "I Possess a TIN") ──
          if (row.tinStatus == 'have_tin') ...[
            const SizedBox(height: 12),
            _FieldLabel(label: 'TIN Number', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _tinCtrl,
              style: GoogleFonts.jost(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFF8FAFC),
              ),
              decoration: InputDecoration(
                hintText: 'Enter TIN',
                prefixIcon: Icon(Icons.pin_outlined, size: 18, color: _textMuted),
                hintStyle: GoogleFonts.jost(
                    fontSize: 14, color: const Color(0xFF475569)),
                filled: true,
                fillColor: _inputFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _borderGlass, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: _cyan.withAlpha(180), width: 1.5),
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
              validator: (_) => widget.showErrors &&
                  _tinCtrl.text.trim().isEmpty
                  ? 'Please enter your TIN number'
                  : null,
              autovalidateMode: widget.showErrors
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              onChanged: (v) {
                widget.onUpdate(row.copyWith(tin: v));
              },
            ),
          ],

          // ── Conditional: No TIN Reason (when "I Do Not Possess a TIN") ──
          if (row.tinStatus == 'no_tin') ...[
            const SizedBox(height: 12),
            _FieldLabel(label: 'Reason for Not Possessing a TIN', required: true),
            const SizedBox(height: 6),
            _DropdownField(
              value: row.noTinReason != null
                  ? _tinReasonDisplay[row.noTinReason!]
                  : null,
              hint: 'Select reason',
              items: _tinReasonDisplay.values.toList(),
              prefixIcon: Icons.help_outline_rounded,
              onChanged: (v) {
                // Map the display text back to the code key
                final code = _tinReasonDisplay.entries
                    .firstWhere((e) => e.value == v,
                        orElse: () => const MapEntry('', ''))
                    .key;
                if (code.isNotEmpty) {
                  widget.onUpdate(row.copyWith(
                    noTinReason: code,
                    reasonBExplanation:
                        code != 'B' ? null : row.reasonBExplanation,
                  ));
                }
              },
              validator: (v) => widget.showErrors && (v == null || v.isEmpty)
                  ? 'Please select a reason'
                  : null,
            ),

            // Conditional explanation field for Reason B
            if (row.noTinReason == 'B') ...[
              const SizedBox(height: 10),
              _FieldLabel(label: 'Explanation for Reason B', required: true),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonBCtrl,
                maxLines: 2,
                minLines: 1,
                style: GoogleFonts.jost(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFF8FAFC),
                ),
                decoration: InputDecoration(
                  hintText: 'Explain why you are unable to obtain a TIN...',
                  hintStyle: GoogleFonts.jost(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF475569)),
                  filled: true,
                  fillColor: _inputFill,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _borderGlass, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _cyan.withAlpha(180), width: 1.5),
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
                validator: (_) => widget.showErrors &&
                    _reasonBCtrl.text.trim().isEmpty
                    ? 'Please provide an explanation'
                    : null,
                autovalidateMode: widget.showErrors
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                onChanged: (v) {
                  widget.onUpdate(row.copyWith(reasonBExplanation: v));
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── TIN status chip ──────────────────────────────────────────────────────────

class _TinStatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  const _TinStatusChip({
    required this.label,
    required this.selected,
    this.hasError = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _cyan.withAlpha(30) : Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _cyan : (hasError ? _errorRed : _borderGlass),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.jost(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w300,
              color: selected ? _cyan : _textBody,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add jurisdiction button ──────────────────────────────────────────────────

class _AddJurisdictionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddJurisdictionButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _cyan.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cyan.withAlpha(60), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded,
                size: 18, color: _cyan),
            const SizedBox(width: 8),
            Text(
              'Add Jurisdiction',
              style: GoogleFonts.jost(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _cyan,
                letterSpacing: 0.3,
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

// ── Searchable country picker ──────────────────────────────────────────────────

class _SearchableCountryPicker extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final bool forceShowError;

  const _SearchableCountryPicker({
    required this.value,
    required this.onChanged,
    this.validator,
    this.forceShowError = false,
  });

  @override
  State<_SearchableCountryPicker> createState() => _SearchableCountryPickerState();
}

class _SearchableCountryPickerState extends State<_SearchableCountryPicker> {
  bool _hasInteracted = false;

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CountryPickerSheet(
        selected: widget.value,
        onSelect: (country) {
          widget.onChanged(country);
          if (!_hasInteracted) {
            setState(() => _hasInteracted = true);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shouldValidate = _hasInteracted || widget.forceShowError;
    final errorText = shouldValidate ? widget.validator?.call(widget.value) : null;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: InputDecorator(
        isEmpty: widget.value == null,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.flag_outlined, size: 18, color: _textMuted),
          suffixIcon: Icon(Icons.expand_more_rounded, color: _textMuted, size: 20),
          filled: true,
          fillColor: _inputFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: errorText != null ? _errorRed : _borderGlass, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: errorText != null ? _errorRed : _cyan.withAlpha(180), width: 1.5),
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
          errorText: errorText,
        ),
        child: Text(
          widget.value ?? 'Select country of birth',
          style: GoogleFonts.jost(
            fontSize: 14,
            fontWeight: widget.value != null ? FontWeight.w400 : FontWeight.w300,
            color: widget.value != null ? const Color(0xFFF8FAFC) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _CountryPickerSheet({required this.selected, required this.onSelect});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = _allCountries;

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
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _allCountries
          : _allCountries
              .where((c) => c.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _borderGlass,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    color: const Color(0xFFF8FAFC),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search country...',
                    hintStyle: GoogleFonts.jost(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF475569),
                    ),
                    prefixIcon:
                        Icon(Icons.search_rounded, size: 20, color: _textMuted),
                    filled: true,
                    fillColor: _inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _borderGlass, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _cyan.withAlpha(180), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No countries found',
                          style: GoogleFonts.jost(
                              fontSize: 14, color: _textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _filtered.length,
                        itemBuilder: (_, index) {
                          final country = _filtered[index];
                          final isSelected = country == widget.selected;
                          return GestureDetector(
                            onTap: () => widget.onSelect(country),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _cyan.withAlpha(18)
                                    : Colors.white.withAlpha(4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? _cyan
                                      : _borderGlass.withAlpha(60),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (isSelected) ...[
                                    const Icon(Icons.check_rounded,
                                        size: 16, color: _cyan),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      country,
                                      style: GoogleFonts.jost(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.w300,
                                        color: isSelected
                                            ? _cyan
                                            : _textBody,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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