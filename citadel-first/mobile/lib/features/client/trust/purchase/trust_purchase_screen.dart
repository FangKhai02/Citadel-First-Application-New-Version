import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/citadel_colors.dart';

class TrustPurchaseScreen extends StatefulWidget {
  const TrustPurchaseScreen({super.key});

  @override
  State<TrustPurchaseScreen> createState() => _TrustPurchaseScreenState();
}

class _TrustPurchaseScreenState extends State<TrustPurchaseScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1 fields
  final _dateOfTrustDeedCtrl = TextEditingController();
  final _trustAssetAmountCtrl = TextEditingController();
  final _advisorNameCtrl = TextEditingController();
  final _advisorNricCtrl = TextEditingController();
  DateTime? _selectedDate;

  bool _submitting = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    // Listen to amount changes for real-time validation
    _trustAssetAmountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    _dateOfTrustDeedCtrl.dispose();
    _trustAssetAmountCtrl.dispose();
    _advisorNameCtrl.dispose();
    _advisorNricCtrl.dispose();
    super.dispose();
  }

  bool get _isStepValid => switch (_currentStep) {
        0 => _selectedDate != null && _trustAssetAmountCtrl.text.isNotEmpty,
        1 => true,
        _ => false,
      };

  void _nextStep() {
    if (_currentStep < 1 && _isStepValid) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
      _animController.reset();
      _animController.forward();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep--);
      _animController.reset();
      _animController.forward();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: CitadelColors.primary,
            onPrimary: Colors.white,
            surface: CitadelColors.surface,
            onSurface: CitadelColors.textPrimary,
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateOfTrustDeedCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _submitOrder() async {
    setState(() => _submitting = true);
    try {
      final api = ApiClient();
      await api.post(
        ApiEndpoints.trustOrders,
        data: {
          'date_of_trust_deed': _selectedDate?.toIso8601String().split('T').first,
          'trust_asset_amount': _trustAssetAmountCtrl.text.isNotEmpty
              ? double.tryParse(_trustAssetAmountCtrl.text.replaceAll(',', ''))
              : null,
          'advisor_name': _advisorNameCtrl.text.isNotEmpty ? _advisorNameCtrl.text : null,
          'advisor_nric': _advisorNricCtrl.text.isNotEmpty ? _advisorNricCtrl.text : null,
        },
      );
      if (mounted) {
        context.go('/client/trust-purchase-success');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed. Please try again.'),
            backgroundColor: CitadelColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: CitadelColors.textPrimary, size: 20),
          onPressed: _currentStep > 0 ? _prevStep : () => context.pop(),
        ),
        title: Text(
          'Trust Application',
          style: GoogleFonts.jost(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CitadelColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: _currentStep),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTrustInfoStep(),
                _buildReviewStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Trust Information ──

  Widget _buildTrustInfoStep() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CitadelColors.primary, CitadelColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trust Information',
                          style: GoogleFonts.jost(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Provide details for your trust application',
                          style: GoogleFonts.jost(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Required fields section
            _buildSectionLabel('Required Details'),
            const SizedBox(height: 12),

            // Date of Trust Deed
            _buildAnimatedField(
              index: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabelWithIcon('Date of Trust Deed', Icons.calendar_today),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _dateOfTrustDeedCtrl,
                        style: GoogleFonts.jost(
                          color: CitadelColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Select date',
                          hintStyle: GoogleFonts.jost(color: CitadelColors.textMuted),
                          prefixIcon: Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.event_rounded,
                              color: _selectedDate != null
                                  ? CitadelColors.primary
                                  : CitadelColors.textMuted,
                              size: 20,
                            ),
                          ),
                          suffixIcon: _selectedDate != null
                              ? const Icon(Icons.check_circle, color: CitadelColors.success, size: 20)
                              : null,
                          filled: true,
                          fillColor: CitadelColors.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: CitadelColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _selectedDate != null
                                  ? CitadelColors.primary.withValues(alpha: 0.5)
                                  : CitadelColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: CitadelColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Trust Asset Amount
            _buildAnimatedField(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabelWithIcon('Trust Asset Amount (RM)', Icons.payments_outlined),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _trustAssetAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[\d,.]*$'))],
                    style: GoogleFonts.jost(
                      color: CitadelColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      hintStyle: GoogleFonts.jost(color: CitadelColors.textMuted),
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.attach_money,
                          color: _trustAssetAmountCtrl.text.isNotEmpty
                              ? CitadelColors.primary
                              : CitadelColors.textMuted,
                          size: 20,
                        ),
                      ),
                      prefixText: 'RM ',
                      prefixStyle: GoogleFonts.jost(
                        color: CitadelColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      suffixIcon: _trustAssetAmountCtrl.text.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(Icons.check_circle, color: CitadelColors.success, size: 20),
                            )
                          : null,
                      filled: true,
                      fillColor: CitadelColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: CitadelColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _trustAssetAmountCtrl.text.isNotEmpty
                              ? CitadelColors.primary.withValues(alpha: 0.5)
                              : CitadelColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: CitadelColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Optional fields section
            _buildSectionLabel('Optional Details'),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Advisor information can be added now or later',
                style: GoogleFonts.jost(fontSize: 11, color: CitadelColors.textMuted),
              ),
            ),

            // Advisor Name
            _buildAnimatedField(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabelWithIcon('Advisor Name', Icons.person_outline),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _advisorNameCtrl,
                    style: GoogleFonts.jost(
                      color: CitadelColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration('Enter advisor name (optional)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Advisor NRIC
            _buildAnimatedField(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabelWithIcon('Advisor NRIC', Icons.badge_outlined),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _advisorNricCtrl,
                    maxLength: 12,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.jost(
                      color: CitadelColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration('Enter advisor NRIC (optional)').copyWith(
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Continue button (scrolls with content, clears Android nav bar)
            _buildContinueButton(),
            // Bottom safe area for Android navigation bar
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Review ──

  Widget _buildReviewStep() {
    final dateVal = _dateOfTrustDeedCtrl.text.isEmpty ? 'N/A' : _dateOfTrustDeedCtrl.text;
    final amountVal = _trustAssetAmountCtrl.text.isEmpty ? 'N/A' : 'RM ${_trustAssetAmountCtrl.text}';
    final advisorVal = _advisorNameCtrl.text.isEmpty ? 'N/A' : _advisorNameCtrl.text;
    final nricVal = _advisorNricCtrl.text.isEmpty ? 'N/A' : _advisorNricCtrl.text;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CitadelColors.primary, CitadelColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review & Submit',
                          style: GoogleFonts.jost(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verify your details before submitting',
                          style: GoogleFonts.jost(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Trust Information Card ──
            _buildReviewCard(
              icon: Icons.account_balance_outlined,
              iconColor: CitadelColors.primary,
              title: 'Trust Information',
              items: [
                _ReviewItem(icon: Icons.event_rounded, label: 'Date of Trust Deed', value: dateVal, required: true),
                _ReviewItem(icon: Icons.payments_outlined, label: 'Trust Asset Amount', value: amountVal, required: true),
              ],
            ),
            const SizedBox(height: 14),

            // ── Advisor Card ──
            _buildReviewCard(
              icon: Icons.person_outline,
              iconColor: CitadelColors.warning,
              title: 'Advisor Details',
              items: [
                _ReviewItem(icon: Icons.person, label: 'Advisor Name', value: advisorVal, required: false),
                _ReviewItem(icon: Icons.badge, label: 'Advisor NRIC', value: nricVal, required: false),
              ],
            ),
            const SizedBox(height: 24),

            // ── Notice ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CitadelColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CitadelColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: CitadelColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'By submitting, you confirm that the information provided is accurate. '
                      'Vanguard Trustee Berhad will review your application.',
                      style: GoogleFonts.jost(
                        fontSize: 12,
                        color: CitadelColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Submit button (scrolls with content, clears Android nav bar)
            _buildSubmitButton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Shared Builders ──

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        label,
        style: GoogleFonts.jost(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CitadelColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFieldLabelWithIcon(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CitadelColors.textMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.jost(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CitadelColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedField({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, widget) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: widget,
        ),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.jost(color: CitadelColors.textMuted),
      filled: true,
      fillColor: CitadelColors.surfaceLight,
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
        borderSide: const BorderSide(color: CitadelColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildReviewCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<_ReviewItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CitadelColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: items.map((item) => _buildReviewRow(item)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(_ReviewItem item) {
    final isNA = item.value == 'N/A';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 15, color: isNA ? CitadelColors.textMuted : CitadelColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.label,
                    style: GoogleFonts.jost(
                      fontSize: 12,
                      color: CitadelColors.textMuted,
                    ),
                  ),
                ),
                if (!item.required)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: CitadelColors.textMuted.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'optional',
                      style: GoogleFonts.jost(fontSize: 8, color: CitadelColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              textAlign: TextAlign.end,
              style: GoogleFonts.jost(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isNA ? CitadelColors.textMuted : CitadelColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isStepValid ? _nextStep : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: CitadelColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CitadelColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: _isStepValid ? 2 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Continue', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submitOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: CitadelColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CitadelColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Submit Application', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(width: 6),
                  const Icon(Icons.send_rounded, size: 16),
                ],
              ),
      ),
    );
  }
}

// ── Review item model ──

class _ReviewItem {
  final IconData icon;
  final String label;
  final String value;
  final bool required;
  const _ReviewItem({
    required this.icon,
    required this.label,
    required this.value,
    this.required = true,
  });
}

// ── Step indicator ──

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Trust Info', 'Review'];
    const icons = [Icons.edit_note_rounded, Icons.fact_check_outlined];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Step 1
          Expanded(child: _buildStep(labels[0], icons[0], 0)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right, color: CitadelColors.textMuted, size: 18),
          ),
          // Step 2
          Expanded(child: _buildStep(labels[1], icons[1], 1)),
        ],
      ),
    );
  }

  Widget _buildStep(String label, IconData icon, int step) {
    final isActive = step <= currentStep;
    final isCurrent = step == currentStep;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive
            ? CitadelColors.primary.withValues(alpha: isCurrent ? 0.15 : 0.08)
            : CitadelColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? CitadelColors.primary
              : isActive
                  ? CitadelColors.primary.withValues(alpha: 0.3)
                  : CitadelColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isActive
                ? Icon(icon, key: const ValueKey('active'), color: CitadelColors.primary, size: 16)
                : Icon(icon, key: const ValueKey('inactive'), color: CitadelColors.textMuted, size: 16),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jost(
                fontSize: 12,
                color: isActive ? CitadelColors.primary : CitadelColors.textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}