import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/citadel_colors.dart';
import '../../../models/bank_details.dart';
import '../../../models/trust_dividend.dart';
import '../../../models/trust_portfolio.dart';
import '../../../services/portfolio_service.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final int portfolioId;
  const PortfolioDetailScreen({super.key, required this.portfolioId});

  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = PortfolioService();
  TrustPortfolioDetail? _detail;
  List<TrustDividend> _dividends = [];
  int _uploadedReceiptCount = 0;
  bool _loading = true;
  bool _updatingPaymentMethod = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _service.getPortfolioDetail(widget.portfolioId),
        _service.getDividendsByPortfolio(widget.portfolioId),
      ]);
      final detail = results[0] as TrustPortfolioDetail;
      final dividends = results[1] as List<TrustDividend>;

      // Fetch receipt count if we have an order ID
      int receiptCount = 0;
      final orderId = detail.portfolio.trustOrderId;
      if (orderId != null) {
        try {
          final receipts = await _service.getPaymentReceipts(orderId);
          receiptCount = receipts.where((r) => r.isUploaded).length;
        } catch (_) {
          // Non-critical — just don't show count if it fails
        }
      }

      if (mounted) {
        setState(() {
          _detail = detail;
          _dividends = dividends;
          _uploadedReceiptCount = receiptCount;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load portfolio details';
        });
      }
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
          onPressed: () => context.pop(),
        ),
        title: Text(_detail?.portfolio.productName ?? 'Portfolio Detail',
          style: GoogleFonts.jost(fontSize: 18, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Dividends'),
          ],
          labelColor: CitadelColors.primary,
          unselectedLabelColor: CitadelColors.textMuted,
          indicatorColor: CitadelColors.primary,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CitadelColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: CitadelColors.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: GoogleFonts.jost(color: CitadelColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildDividendsTab(),
                  ],
                ),
    );
  }

  // ─── Overview Tab ─────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    if (_detail == null) return const SizedBox();
    final p = _detail!.portfolio;
    return RefreshIndicator(
      color: CitadelColors.primary,
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(p),
          const SizedBox(height: 12),
          _buildDetailSection(
            icon: Icons.description_outlined,
            iconBgColor: CitadelColors.primary,
            title: 'Trust Details',
            rows: [
              _DetailRow(label: 'Reference ID', value: _detail!.display(_detail!.trustReferenceId)),
              _DetailRow(label: 'Investment Amount', value: _detail!.displayAssetAmount),
              _DetailRow(label: 'Case Status', value: _detail!.display(_detail!.caseStatus), valueColor: _detail!.caseStatus == 'APPROVED' ? CitadelColors.success : null),
              _DetailRow(label: 'Advisor', value: _detail!.display(_detail!.advisorName)),
              _DetailRow(label: 'Advisor Code', value: _detail!.display(_detail!.advisorCode)),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailSection(
            icon: Icons.calendar_today_outlined,
            iconBgColor: CitadelColors.success,
            title: 'Important Dates',
            rows: [
              _DetailRow(label: 'Commencement', value: _detail!.displayDate(_detail!.commencementDate)),
              _DetailRow(label: 'Period Ending', value: _detail!.displayDate(_detail!.trustPeriodEndingDate)),
              _DetailRow(label: 'Maturity Date', value: p.displayDate(p.maturityDate)),
            ],
          ),
          const SizedBox(height: 12),
          _buildBankDetailsSection(p),
          const SizedBox(height: 12),
          _buildPaymentSection(p),
          if (p.status == 'PENDING_PAYMENT') ...[
            const SizedBox(height: 12),
            _buildWarningBanner(),
          ],
          const SizedBox(height: 16),
          _buildActionButtons(p),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Hero Card ────────────────────────────────────────────────────

  Widget _buildHeroCard(TrustPortfolio p) {
    final statusColor = _statusColor(p.status);
    final statusLabel = p.statusLabel;

    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CitadelColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left status strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.productName,
                              style: GoogleFonts.jost(fontSize: 18, fontWeight: FontWeight.w700, color: CitadelColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(p.productCode,
                              style: GoogleFonts.jost(fontSize: 12, color: CitadelColors.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(statusLabel.toUpperCase(),
                              style: GoogleFonts.jost(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                                letterSpacing: 0.5,
                              )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Amount section
                  Text('TOTAL INVESTMENT',
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      color: CitadelColors.textMuted,
                      letterSpacing: 0.8,
                    )),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('RM',
                        style: GoogleFonts.jost(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: CitadelColors.textSecondary,
                        )),
                      const SizedBox(width: 4),
                      Text(_detail!.displayAssetAmount.replaceAll('RM ', ''),
                        style: GoogleFonts.jost(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: CitadelColors.textPrimary,
                          height: 1.1,
                        )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [CitadelColors.primary, Colors.transparent],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'ACTIVE' => CitadelColors.success,
      'PENDING_PAYMENT' => CitadelColors.warning,
      'MATURED' => CitadelColors.primary,
      'WITHDRAWN' => CitadelColors.textMuted,
      _ => CitadelColors.warning,
    };
  }

  Color _paymentStatusColor(String? paymentStatus) {
    return switch (paymentStatus) {
      'SUCCESS' => CitadelColors.success,
      'FAILED' => CitadelColors.error,
      _ => CitadelColors.warning,
    };
  }

  // ─── Detail Section ──────────────────────────────────────────────

  Widget _buildDetailSection({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required List<_DetailRow> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with icon
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconBgColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: iconBgColor),
                ),
                const SizedBox(width: 8),
                Text(title,
                  style: GoogleFonts.jost(fontSize: 14, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Detail rows
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(row.label,
                  style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textSecondary)),
                Flexible(
                  child: Text(row.value,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.jost(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: row.valueColor ?? CitadelColors.textPrimary,
                    )),
                ),
              ],
            ),
          )),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ─── Payment Section ──────────────────────────────────────────────

  Widget _buildPaymentSection(TrustPortfolio p) {
    final paymentStatusColor = _paymentStatusColor(p.paymentStatus);
    final canEditPaymentMethod = p.status == 'PENDING_PAYMENT';

    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: CitadelColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.credit_card_outlined, size: 14, color: CitadelColors.primary),
                ),
                const SizedBox(width: 8),
                Text('Payment',
                  style: GoogleFonts.jost(fontSize: 14, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Payment method row — dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Method',
                  style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textSecondary)),
                _updatingPaymentMethod
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: CitadelColors.primary),
                      )
                    : _buildPaymentMethodDropdown(p, canEditPaymentMethod),
              ],
            ),
          ),
          // Payment status row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Status',
                  style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textSecondary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: paymentStatusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(p.paymentStatusLabel,
                    style: GoogleFonts.jost(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: paymentStatusColor,
                    )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodDropdown(TrustPortfolio p, bool canEdit) {
    if (!canEdit) {
      // Show as read-only text when not in PENDING_PAYMENT
      final label = switch (p.paymentMethod) {
        'MANUAL_TRANSFER' => 'Manual Transfer',
        'ONLINE_BANKING' => 'Online Banking',
        _ => p.paymentMethod ?? 'Not set',
      };
      return Text(label,
        style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w500, color: CitadelColors.textPrimary));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CitadelColors.border),
      ),
      child: DropdownButton<String>(
        value: p.paymentMethod,
        hint: Text('Select method',
          style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textMuted)),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: CitadelColors.textSecondary),
        underline: const SizedBox(),
        isDense: true,
        style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w500, color: CitadelColors.textPrimary),
        dropdownColor: CitadelColors.surfaceLight,
        items: const [
          DropdownMenuItem(value: 'MANUAL_TRANSFER', child: Text('Manual Transfer')),
          DropdownMenuItem(value: 'ONLINE_BANKING', child: Text('Online Banking')),
        ],
        onChanged: (value) {
          if (value != null && value != p.paymentMethod) {
            _updatePaymentMethod(value);
          }
        },
      ),
    );
  }

  Future<void> _updatePaymentMethod(String method) async {
    setState(() => _updatingPaymentMethod = true);
    try {
      await _service.updatePortfolio(widget.portfolioId, {'payment_method': method});
      if (mounted) {
        await _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update payment method'),
            backgroundColor: CitadelColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingPaymentMethod = false);
      }
    }
  }

  // ─── Warning Banner ────────────────────────────────────────────────

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CitadelColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.warning.withValues(alpha: 0.35), style: BorderStyle.solid),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CitadelColors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline, size: 16, color: CitadelColors.warning),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.jost(fontSize: 13, color: CitadelColors.textSecondary, height: 1.5),
                children: [
                  TextSpan(
                    text: 'Payment Required\n',
                    style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.warning),
                  ),
                  const TextSpan(
                    text: 'Upload your payment receipt to activate your trust investment. Your portfolio will remain on hold until payment is verified.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Action Buttons ────────────────────────────────────────────────

  Widget _buildActionButtons(TrustPortfolio p) {
    final buttons = <Widget>[];

    if (p.status == 'PENDING_PAYMENT') {
      final hasReceipts = _uploadedReceiptCount > 0;
      buttons.add(
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [CitadelColors.primary, CitadelColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: CitadelColors.primary.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final orderId = _detail?.portfolio.trustOrderId;
                  if (orderId != null) {
                    await context.push('/client/payment-receipts/$orderId?paymentStatus=${_detail?.portfolio.paymentStatus ?? 'PENDING'}');
                    if (mounted) _fetchData();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload_file_outlined, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(hasReceipts ? 'Payment Receipts' : 'Upload Payment Receipt',
                        style: GoogleFonts.jost(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15)),
                      if (hasReceipts) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_uploadedReceiptCount.toString(),
                            style: GoogleFonts.jost(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      buttons.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await context.push('/client/bank-details');
            },
            icon: const Icon(Icons.account_balance_rounded, size: 18),
            label: Text('Manage Bank Details', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 15)),
            style: OutlinedButton.styleFrom(
              foregroundColor: CitadelColors.primary,
              side: const BorderSide(color: CitadelColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }

    if (p.status == 'ACTIVE') {
      buttons.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final orderId = _detail?.portfolio.trustOrderId;
              if (orderId != null) {
                await context.push('/client/payment-receipts/$orderId?paymentStatus=${_detail?.portfolio.paymentStatus ?? 'PENDING'}');
              }
            },
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text('View Receipts', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 15)),
            style: OutlinedButton.styleFrom(
              foregroundColor: CitadelColors.primary,
              side: const BorderSide(color: CitadelColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
      if (p.agreementKey != null) {
        buttons.add(
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: View agreement document
              },
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text('View Agreement', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: CitadelColors.primary,
                side: const BorderSide(color: CitadelColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        );
      }
    }

    if (p.status == 'MATURED') {
      buttons.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.autorenew, size: 18),
            label: Text('Rollover / Redemption', style: GoogleFonts.jost(fontWeight: FontWeight.w600, fontSize: 15)),
            style: OutlinedButton.styleFrom(
              foregroundColor: CitadelColors.textSecondary,
              side: BorderSide(color: CitadelColors.textMuted.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...buttons.map((button) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: button,
        )),
      ],
    );
  }

  // ─── Bank Details Section ────────────────────────────────────────────

  Widget _buildBankDetailsSection(TrustPortfolio p) {
    final isPendingPayment = p.status == 'PENDING_PAYMENT';
    final hasLinkedBank = _detail!.bankName != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: CitadelColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_outlined, size: 16, color: CitadelColors.warning),
            ),
            const SizedBox(width: 8),
            Text('Bank Details', style: GoogleFonts.jost(
              fontSize: 15, fontWeight: FontWeight.w700, color: CitadelColors.textPrimary)),
            const Spacer(),
            if (hasLinkedBank)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CitadelColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('LINKED', style: GoogleFonts.jost(
                  fontSize: 10, fontWeight: FontWeight.w700, color: CitadelColors.success)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (hasLinkedBank) ...[
          // Show linked bank card
          Container(
            decoration: BoxDecoration(
              color: CitadelColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CitadelColors.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: CitadelColors.success,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Bank initial avatar
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: CitadelColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                _detail!.bankName!.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.jost(
                                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_detail!.bankName!, style: GoogleFonts.jost(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text('${_detail!.bankAccountHolderName ?? 'N/A'} · ${_detail!.bankAccountNumber ?? 'N/A'}',
                                  style: GoogleFonts.jost(fontSize: 12, color: CitadelColors.textMuted)),
                                if (_detail!.bankSwiftCode != null && _detail!.bankSwiftCode!.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text('SWIFT: ${_detail!.bankSwiftCode}', style: GoogleFonts.jost(
                                    fontSize: 11, color: CitadelColors.textMuted)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Change button (only during PENDING_PAYMENT)
          if (isPendingPayment) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showBankSelectionSheet(),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: Text('Change Bank Account', style: GoogleFonts.jost(fontSize: 12, fontWeight: FontWeight.w500)),
                style: TextButton.styleFrom(
                  foregroundColor: CitadelColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ),
          ],
        ] else if (isPendingPayment) ...[
          // Show link prompt (only during PENDING_PAYMENT)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showBankSelectionSheet(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: CitadelColors.primary.withValues(alpha: 0.3), width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: CitadelColors.primary.withValues(alpha: 0.03),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: CitadelColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_outlined, size: 24, color: CitadelColors.primary),
                    ),
                    const SizedBox(height: 10),
                    Text('Link Your Bank Account', style: GoogleFonts.jost(
                      fontSize: 14, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Select a bank account for dividend and maturity payouts',
                      style: GoogleFonts.jost(fontSize: 12, color: CitadelColors.textMuted),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [CitadelColors.primary, Color(0xFF1E8CB8)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Select Bank Account', style: GoogleFonts.jost(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showBankSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CitadelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BankSelectionSheet(
        portfolioId: widget.portfolioId,
        currentBankDetailsId: _detail?.portfolio.bankDetailsId,
        onLinked: () {
          Navigator.of(context).pop();
          _fetchData();
        },
      ),
    );
  }

  // ─── Dividends Tab ────────────────────────────────────────────────

  Widget _buildDividendsTab() {
    if (_dividends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 56, color: CitadelColors.textMuted),
            const SizedBox(height: 12),
            Text('No dividends yet',
              style: GoogleFonts.jost(fontSize: 16, color: CitadelColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Dividends will appear here when they are disbursed.',
              style: GoogleFonts.jost(fontSize: 12, color: CitadelColors.textMuted)),
          ],
        ),
      );
    }

    // Calculate totals
    final disbursed = _dividends.where((d) => d.paymentStatus == 'PAID').toList();
    final totalGross = disbursed.fold<double>(0, (sum, d) => sum + d.dividendAmount);
    final totalFees = disbursed.fold<double>(0, (sum, d) => sum + d.trusteeFeeAmount);
    final totalNet = totalGross - totalFees;

    return RefreshIndicator(
      color: CitadelColors.primary,
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          _buildDividendSummaryCard(totalGross, totalNet),
          const SizedBox(height: 12),
          ..._dividends.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DividendCard(dividend: d),
          )),
        ],
      ),
    );
  }

  Widget _buildDividendSummaryCard(double totalGross, double totalNet) {
    String formatAmount(double v) =>
      'RM ${v.toStringAsFixed(2).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF162032)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CitadelColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Dividends Earned',
                  style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.textSecondary)),
                const SizedBox(height: 4),
                Text(formatAmount(totalGross),
                  style: GoogleFonts.jost(fontSize: 17, fontWeight: FontWeight.w700, color: CitadelColors.textPrimary)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Net After Fees',
                  style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w600, color: CitadelColors.textSecondary)),
                const SizedBox(height: 4),
                Text(formatAmount(totalNet),
                  style: GoogleFonts.jost(fontSize: 17, fontWeight: FontWeight.w700, color: CitadelColors.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Row Data Class ──────────────────────────────────────────

class _DetailRow {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

// ─── Dividend Card ──────────────────────────────────────────────────

class _DividendCard extends StatelessWidget {
  final TrustDividend dividend;
  const _DividendCard({required this.dividend});

  @override
  Widget build(BuildContext context) {
    final isPaid = dividend.paymentStatus == 'PAID';
    final statusLabel = dividend.paymentStatusLabel;
    final heroColor = CitadelColors.success;

    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dividend.quarterLabel.isNotEmpty
                    ? 'Q${dividend.quarterLabel} Profit Sharing'
                    : 'Profit Sharing',
                  style: GoogleFonts.jost(fontSize: 14, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid ? CitadelColors.success.withValues(alpha: 0.12) : CitadelColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusLabel,
                    style: GoogleFonts.jost(fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: isPaid ? CitadelColors.success : CitadelColors.warning)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Hero amount — net payout (what client receives)
            Text('Net Payout',
              style: GoogleFonts.jost(fontSize: 11, color: CitadelColors.textMuted)),
            const SizedBox(height: 2),
            Text(dividend.netAmount,
              style: GoogleFonts.jost(fontSize: 17, fontWeight: FontWeight.w700, color: heroColor)),
            const SizedBox(height: 12),
            // Details row: gross + trustee fee
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gross Amount', style: GoogleFonts.jost(fontSize: 10, color: CitadelColors.textMuted)),
                      const SizedBox(height: 1),
                      Text(dividend.displayAmount,
                        style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w500, color: CitadelColors.textSecondary)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trustee Fee', style: GoogleFonts.jost(fontSize: 10, color: CitadelColors.textMuted)),
                      const SizedBox(height: 1),
                      Text('−${dividend.displayTrusteeFee}',
                        style: GoogleFonts.jost(fontSize: 13, fontWeight: FontWeight.w500, color: CitadelColors.warning)),
                    ],
                  ),
                ),
              ],
            ),
            // Dashed footer: reference + period
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: CitadelColors.border, width: 1, style: BorderStyle.solid)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dividend.referenceNumber,
                    style: GoogleFonts.jost(fontSize: 10, color: CitadelColors.textMuted, fontWeight: FontWeight.w400)),
                  Text(
                    dividend.periodStartingDate != null
                      ? '${dividend.displayDate(dividend.periodStartingDate)} — ${dividend.displayDate(dividend.periodEndingDate)}'
                      : '—',
                    style: GoogleFonts.jost(fontSize: 10, color: CitadelColors.textMuted),
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

// ─── Bank Account Selection Sheet ──────────────────────────────────────

class _BankSelectionSheet extends StatefulWidget {
  final int portfolioId;
  final int? currentBankDetailsId;
  final VoidCallback onLinked;

  const _BankSelectionSheet({
    required this.portfolioId,
    this.currentBankDetailsId,
    required this.onLinked,
  });

  @override
  State<_BankSelectionSheet> createState() => _BankSelectionSheetState();
}

class _BankSelectionSheetState extends State<_BankSelectionSheet> {
  final _service = PortfolioService();
  List<BankDetails> _banks = [];
  int? _selectedBankId;
  bool _loading = true;
  bool _linking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedBankId = widget.currentBankDetailsId;
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    try {
      final banks = await _service.getMyBankDetails();
      if (mounted) {
        setState(() {
          _banks = banks;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load bank accounts';
        });
      }
    }
  }

  Future<void> _linkBank() async {
    if (_selectedBankId == null) return;
    setState(() => _linking = true);
    try {
      await _service.linkBankAccount(widget.portfolioId, _selectedBankId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bank account linked successfully', style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.success,
        ));
        widget.onLinked();
      }
    } catch (e) {
      debugPrint('Link bank error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to link bank account: ${e.toString()}', style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.error,
        ));
        setState(() => _linking = false);
      }
    }
  }

  // Malaysian bank initial colors
  Color _bankColor(String bankName) {
    final name = bankName.toLowerCase();
    if (name.contains('maybank')) return const Color(0xFF29ABE2);
    if (name.contains('cimb')) return const Color(0xFF22C55E);
    if (name.contains('public')) return const Color(0xFFEF4444);
    if (name.contains('rhb')) return const Color(0xFFF59E0B);
    if (name.contains('hong')) return const Color(0xFF8B5CF6);
    if (name.contains('ambank')) return const Color(0xFFF97316);
    if (name.contains('uob')) return const Color(0xFFEF4444);
    if (name.contains('ocbc')) return const Color(0xFFEF4444);
    if (name.contains('hsbc')) return const Color(0xFFEF4444);
    return const Color(0xFF29ABE2);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: CitadelColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: CitadelColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text('Select Bank Account', style: GoogleFonts.jost(
                    fontSize: 18, fontWeight: FontWeight.w700, color: CitadelColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Choose a bank account for payouts', style: GoogleFonts.jost(
                    fontSize: 12, color: CitadelColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Bank list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: CitadelColors.primary))
                  : _error != null
                      ? Center(child: Text(_error!, style: GoogleFonts.jost(color: CitadelColors.error)))
                      : _banks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.account_balance_outlined, size: 40, color: CitadelColors.textMuted),
                                  const SizedBox(height: 8),
                                  Text('No bank accounts added yet', style: GoogleFonts.jost(color: CitadelColors.textMuted)),
                                ],
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                ..._banks.map((bank) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _BankOption(
                                    bank: bank,
                                    isSelected: _selectedBankId == bank.id,
                                    bankColor: _bankColor(bank.bankName ?? ''),
                                    onTap: () => setState(() => _selectedBankId = bank.id),
                                  ),
                                )),
                                // Add new bank account option
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      context.push('/client/bank-details');
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: CitadelColors.textMuted.withValues(alpha: 0.3), width: 2, style: BorderStyle.solid),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text('+ Add New Bank Account', style: GoogleFonts.jost(
                                          fontSize: 13, fontWeight: FontWeight.w500, color: CitadelColors.textSecondary)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
            ),
            // Confirm button
            if (_banks.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedBankId != null && !_linking ? _linkBank : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CitadelColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor: CitadelColors.primary.withValues(alpha: 0.5),
                    ),
                    child: _linking
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Confirm Selection', style: GoogleFonts.jost(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BankOption extends StatelessWidget {
  final BankDetails bank;
  final bool isSelected;
  final Color bankColor;
  final VoidCallback onTap;

  const _BankOption({
    required this.bank,
    required this.isSelected,
    required this.bankColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? bankColor.withValues(alpha: 0.08) : CitadelColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? bankColor : CitadelColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Bank initial avatar
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: bankColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    (bank.bankName ?? '?').substring(0, 1).toUpperCase(),
                    style: GoogleFonts.jost(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bank.bankName ?? 'Unknown', style: GoogleFonts.jost(
                      fontSize: 14, fontWeight: FontWeight.w600, color: CitadelColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${bank.accountHolderName ?? 'N/A'} · ${bank.maskedAccountNumber}', style: GoogleFonts.jost(
                      fontSize: 12, color: CitadelColors.textMuted)),
                    if (bank.swiftCode != null && bank.swiftCode!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text('SWIFT: ${bank.swiftCode}', style: GoogleFonts.jost(
                        fontSize: 11, color: CitadelColors.textMuted)),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: bankColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}