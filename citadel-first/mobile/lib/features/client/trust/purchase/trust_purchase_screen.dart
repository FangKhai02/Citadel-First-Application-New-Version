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

class _TrustPurchaseScreenState extends State<TrustPurchaseScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1 fields
  final _dateOfTrustDeedCtrl = TextEditingController();
  final _trustAssetAmountCtrl = TextEditingController();
  final _advisorNameCtrl = TextEditingController();
  final _advisorNricCtrl = TextEditingController();
  DateTime? _selectedDate;

  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
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
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildTrustInfoStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTrustInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trust Information',
            style: GoogleFonts.jost(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: CitadelColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Provide the details for your trust application.',
            style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textMuted),
          ),
          const SizedBox(height: 28),
          _buildFieldLabel('Date of Trust Deed *'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: AbsorbPointer(
              child: TextFormField(
                controller: _dateOfTrustDeedCtrl,
                style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Select date',
                  hintStyle: GoogleFonts.jost(color: CitadelColors.textMuted),
                  prefixIcon: const Icon(Icons.calendar_today, color: CitadelColors.primary, size: 20),
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
                    borderSide: const BorderSide(color: CitadelColors.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('Trust Asset Amount (RM) *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _trustAssetAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[\d,.]*$'))],
            style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Enter amount',
              hintStyle: GoogleFonts.jost(color: CitadelColors.textMuted),
              prefixText: 'RM ',
              prefixStyle: GoogleFonts.jost(color: CitadelColors.primary, fontWeight: FontWeight.w600),
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
                borderSide: const BorderSide(color: CitadelColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('Advisor Name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _advisorNameCtrl,
            style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 15),
            decoration: _inputDecoration('Enter advisor name (optional)'),
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('Advisor NRIC'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _advisorNricCtrl,
            maxLength: 12,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontSize: 15),
            decoration: _inputDecoration('Enter advisor NRIC (optional)').copyWith(
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Submit',
            style: GoogleFonts.jost(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: CitadelColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please review your application details before submitting.',
            style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textMuted),
          ),
          const SizedBox(height: 28),
          _buildReviewSection('Trust Information', [
            _reviewRow('Date of Trust Deed', _dateOfTrustDeedCtrl.text.isEmpty ? 'Not provided' : _dateOfTrustDeedCtrl.text),
            _reviewRow('Trust Asset Amount', _trustAssetAmountCtrl.text.isEmpty ? 'Not provided' : 'RM ${_trustAssetAmountCtrl.text}'),
            _reviewRow('Advisor Name', _advisorNameCtrl.text.isEmpty ? 'Not provided' : _advisorNameCtrl.text),
            _reviewRow('Advisor NRIC', _advisorNricCtrl.text.isEmpty ? 'Not provided' : _advisorNricCtrl.text),
          ]),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: CitadelColors.surface,
        border: Border(top: BorderSide(color: CitadelColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: CitadelColors.primary,
                  side: const BorderSide(color: CitadelColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Back', style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: _currentStep == 1
                  ? (_submitting ? null : _submitOrder)
                  : (_isStepValid ? _nextStep : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: CitadelColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: CitadelColors.primary.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _currentStep == 1 ? 'Submit Application' : 'Next',
                      style: GoogleFonts.jost(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.jost(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: CitadelColors.textSecondary,
      ),
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
        borderSide: const BorderSide(color: CitadelColors.primary),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.jost(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CitadelColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.jost(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CitadelColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Trust Info', 'Review'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i <= currentStep;
          final isCurrent = i == currentStep;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? CitadelColors.primary : CitadelColors.surfaceLight,
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: CitadelColors.primaryLight, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isActive
                            ? Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                                '${i + 1}',
                                style: GoogleFonts.jost(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: CitadelColors.textMuted,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: GoogleFonts.jost(
                        fontSize: 10,
                        color: isActive ? CitadelColors.primary : CitadelColors.textMuted,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: i < currentStep ? CitadelColors.primary : CitadelColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}