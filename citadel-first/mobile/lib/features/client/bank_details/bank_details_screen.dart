import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../core/theme/citadel_colors.dart';
import '../../../core/constants/malaysian_banks.dart';
import '../../../models/bank_details.dart';
import '../../../services/portfolio_service.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _service = PortfolioService();
  List<BankDetails> _banks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    try {
      final banks = await _service.getMyBankDetails();
      if (mounted) {
        setState(() {
          _banks = banks;
          _loading = false;
          _error = null;
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

  Future<void> _deleteBank(BankDetails bank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CitadelColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Bank Account?',
            style: GoogleFonts.jost(color: CitadelColors.textPrimary)),
        content: Text(
            'Are you sure you want to remove ${bank.bankName ?? "this account"}?',
            style: GoogleFonts.jost(color: CitadelColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.jost(color: CitadelColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.jost(color: CitadelColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteBankDetails(bank.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bank account removed',
              style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.success,
        ));
        _fetchBanks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete bank account',
              style: GoogleFonts.jost()),
          backgroundColor: CitadelColors.error,
        ));
      }
    }
  }

  void _showAddEditSheet([BankDetails? bank]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CitadelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BankFormSheet(
        bank: bank,
        onSaved: () {
          Navigator.pop(ctx);
          _fetchBanks();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitadelColors.background,
      appBar: AppBar(
        backgroundColor: CitadelColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: CitadelColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Bank Accounts',
            style: GoogleFonts.jost(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CitadelColors.textPrimary)),
        centerTitle: true,
        actions: [
          if (_banks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_rounded,
                  color: CitadelColors.primary),
              onPressed: () => _showAddEditSheet(),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: CitadelColors.primary))
          : _error != null
              ? _buildError()
              : _banks.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: CitadelColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.account_balance_outlined,
                  size: 36, color: CitadelColors.primary),
            ),
            const SizedBox(height: 24),
            Text('No Bank Accounts Yet',
                style: GoogleFonts.jost(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: CitadelColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Link your bank account to receive trust payouts and dividend collections.',
                style: GoogleFonts.jost(
                    fontSize: 13,
                    color: CitadelColors.textMuted,
                    height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _showAddEditSheet(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add Bank Account',
                  style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CitadelColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: CitadelColors.primary,
      backgroundColor: CitadelColors.surface,
      onRefresh: _fetchBanks,
      child: CustomScrollView(
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Bank Accounts',
                      style: GoogleFonts.jost(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: CitadelColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Manage your linked bank accounts for trust payouts',
                      style: GoogleFonts.jost(
                          fontSize: 13, color: CitadelColors.textMuted)),
                ],
              ),
            ),
          ),

          // Bank cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _BankCard(
                    bank: _banks[index],
                    onEdit: () => _showAddEditSheet(_banks[index]),
                    onDelete: () => _deleteBank(_banks[index]),
                  ),
                ),
                childCount: _banks.length,
              ),
            ),
          ),

          // Add button at bottom
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: OutlinedButton(
                onPressed: () => _showAddEditSheet(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CitadelColors.primary,
                  side: const BorderSide(color: CitadelColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('+ Add Bank Account',
                        style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: CitadelColors.error),
          const SizedBox(height: 16),
          Text(_error!,
              style: GoogleFonts.jost(
                  fontSize: 14, color: CitadelColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchBanks,
            style: ElevatedButton.styleFrom(
              backgroundColor: CitadelColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Bank account card (Design B: Bank Statement style)
// ═══════════════════════════════════════════════════════════════════════

class _BankCard extends StatelessWidget {
  final BankDetails bank;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BankCard({
    required this.bank,
    required this.onEdit,
    required this.onDelete,
  });

  String get _bankInitial {
    final name = bank.bankName ?? '?';
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }

  Color get _initialColor {
    final name = (bank.bankName ?? '').toLowerCase();
    if (name.contains('maybank')) return CitadelColors.primary;
    if (name.contains('cimb')) return CitadelColors.success;
    if (name.contains('public')) return CitadelColors.warning;
    if (name.contains('rhb')) return const Color(0xFF8B5CF6);
    if (name.contains('hong leong')) return const Color(0xFFEC4899);
    if (name.contains('ambank')) return const Color(0xFFF97316);
    if (name.contains('hsbc')) return const Color(0xFFEF4444);
    return CitadelColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Column(
        children: [
          // Top row: initial + name + menu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _initialColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(_bankInitial,
                        style: GoogleFonts.jost(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bank.bankName ?? 'Unnamed Bank',
                          style: GoogleFonts.jost(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: CitadelColors.textPrimary)),
                      const SizedBox(height: 1),
                      Text(bank.maskedAccountNumber,
                          style: GoogleFonts.jost(
                              fontSize: 12,
                              color: CitadelColors.textMuted,
                              fontFeatures: [FontFeature.tabularFigures()],
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: CitadelColors.textSecondary, size: 22),
                  color: const Color(0xFF2A3A50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_outlined,
                            size: 18, color: CitadelColors.textSecondary),
                        const SizedBox(width: 8),
                        Text('Edit',
                            style: GoogleFonts.jost(
                                color: CitadelColors.textPrimary)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline,
                            size: 18, color: CitadelColors.error),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style:
                                GoogleFonts.jost(color: CitadelColors.error)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Info rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                if (bank.accountHolderName != null && bank.accountHolderName!.isNotEmpty)
                  _infoRow('Account Holder', bank.accountHolderName!),
                if (bank.swiftCode != null && bank.swiftCode!.isNotEmpty)
                  _infoRow('SWIFT Code', bank.swiftCode!),
                if (_hasAddress)
                  _infoRow('Address', _fullAddress),
              ],
            ),
          ),
          // Proof indicator
          if (bank.hasProof)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded,
                      size: 13, color: CitadelColors.success),
                  const SizedBox(width: 4),
                  Text('Proof uploaded',
                      style: GoogleFonts.jost(
                          fontSize: 11,
                          color: CitadelColors.success,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasAddress {
    return [bank.bankAddress, bank.postcode, bank.city, bank.state, bank.country]
        .any((v) => v != null && v.isNotEmpty);
  }

  String get _fullAddress {
    return [bank.bankAddress, bank.postcode, bank.city, bank.state, bank.country]
        .where((v) => v != null && v.isNotEmpty)
        .join(', ');
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: GoogleFonts.jost(
                    fontSize: 11, color: CitadelColors.textMuted)),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: GoogleFonts.jost(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: CitadelColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Add/Edit bank account bottom sheet — Design A: Banking Premium
// ═══════════════════════════════════════════════════════════════════════

class _BankFormSheet extends StatefulWidget {
  final BankDetails? bank;
  final VoidCallback onSaved;

  const _BankFormSheet({this.bank, required this.onSaved});

  @override
  State<_BankFormSheet> createState() => _BankFormSheetState();
}

class _BankFormSheetState extends State<_BankFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _service = PortfolioService();
  bool _saving = false;

  // Bank selection
  MalaysianBank? _selectedBank;
  bool _isOtherBank = false;

  // Proof upload
  File? _proofFile;

  late final TextEditingController _bankName;
  late final TextEditingController _holderName;
  late final TextEditingController _accountNumber;
  late final TextEditingController _bankAddress;
  late final TextEditingController _postcode;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _branchSwiftCode;

  String _generalSwiftCode = '';

  @override
  void initState() {
    super.initState();
    final b = widget.bank;
    _bankName = TextEditingController(text: b?.bankName ?? '');
    _holderName = TextEditingController(text: b?.accountHolderName ?? '');
    _accountNumber = TextEditingController(text: b?.accountNumber ?? '');
    _bankAddress = TextEditingController(text: b?.bankAddress ?? '');
    _postcode = TextEditingController(text: b?.postcode ?? '');
    _city = TextEditingController(text: b?.city ?? '');
    _state = TextEditingController(text: b?.state ?? '');
    _country = TextEditingController(text: b?.country ?? '');

    // If editing an existing bank, try to match it to the known banks list
    if (b != null) {
      final existingSwift = b.swiftCode ?? '';
      final matchedBank = malaysianBanks.where(
        (mb) => mb.name == b.bankName || (existingSwift.isNotEmpty && existingSwift.startsWith(mb.swiftCode)),
      ).firstOrNull;

      if (matchedBank != null) {
        _selectedBank = matchedBank;
        _generalSwiftCode = matchedBank.swiftCode;
        // Extract branch suffix from existing SWIFT code
        if (existingSwift.length > matchedBank.swiftCode.length) {
          _branchSwiftCode = TextEditingController(
            text: existingSwift.substring(matchedBank.swiftCode.length),
          );
        } else {
          _branchSwiftCode = TextEditingController();
        }
      } else if (b.bankName != null && b.bankName!.isNotEmpty) {
        _isOtherBank = true;
        _branchSwiftCode = TextEditingController(text: existingSwift);
      } else {
        _branchSwiftCode = TextEditingController(text: existingSwift);
      }
    } else {
      _branchSwiftCode = TextEditingController();
    }
  }

  @override
  void dispose() {
    _bankName.dispose();
    _holderName.dispose();
    _accountNumber.dispose();
    _bankAddress.dispose();
    _postcode.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _branchSwiftCode.dispose();
    super.dispose();
  }

  String get _fullSwiftCode {
    if (_isOtherBank) {
      return _branchSwiftCode.text.trim().toUpperCase();
    }
    final branch = _branchSwiftCode.text.trim().toUpperCase();
    if (_generalSwiftCode.isEmpty && branch.isEmpty) return '';
    return '$_generalSwiftCode$branch';
  }

  void _onBankSelected(MalaysianBank? bank) {
    if (bank == null) return;
    setState(() {
      if (bank.name == 'Other') {
        _isOtherBank = true;
        _selectedBank = null;
        _generalSwiftCode = '';
        _bankName.clear();
      } else {
        _isOtherBank = false;
        _selectedBank = bank;
        _generalSwiftCode = bank.swiftCode;
        _bankName.text = bank.name;
      }
    });
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _proofFile = File(picked.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    String? proofKey;

    // Upload proof if selected
    if (_proofFile != null) {
      try {
        final ext = _proofFile!.path.split('.').lastOrNull ?? 'jpg';
        final fileName = 'proof_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final uploadData = await _service.getBankProofUploadUrl(
          fileName: fileName,
          contentType: 'image/jpeg',
        );
        final bytes = await _proofFile!.readAsBytes();
        await Dio().put(
          uploadData['upload_url']!,
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              'Content-Type': 'image/jpeg',
              'Content-Length': bytes.length.toString(),
            },
          ),
        );
        proofKey = uploadData['key'];
      } catch (e) {
        // Log but don't block the save — proof is optional
        debugPrint('Proof upload failed: $e');
      }
    }

    final data = {
      'bank_name': _bankName.text.trim(),
      'account_holder_name': _holderName.text.trim(),
      'account_number': _accountNumber.text.trim(),
      if (_bankAddress.text.trim().isNotEmpty)
        'bank_address': _bankAddress.text.trim(),
      if (_postcode.text.trim().isNotEmpty)
        'postcode': _postcode.text.trim(),
      if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
      if (_state.text.trim().isNotEmpty) 'state': _state.text.trim(),
      if (_country.text.trim().isNotEmpty) 'country': _country.text.trim(),
      if (_fullSwiftCode.isNotEmpty) 'swift_code': _fullSwiftCode,
      if (proofKey != null) 'bank_account_proof_key': proofKey,
    };

    try {
      if (widget.bank != null) {
        await _service.updateBankDetails(widget.bank!.id, data);
      } else {
        await _service.createBankDetails(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.bank != null
              ? 'Bank account updated'
              : 'Bank account added'),
          backgroundColor: CitadelColors.success,
        ));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save bank account'),
          backgroundColor: CitadelColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bank != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: CitadelColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(isEdit ? 'Edit Bank Account' : 'Add Bank Account',
                    style: GoogleFonts.jost(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: CitadelColors.textPrimary)),
              ),
              const SizedBox(height: 20),

              // ─── Section 1: Bank Details ───
              _SectionCard(
                icon: Icons.account_balance_rounded,
                iconColor: CitadelColors.primary,
                iconBg: CitadelColors.primary.withValues(alpha: 0.15),
                label: 'BANK DETAILS',
                children: [
                  // Bank dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Bank *',
                          style: GoogleFonts.jost(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: CitadelColors.textMuted)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: CitadelColors.background,
                          border: Border.all(color: CitadelColors.border, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MalaysianBank>(
                            isExpanded: true,
                            dropdownColor: CitadelColors.surfaceLight,
                            hint: Text('Choose your bank...',
                                style: GoogleFonts.jost(
                                    fontSize: 14,
                                    color: CitadelColors.textMuted)),
                            value: _isOtherBank ? otherBank : _selectedBank,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: CitadelColors.textMuted),
                            items: [...malaysianBanks, otherBank]
                                .map((b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(
                                        b.swiftCode.isNotEmpty
                                            ? '${b.name}  —  ${b.swiftCode}'
                                            : b.name,
                                        style: GoogleFonts.jost(
                                            fontSize: 14,
                                            color: CitadelColors.textPrimary),
                                      ),
                                    ))
                                .toList(),
                            onChanged: _onBankSelected,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Other bank name field (shown when "Other" is selected)
                  if (_isOtherBank) ...[
                    _field(_bankName, 'Bank Name *',
                        hint: 'Enter your bank name', required: true),
                    const SizedBox(height: 14),
                  ],

                  _field(_holderName, 'Account Holder Name *',
                      hint: 'e.g., John Doe', required: true),
                  const SizedBox(height: 14),
                  _field(_accountNumber, 'Account Number *',
                      hint: 'e.g., 1234567890', required: true, keyboardType: TextInputType.number),
                ],
              ),

              // ─── Section 2: SWIFT Code ───
              _SectionCard(
                icon: Icons.bolt_rounded,
                iconColor: CitadelColors.warning,
                iconBg: CitadelColors.warning.withValues(alpha: 0.15),
                label: 'SWIFT CODE',
                children: [
                  // General + Branch SWIFT code row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // General SWIFT code (auto-populated)
                      Expanded(
                        flex: 0,
                        child: SizedBox(
                          width: 130,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('General Code',
                                  style: GoogleFonts.jost(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: CitadelColors.textMuted)),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: CitadelColors.primary.withValues(alpha: 0.06),
                                  border: Border.all(
                                      color: CitadelColors.primary.withValues(alpha: 0.3), width: 1.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _isOtherBank
                                      ? '—'
                                      : (_generalSwiftCode.isEmpty ? 'Auto-filled' : _generalSwiftCode),
                                  style: GoogleFonts.jost(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _generalSwiftCode.isEmpty
                                        ? CitadelColors.textMuted
                                        : CitadelColors.primary,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 26),
                        child: Text('+',
                            style: GoogleFonts.jost(
                                fontSize: 18,
                                color: CitadelColors.textMuted)),
                      ),
                      // Branch SWIFT code
                      Expanded(
                        flex: 1,
                        child: _field(
                          _branchSwiftCode,
                          _isOtherBank ? 'Full SWIFT Code' : 'Branch Code',
                          hint: _isOtherBank ? 'e.g., MBBEMYKLPJY' : 'e.g., PJY',
                          required: false,
                          keyboardType: TextInputType.text,
                          isMonospace: true,
                        ),
                      ),
                    ],
                  ),

                  // SWIFT preview
                  if (_fullSwiftCode.isNotEmpty && !_isOtherBank) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: CitadelColors.primary.withValues(alpha: 0.08),
                        border: Border.all(
                            color: CitadelColors.primary.withValues(alpha: 0.3),
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Full SWIFT Code',
                                    style: GoogleFonts.jost(
                                        fontSize: 11,
                                        color: CitadelColors.textMuted)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(_generalSwiftCode,
                                        style: GoogleFonts.jetBrainsMono(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: CitadelColors.primary,
                                            letterSpacing: 1)),
                                    if (_branchSwiftCode.text.trim().isNotEmpty)
                                      Text(_branchSwiftCode.text.trim().toUpperCase(),
                                          style: GoogleFonts.jetBrainsMono(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: CitadelColors.warning,
                                              letterSpacing: 1)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // ─── Section 3: Bank Address ───
              _SectionCard(
                icon: Icons.location_on_rounded,
                iconColor: CitadelColors.success,
                iconBg: CitadelColors.success.withValues(alpha: 0.15),
                label: 'BANK ADDRESS',
                children: [
                  _field(_bankAddress, 'Address',
                      hint: 'e.g., 123 Jalan Bukit Bintang'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: _field(_postcode, 'Postcode',
                            hint: '55100', keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_city, 'City', hint: 'Kuala Lumpur')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _field(_state, 'State', hint: 'Wilayah Persekutuan')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_country, 'Country', hint: 'Malaysia')),
                    ],
                  ),
                ],
              ),

              // ─── Section 4: Proof Upload ───
              _SectionCard(
                icon: Icons.upload_file_rounded,
                iconColor: const Color(0xFF8B5CF6),
                iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                label: 'PROOF DOCUMENT',
                children: [
                  Text('Upload a bank statement or passbook image as proof of your account.',
                      style: GoogleFonts.jost(
                          fontSize: 12, color: CitadelColors.textMuted, height: 1.4)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _saving ? null : _pickProof,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CitadelColors.background,
                        border: Border.all(
                          color: _proofFile != null
                              ? CitadelColors.success.withValues(alpha: 0.5)
                              : CitadelColors.border,
                          width: 1.5,
                          style: _proofFile != null ? BorderStyle.solid : BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _proofFile != null
                          ? Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: CitadelColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.check_circle_rounded,
                                      color: CitadelColors.success, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Proof uploaded',
                                          style: GoogleFonts.jost(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: CitadelColors.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text('Tap to change',
                                          style: GoogleFonts.jost(
                                              fontSize: 12,
                                              color: CitadelColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.edit_outlined,
                                    size: 18, color: CitadelColors.textMuted),
                              ],
                            )
                          : Column(
                              children: [
                                Icon(Icons.cloud_upload_outlined,
                                    size: 32, color: CitadelColors.textMuted),
                                const SizedBox(height: 8),
                                Text('Tap to upload proof',
                                    style: GoogleFonts.jost(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: CitadelColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text('JPG, PNG up to 10MB',
                                    style: GoogleFonts.jost(
                                        fontSize: 11,
                                        color: CitadelColors.textMuted)),
                              ],
                            ),
                    ),
                  ),
                  if (widget.bank?.hasProof == true && _proofFile == null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 14, color: CitadelColors.success),
                        const SizedBox(width: 4),
                        Text('Existing proof on file',
                            style: GoogleFonts.jost(
                                fontSize: 12,
                                color: CitadelColors.success,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CitadelColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Update' : 'Add Account',
                            style: GoogleFonts.jost(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Safe area for Android bottom nav
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {String? hint, bool required = false, TextInputType? keyboardType, bool isMonospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.jost(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CitadelColors.textMuted),
            children: required
                ? [TextSpan(text: ' *', style: GoogleFonts.jost(fontSize: 12, color: CitadelColors.primary))]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: isMonospace
              ? GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: CitadelColors.textPrimary,
                  letterSpacing: 1,
                )
              : GoogleFonts.jost(
                  fontSize: 14,
                  color: CitadelColors.textPrimary,
                ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: isMonospace
                ? GoogleFonts.jetBrainsMono(
                    fontSize: 13, color: CitadelColors.textMuted, letterSpacing: 1)
                : GoogleFonts.jost(
                    fontSize: 13, color: CitadelColors.textMuted),
            filled: true,
            fillColor: CitadelColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CitadelColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CitadelColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CitadelColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CitadelColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            isDense: true,
          ),
          textCapitalization: isMonospace ? TextCapitalization.characters : TextCapitalization.none,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
              : null,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section card with icon badge (Design A pattern)
// ═══════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CitadelColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CitadelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with icon badge
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.jost(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CitadelColors.textSecondary,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}