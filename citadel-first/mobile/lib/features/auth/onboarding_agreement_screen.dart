import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:signature/signature.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../models/onboarding_agreement.dart';
import 'widgets/signup_progress_bar.dart' show SignupProgressBar;

// ── Brand tokens ──────────────────────────────────────────────────────────────
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

BoxDecoration _glassCardDecoration() => BoxDecoration(
  color: Colors.white.withAlpha(6),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _borderGlass.withAlpha(60), width: 1),
);

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

// ── Agreement text (matches backend template) ────────────────────────────────
const _agreementSections = <Map<String, String>>[
  {
    'title': '1. Interpretation and Definitions',
    'body':
        'The words of which the initial letter is capitalized have meanings defined under the following conditions. '
        'The following definitions shall have the same meaning regardless of whether they appear in singular or plural.\n\n'
        '"Application" means the software program provided by the Company downloaded by You on any electronic device, named CITADEL FIRST.\n'
        '"Application Store" means the digital distribution service operated and developed by Apple Inc. (Apple App Store) or Google Inc. (Google Play Store).\n'
        '"Affiliate" means an entity that controls, is controlled by or is under common control with a party.\n'
        '"Account" means a unique account created for You to access our Service.\n'
        '"Company" refers to CITADEL GROUP SDN. BHD.\n'
        '"Country" refers to Malaysia.\n'
        '"Content" refers to all forms of text, files, data, images, photographs, video streaming, or other information.\n'
        '"Device" means any device that can access the Service.\n'
        '"Feedback" means feedback or suggestions sent by You regarding our Service.\n'
        '"Service" refers to the use and access to the Application.\n'
        '"SuperApp" refers to the mobile application developed by CITADEL GROUP SDN. BHD.\n'
        '"Terms and Conditions" mean these Terms and Conditions that form the entire agreement between You and the Company.\n'
        '"You" means the individual accessing or using the Service.',
  },
  {
    'title': '2. Acknowledgement',
    'body':
        'These are the Terms and Conditions governing the use of this Service and the agreement that operates between You and the Company. '
        'These Terms and Conditions set out the rights and obligations of all users regarding the use of the Service.\n\n'
        'Your access to and use of the Service is conditioned on Your acceptance of and compliance with these Terms and Conditions. '
        'By accessing or using the Service You agree to be bound by these Terms and Conditions. '
        'If You disagree with any part of these Terms and Conditions, then You may not access the Service.\n\n'
        'Our Service is the property of the Company. We grant you a non-exclusive, non-sub-licensable, revocable and limited license '
        'to access our Platform to enjoy personal, non-commercial use of our Service.\n\n'
        'You represent that you are over the age of 18. The Company does not permit those under 18 to use the Service.\n\n'
        'Your access to and use of the Service is also conditioned on Your acceptance of and compliance with the Privacy Policy of the Company.',
  },
  {
    'title': '3. User Accounts',
    'body':
        'When You create an account with Us, You must provide Us information that is accurate, complete, and current at all times. '
        'Failure to do so constitutes a breach of the Terms and Conditions, which may result in immediate termination of Your account.\n\n'
        'You are responsible for safeguarding the password that You use to access the Service and for any activities or actions under Your password. '
        'You agree not to disclose Your password to any third party. You must notify Us immediately upon becoming aware of any breach of security or unauthorized use of Your account.',
  },
  {
    'title': '4. Information as Content',
    'body':
        'Our Service allows You to post your information as Content. You are responsible for the Content that You post to the Service, '
        'including its legality, reliability, and appropriateness.\n\n'
        'By posting information as content to the Service, You grant Us the right and license to use, modify, publicly perform, '
        'publicly display, reproduce, and distribute such Content on and through the Service.',
  },
  {
    'title': '5. Content Restrictions',
    'body':
        'The Company is not responsible for the information as content of the Service\'s users. '
        'You expressly understand and agree that You are solely responsible for the information as content and for all activity that occurs under your account.\n\n'
        'You may not transmit any information as content that is unlawful, offensive, upsetting, intended to disgust, threatening, '
        'libelous, defamatory, obscene or otherwise objectionable.\n\n'
        'The Company reserves the right, but not the obligation, to determine whether or not any information as content is appropriate and complies with these Terms and Conditions.',
  },
  {
    'title': '6. Personal Data',
    'body':
        'Where the Personal Data Protection Act 2010 (PDPA) is relevant to the disclosure of data or information by the User, '
        'the Company hereby agrees to fully comply with the provisions of the PDPA.\n\n'
        'The Company takes your right to privacy seriously and commits to protecting your personally identifiable information and the laws of Malaysia. '
        'The legal basis we rely on for processing of your personal data may be: your consent; compliance with the Company\'s legal obligations; '
        'protection of your vital interests; the Company\'s performance of statutory duties; the Company\'s legitimate interests.\n\n'
        'The types of personal data which the Company may need to process include but are not limited to: your name, date of birth, '
        'identification supporting documents (including NRIC or passport number), gender, nationality and race, current private and/or business address, '
        'telephone or mobile phone number, email address; your credit and/or debit card information, bank account details and your payment history.\n\n'
        'You have the right under PDPA 2010 to make a data access request with respect to your personal data held by us.',
  },
  {
    'title': '7. Consent',
    'body':
        'To the extent that any of the data/information of the User is disclosed pursuant to this Terms, '
        'the User hereby irrevocably consent, authorize and confirm that the data/information belongs to the User '
        'or the User have the right to use it and grant the Company the rights and license as provided in these Terms and Conditions.',
  },
  {
    'title': '8. Copyright Policy',
    'body':
        'The Service and its original content (excluding information content provided by You or other users), '
        'features and functionality are and will remain the exclusive property of the Company and its licensors.\n\n'
        'We respect the intellectual property rights of others. It is Our policy to respond to any claim that Content posted on the Service '
        'infringes a copyright or other intellectual property infringement of any person.',
  },
  {
    'title': '9. Other Websites and Third-Party Links',
    'body':
        'Our Service may contain links to third-party websites or services that are not owned or controlled by the Company. '
        'The Company has no control over, and assumes no responsibility for, the content, privacy policies, or practices of any third-party web sites or services.',
  },
  {
    'title': '10. Termination',
    'body':
        'We may terminate or suspend Your Account immediately, without prior notice or liability, for any reason whatsoever, '
        'including without limitation if You breach these Terms and Conditions.\n\n'
        'Upon termination, Your right to use the Service will cease immediately. '
        'If You wish to terminate Your Account, You may simply discontinue using the Service.',
  },
  {
    'title': '11. Disclaimer and Limitation of Liability',
    'body':
        'Notwithstanding any damages that You might incur, the entire liability of the Company and any of its suppliers under any provision '
        'of this Terms and Conditions and Your exclusive remedy for all of the foregoing shall be limited to the amount actually paid by You '
        'as the User through the Service or RM 1,000.00 if You have not purchased anything through the Service.\n\n'
        'To the maximum extent permitted by applicable law, in no event shall the Company or its suppliers be liable for any special, '
        'incidental, indirect, or consequential damages whatsoever.',
  },
  {
    'title': '12. "As Is" and "As Available" Disclaimer',
    'body':
        'The Service is provided to You "AS IS" and "AS AVAILABLE" and with all faults and defects without warranty of any kind. '
        'To the maximum extent permitted under applicable law, the Company, on its own behalf and on behalf of its Affiliates and its and their '
        'respective licensors and service providers, expressly disclaims all warranties, whether express, implied, statutory or otherwise, '
        'with respect to the Service.',
  },
  {
    'title': '13. Governing Law',
    'body': 'These Terms and Conditions shall be governed in accordance with the laws of Malaysia.',
  },
  {
    'title': '14. Severability and Waiver',
    'body':
        'In the event that any of the terms, conditions or provisions contained in this Terms and Conditions shall be deemed invalid, '
        'unlawful or unenforceable to any extent, such term, condition or provision shall be severed from the remaining terms, conditions '
        'and provisions which shall continue to be valid to the fullest extent permitted by law.\n\n'
        'Except as provided herein, the failure to exercise a right or to require performance of an obligation under these Terms and Conditions '
        'shall not affect a party\'s ability to exercise such right or require such performance at any time thereafter.',
  },
  {
    'title': '15. Changes to These Terms and Conditions',
    'body':
        'We reserve the right, at Our sole discretion, to modify or replace these Terms and Conditions at any time. '
        'If a revision is material, We will make reasonable efforts to provide at least 30 days\' notice prior to any new terms taking effect.\n\n'
        'By continuing to access or use Our Service after those revisions become effective, You agree to be bound by the revised terms.',
  },
  {
    'title': '16. Miscellaneous',
    'body':
        'The Company reserves the right, in its sole discretion, to the extent permissible under relevant law to temporarily or permanently '
        'modify, suspend, or terminate the Service and/or any part thereof.\n\n'
        'These Terms and Conditions and other documents expressly referred to in these Terms, as may be amended from time to time, '
        'constitute the entire agreement and understanding between the Company and you in relation to the subject matter of these Terms and Conditions.',
  },
  {
    'title': 'Contact Us',
    'body':
        'If you have any questions about these Terms and Conditions, please contact Citadel Group via email at enquiry@citadelgroup.com.my',
  },
];

class OnboardingAgreementScreen extends StatefulWidget {
  const OnboardingAgreementScreen({super.key});

  @override
  State<OnboardingAgreementScreen> createState() =>
      _OnboardingAgreementScreenState();
}

class _OnboardingAgreementScreenState extends State<OnboardingAgreementScreen>
    with SingleTickerProviderStateMixin {
  final _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: const Color(0xFF111827),
    exportBackgroundColor: Colors.white,
  );

  String _fullName = '';
  String _icNumber = '';
  bool _hasScrolledToBottom = false;
  bool _declarationChecked = false;
  bool _isLoading = false;
  bool _isFetchingDetails = true;
  String? _errorMessage;

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
    _fetchUserDetails();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final response = await ApiClient().get(ApiEndpoints.signupUserDetails);
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _fullName = (data['name'] as String?) ?? '';
          _icNumber = (data['identity_card_number'] as String?) ?? '';
          _isFetchingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingDetails = false);
    }
  }

  bool get _canSubmit =>
      _hasScrolledToBottom &&
      _declarationChecked &&
      _signatureController.isNotEmpty &&
      _fullName.isNotEmpty &&
      _icNumber.isNotEmpty &&
      !_isLoading;

  Future<void> _onSignAndSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Declaration',
          style: GoogleFonts.jost(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _textHeading,
          ),
        ),
        content: Text(
          'I hereby declare that the information provided is true and correct. '
          'I agree to be bound by the Terms and Conditions of Citadel Group Sdn. Bhd.',
          style: GoogleFonts.jost(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: _textBody,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.jost(color: _textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.jost(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null || signatureBytes.isEmpty) {
        setState(() {
          _errorMessage = 'Could not capture signature. Please try again.';
          _isLoading = false;
        });
        return;
      }

      final signatureBase64 = base64Encode(signatureBytes);

      final data = OnboardingAgreementData(
        signatureBase64: signatureBase64,
        fullName: _fullName,
        icNumber: _icNumber,
      );

      await ApiClient().patch(ApiEndpoints.onboardingAgreement, data: data.toJson());

      if (mounted) context.push('/signup/client/success');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ??
          'Something went wrong. Please try again.';
      setState(() => _errorMessage = msg);
    } catch (e) {
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
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollEndNotification) {
                            final metrics = notification.metrics;
                            if (metrics.maxScrollExtent > 0 &&
                                metrics.pixels >= metrics.maxScrollExtent - 40) {
                              if (!_hasScrolledToBottom) {
                                setState(() => _hasScrolledToBottom = true);
                              }
                            }
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
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
                                        Icons.description_outlined,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'Onboarding Agreement',
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
                                      'Please read and accept the terms before signing',
                                      style: GoogleFonts.jost(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: _textBody,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // ── Card 1: Agreement text ─────────────────────
                              Container(
                                decoration: _glassCardDecoration(),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const _SectionHeader(
                                          icon: Icons.article_outlined,
                                          title: 'Terms & Conditions',
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _hasScrolledToBottom
                                                ? _cyan.withAlpha(18)
                                                : Colors.white.withAlpha(6),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _hasScrolledToBottom
                                                  ? _cyan.withAlpha(80)
                                                  : _borderGlass.withAlpha(45),
                                            ),
                                          ),
                                          child: Text(
                                            _hasScrolledToBottom
                                                ? 'All terms read'
                                                : 'Scroll to read',
                                            style: GoogleFonts.jost(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: _hasScrolledToBottom
                                                  ? _cyan
                                                  : _textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Citadel Group Sdn. Bhd',
                                      style: GoogleFonts.jost(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _cyanDim,
                                      ),
                                    ),
                                    Text(
                                      'L3-1 Wisma LYL, No 12, Jalan 51A/223, '
                                      'Seksyen 51A, 46100 Petaling Jaya, '
                                      'Selangor, Malaysia',
                                      style: GoogleFonts.jost(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w300,
                                        color: _textMuted,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    ..._agreementSections
                                        .expand((section) => [
                                              Text(
                                                section['title']!,
                                                style: GoogleFonts.jost(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textHeading,
                                                  height: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                section['body']!,
                                                style: GoogleFonts.jost(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w300,
                                                  color: _textBody,
                                                  height: 1.6,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                            ]),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Card 2: Identity confirmation ──────────────
                              Container(
                                decoration: _glassCardDecoration(),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionHeader(
                                      icon: Icons.badge_outlined,
                                      title: 'Identity Confirmation',
                                    ),
                                    const SizedBox(height: 16),
                                    _ReadOnlyField(
                                      label: 'Full Name',
                                      value: _isFetchingDetails
                                          ? 'Loading...'
                                          : _fullName,
                                    ),
                                    const SizedBox(height: 12),
                                    _ReadOnlyField(
                                      label: 'MyKad/Passport No.',
                                      value: _isFetchingDetails
                                          ? 'Loading...'
                                          : _icNumber,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Card 3: Digital signature ──────────────────
                              Container(
                                decoration: _glassCardDecoration(),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const _SectionHeader(
                                          icon: Icons.draw_outlined,
                                          title: 'Digital Signature',
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () =>
                                              _signatureController.clear(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _errorRed.withAlpha(15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Clear',
                                              style: GoogleFonts.jost(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: _errorRed,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _borderGlass.withAlpha(80),
                                        ),
                                      ),
                                      child: Signature(
                                        controller: _signatureController,
                                        backgroundColor: Colors.transparent,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Center(
                                      child: Text(
                                        'Sign above this line',
                                        style: GoogleFonts.jost(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w300,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Card 4: Declaration checkbox ───────────────
                              Container(
                                decoration: _glassCardDecoration(),
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _declarationChecked,
                                        onChanged: _hasScrolledToBottom
                                            ? (v) => setState(() =>
                                                _declarationChecked = v ?? false)
                                            : null,
                                        activeColor: _cyan,
                                        checkColor: Colors.white,
                                        side: BorderSide(
                                          color: _hasScrolledToBottom
                                              ? _cyan
                                              : _borderGlass,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'I have read and confirmed the Terms and Conditions. '
                                        'I agree to be bound by the Onboarding Agreement of Citadel Group Sdn. Bhd.',
                                        style: GoogleFonts.jost(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: _hasScrolledToBottom
                                              ? _textBody
                                              : _textMuted,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ── Error banner ────────────────────────────────
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                _ErrorBanner(message: _errorMessage!),
                              ],

                              const SizedBox(height: 24),

                              // ── CTA ─────────────────────────────────────────
                              _CtaButton(
                                enabled: _canSubmit,
                                isLoading: _isLoading,
                                onPressed: _onSignAndSubmit,
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

// ── Read-only identity field ──────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderGlass, width: 1),
          ),
          child: Text(
            value,
            style: GoogleFonts.jost(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFF8FAFC),
            ),
          ),
        ),
      ],
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

// ── Error banner ──────────────────────────────────────────────────────────────

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

// ── CTA button ────────────────────────────────────────────────────────────────

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
                ? [
                    BoxShadow(
                      color: _cyan.withAlpha(50),
                      blurRadius: 22,
                      offset: const Offset(0, 5),
                    )
                  ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: (enabled && !isLoading) ? onPressed : null,
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
                        'Sign & Submit',
                        style: GoogleFonts.jost(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.draw_outlined,
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