import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_bloc.dart';
import '../../../core/auth/auth_event.dart';
import '../../../core/theme/citadel_colors.dart';
import '../../../models/beneficiary.dart';
import '../../client/dashboard/widgets/dashboard_card_shell.dart';
import '../../client/dashboard/widgets/section_header.dart';
import 'beneficiary_form_screen.dart';

class BeneficiarySummaryScreen extends StatefulWidget {
  const BeneficiarySummaryScreen({super.key});

  @override
  State<BeneficiarySummaryScreen> createState() => _BeneficiarySummaryScreenState();
}

class _BeneficiarySummaryScreenState extends State<BeneficiarySummaryScreen> {
  final _api = ApiClient();
  List<Beneficiary> _beneficiaries = [];
  bool _hasPreDemise = false;
  bool _hasPostDemise = false;
  bool _isLoading = true;
  int _selectedTab = 0; // 0 = pre-demise, 1 = post-demise

  List<Beneficiary> get _preDemise => _beneficiaries.where((b) => b.isPreDemise).toList();
  List<Beneficiary> get _postDemise => _beneficiaries.where((b) => b.isPostDemise).toList();

  double get _preTotal => _preDemise.fold(0.0, (sum, b) => sum + (b.sharePercentage ?? 0));
  double get _postTotal => _postDemise.fold(0.0, (sum, b) => sum + (b.sharePercentage ?? 0));

  bool get _preComplete => _hasPreDemise && (_preTotal - 100.0).abs() < 0.01;
  bool get _postComplete => _hasPostDemise && (_postTotal - 100.0).abs() < 0.01;

  bool get _canConfirm => _preComplete && _postComplete;

  double get _overallPercent =>
      ((_preTotal.clamp(0, 100) + _postTotal.clamp(0, 100)) / 2).clamp(0, 100);

  @override
  void initState() {
    super.initState();
    _fetchBeneficiaries();
  }

  Future<void> _fetchBeneficiaries() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiEndpoints.beneficiaries);
      final result = BeneficiaryListResult.fromJson(res.data as Map<String, dynamic>);
      setState(() {
        _beneficiaries = result.beneficiaries;
        _hasPreDemise = result.hasPreDemise;
        _hasPostDemise = result.hasPostDemise;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load beneficiaries: $e'), backgroundColor: CitadelColors.error),
        );
      }
    }
  }

  Future<void> _deleteBeneficiary(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CitadelColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Beneficiary?', style: GoogleFonts.jost(color: CitadelColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('This action cannot be undone. Are you sure you want to remove this beneficiary?', style: GoogleFonts.jost(color: CitadelColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.jost(color: CitadelColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.jost(color: CitadelColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete('${ApiEndpoints.beneficiaries}/$id');
      _fetchBeneficiaries();
      if (mounted) context.read<AuthBloc>().add(const AuthCheckRequested());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: CitadelColors.error),
        );
      }
    }
  }

  void _addBeneficiary(String type) async {
    final isPre = type == 'pre_demise';
    final currentTotal = isPre ? _preTotal : _postTotal;
    final remaining = (100.0 - currentTotal).clamp(0.01, 100.0);
    // Auto-assign for 2nd pre-demise beneficiary
    final autoAssign = isPre && _preDemise.length == 1;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BeneficiaryFormScreen(
        beneficiaryType: type,
        maxAllowedShare: remaining,
        autoAssignShare: autoAssign,
      )),
    );
    if (result == true) _fetchBeneficiaries();
  }

  void _editBeneficiary(Beneficiary b) async {
    final isPre = b.isPreDemise;
    final othersTotal = isPre
        ? _preDemise.where((x) => x.id != b.id).fold(0.0, (sum, x) => sum + (x.sharePercentage ?? 0))
        : _postDemise.where((x) => x.id != b.id).fold(0.0, (sum, x) => sum + (x.sharePercentage ?? 0));
    final remaining = (100.0 - othersTotal).clamp(0.01, 100.0);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BeneficiaryFormScreen(
          beneficiaryType: b.beneficiaryType,
          existingBeneficiaryId: b.id,
          existingBeneficiary: b,
          maxAllowedShare: remaining,
        ),
      ),
    );
    if (result == true) _fetchBeneficiaries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        foregroundColor: CitadelColors.textPrimary,
        automaticallyImplyLeading: false,
        title: Text('Beneficiary Details', style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CitadelColors.primary))
          : RefreshIndicator(
              color: CitadelColors.primary,
              backgroundColor: CitadelColors.surface,
              onRefresh: _fetchBeneficiaries,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 16),
                  _buildTabToggle(),
                  const SizedBox(height: 16),
                  _buildCurrentTabContent(),
                  const Divider(color: CitadelColors.border, height: 40, thickness: 1),
                  _buildValidationSummary(),
                  const Divider(color: CitadelColors.border, height: 40, thickness: 1),
                  _buildConfirmButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CitadelColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Pre-Demise',
              icon: Icons.person_outline_rounded,
              isSelected: _selectedTab == 0,
              color: CitadelColors.primary,
              count: _preDemise.length,
              maxCount: 2,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: 'Post-Demise',
              icon: Icons.group_outlined,
              isSelected: _selectedTab == 1,
              color: CitadelColors.warning,
              onTap: () => setState(() => _selectedTab = 1),
              count: _postDemise.length,
              maxCount: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    final isPre = _selectedTab == 0;
    final accentColor = isPre ? CitadelColors.primary : CitadelColors.warning;
    final title = isPre ? 'Pre-Demise Beneficiaries' : 'Post-Demise Beneficiaries';
    final subtitle = isPre
        ? 'Beneficiaries who receive distributions while the settlor is alive.'
        : 'Beneficiaries who receive distributions after the settlor\'s demise.';
    final minMax = isPre ? 'Minimum 1 required · Maximum 2 allowed' : 'Minimum 1 required · Maximum 5 allowed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPre ? Icons.person_outline_rounded : Icons.group_outlined,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.jost(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CitadelColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Text(
            subtitle,
            style: GoogleFonts.jost(
              fontSize: 13,
              color: CitadelColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                minMax,
                style: GoogleFonts.jost(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTabContent() {
    final isPre = _selectedTab == 0;
    final beneficiaries = isPre ? _preDemise : _postDemise;
    final maxCount = isPre ? 2 : 5;
    final type = isPre ? 'pre_demise' : 'post_demise';
    final totalPct = isPre ? _preTotal : _postTotal;
    final accentColor = isPre ? CitadelColors.primary : CitadelColors.warning;

    final allocationComplete = (totalPct - 100.0).abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (beneficiaries.isEmpty)
          _buildEmptyState(accentColor: accentColor, type: type, label: isPre ? 'Pre-Demise' : 'Post-Demise')
        else
          ...beneficiaries.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BeneficiaryCard(
                  beneficiary: b,
                  accentColor: accentColor,
                  onEdit: () => _editBeneficiary(b),
                  onDelete: () => _deleteBeneficiary(b.id),
                ),
              )),
        if (allocationComplete) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: CitadelColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CitadelColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: CitadelColors.success, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Allocation complete — all 100% has been assigned',
                    style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w500, color: CitadelColors.success),
                  ),
                ),
              ],
            ),
          ),
        ] else if (beneficiaries.length < maxCount) ...[
          const SizedBox(height: 12),
          _buildAddCard(type: type, accentColor: accentColor),
        ],
        if (beneficiaries.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildTotalShareIndicator(totalPct: totalPct, accentColor: accentColor),
        ],
      ],
    );
  }

  Widget _buildEmptyState({required Color accentColor, required String type, required String label}) {
    return DashboardCardShell(
      borderColor: accentColor.withValues(alpha: 0.2),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedTab == 0 ? Icons.person_outline_rounded : Icons.group_outlined,
              color: accentColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No $label Beneficiaries',
            style: GoogleFonts.jost(fontSize: 16, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedTab == 0
                ? 'Add beneficiaries who receive distributions while the settlor is alive.'
                : 'Add beneficiaries who receive distributions after the settlor\'s demise.',
            textAlign: TextAlign.center,
            style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard({required String type, required Color accentColor}) {
    return GestureDetector(
      onTap: () => _addBeneficiary(type),
      child: DashedBorderContainer(
        borderColor: CitadelColors.textMuted.withValues(alpha: 0.4),
        borderRadius: 16,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Add Beneficiary',
                  style: GoogleFonts.jost(fontSize: 14, fontWeight: FontWeight.w500, color: accentColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalShareIndicator({required double totalPct, required Color accentColor}) {
    final isComplete = (totalPct - 100.0).abs() < 0.01;
    final color = isComplete ? CitadelColors.success : CitadelColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Share', style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textSecondary, fontWeight: FontWeight.w500)),
          Text(
            '${totalPct.toStringAsFixed(totalPct == totalPct.roundToDouble() ? 0 : 1)}%',
            style: GoogleFonts.jost(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationSummary() {
    final preFrac = (_preTotal / 100).clamp(0.0, 1.0);
    final postFrac = (_postTotal / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Completion Status')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _overallPercent >= 100
                    ? CitadelColors.success.withValues(alpha: 0.15)
                    : CitadelColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_overallPercent.toStringAsFixed(0)}%',
                style: GoogleFonts.jost(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _overallPercent >= 100 ? CitadelColors.success : CitadelColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SegmentedProgressBar(preFraction: preFrac, postFraction: postFrac),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _SegmentLabel(
                label: 'Pre-Demise',
                percent: _preTotal,
                isComplete: _preComplete,
                color: CitadelColors.primary,
              ),
            ),
            Expanded(
              child: _SegmentLabel(
                label: 'Post-Demise',
                percent: _postTotal,
                isComplete: _postComplete,
                color: CitadelColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canConfirm ? _confirmAndContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: CitadelColors.primary,
          disabledBackgroundColor: CitadelColors.surfaceLight,
          disabledForegroundColor: CitadelColors.textMuted,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Confirm & Continue', style: GoogleFonts.jost(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  void _confirmAndContinue() {
    context.read<AuthBloc>().add(const AuthCheckRequested());
    Navigator.pop(context);
  }
}

// --- Private Widgets ---

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final int count;
  final int maxCount;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.count,
    required this.maxCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : CitadelColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.jost(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : CitadelColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : CitadelColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count/$maxCount',
                style: GoogleFonts.jost(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : CitadelColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeneficiaryCard extends StatelessWidget {
  final Beneficiary beneficiary;
  final Color accentColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BeneficiaryCard({
    required this.beneficiary,
    required this.accentColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = beneficiary.fullName ?? 'Unnamed';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final relationship = beneficiary.relationshipToSettlor ?? '—';
    final sharePct = beneficiary.sharePercentage?.toStringAsFixed(0) ?? '0';

    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CitadelColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.jost(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.jost(fontSize: 15, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  relationship,
                                  style: GoogleFonts.jost(fontSize: 10, fontWeight: FontWeight.w500, color: accentColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$sharePct%',
                                style: GoogleFonts.jost(fontSize: 12, color: CitadelColors.textMuted, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, color: CitadelColors.primary.withValues(alpha: 0.7), size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline_rounded, color: CitadelColors.error.withValues(alpha: 0.7), size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete',
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
}

class _SegmentedProgressBar extends StatelessWidget {
  final double preFraction;
  final double postFraction;

  const _SegmentedProgressBar({
    required this.preFraction,
    required this.postFraction,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: CitadelColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: preFraction,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: preFraction >= 1.0
                            ? CitadelColors.success
                            : CitadelColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 2, color: CitadelColors.background),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: CitadelColors.warning.withValues(alpha: 0.12),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: postFraction,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: postFraction >= 1.0
                            ? CitadelColors.success
                            : CitadelColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  final String label;
  final double percent;
  final bool isComplete;
  final Color color;

  const _SegmentLabel({
    required this.label,
    required this.percent,
    required this.isComplete,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isComplete) ...[
          const Icon(Icons.check_circle_rounded, color: CitadelColors.success, size: 14),
          const SizedBox(width: 4),
        ] else ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.jost(
              fontSize: 11,
              fontWeight: isComplete ? FontWeight.w600 : FontWeight.w400,
              color: isComplete ? CitadelColors.success : CitadelColors.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${percent.clamp(0, 100).toStringAsFixed(0)}%',
          style: GoogleFonts.jost(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isComplete ? CitadelColors.success : color,
          ),
        ),
      ],
    );
  }
}

class DashedBorderContainer extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final double borderRadius;

  const DashedBorderContainer({
    super.key,
    required this.child,
    required this.borderColor,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: borderColor,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  _DashedBorderPainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashGap = 4.0;
    final r = borderRadius;

    // Draw dashed lines along each side
    _drawDashedLine(canvas, paint, Offset(r, 0), Offset(size.width - r, 0), dashWidth, dashGap); // top
    _drawDashedLine(canvas, paint, Offset(size.width, r), Offset(size.width, size.height - r), dashWidth, dashGap); // right
    _drawDashedLine(canvas, paint, Offset(size.width - r, size.height), Offset(r, size.height), dashWidth, dashGap); // bottom
    _drawDashedLine(canvas, paint, Offset(0, size.height - r), Offset(0, r), dashWidth, dashGap); // left

    // Draw corner arcs
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromLTWH(0, 0, r * 2, r * 2), -3.14159 / 2, 3.14159 / 2, false, arcPaint); // top-left
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2), 0, 3.14159 / 2, false, arcPaint); // top-right
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2), 3.14159 / 2, 3.14159 / 2, false, arcPaint); // bottom-right
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2), 3.14159, 3.14159 / 2, false, arcPaint); // bottom-left
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end, double dashWidth, double dashGap) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalLength = sqrt(dx * dx + dy * dy);
    if (totalLength == 0) return;
    final unitDx = dx / totalLength;
    final unitDy = dy / totalLength;

    double distance = 0;
    bool drawing = true;
    while (distance < totalLength) {
      final segmentLength = drawing ? dashWidth : dashGap;
      final endDistance = (distance + segmentLength).clamp(0.0, totalLength);
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + unitDx * distance, start.dy + unitDy * distance),
          Offset(start.dx + unitDx * endDistance, start.dy + unitDy * endDistance),
          paint,
        );
      }
      distance = endDistance;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}