import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_bloc.dart';
import '../auth/auth_state.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/bankruptcy_declaration_screen.dart';
import '../../features/auth/disclaimer_screen.dart';
import '../../features/auth/document_selection_screen.dart';
import '../../features/auth/identity_verification_screen.dart';
import '../../features/auth/document_upload_screen.dart';
import '../../features/auth/document_review_screen.dart';
import '../../features/auth/selfie_instruction_screen.dart';
import '../../features/auth/selfie_capture_screen.dart';
import '../../features/auth/verification_processing_screen.dart';
import '../../features/auth/verification_result_screen.dart';
import '../../features/auth/personal_details_screen.dart';
import '../../features/auth/address_contact_screen.dart';
import '../../features/auth/employment_details_screen.dart';
import '../../features/auth/kyc_crs_screen.dart';
import '../../features/auth/pep_declaration_screen.dart';
import '../../features/auth/onboarding_agreement_screen.dart';
import '../../features/auth/signup_success_screen.dart';
import '../../features/client/dashboard/client_dashboard_screen.dart';
import '../../features/agent/dashboard/agent_dashboard_screen.dart';
import '../../models/document_upload.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final onLogin        = state.matchedLocation == '/login';
    final onSignup       = state.matchedLocation == '/signup';
    final onRegister     = state.matchedLocation == '/signup/register';
    final onDeclaration  = state.matchedLocation == '/signup/client/declaration';
    final onDisclaimer   = state.matchedLocation == '/signup/client/disclaimer';
    final onIdentity     = state.matchedLocation == '/signup/client/identity-verification';
    final onDocUpload    = state.matchedLocation == '/signup/client/document-upload';
    final onDocReview    = state.matchedLocation == '/signup/client/document-review';
    final onSelfieInst   = state.matchedLocation == '/signup/client/selfie-instruction';
    final onSelfieCapture = state.matchedLocation == '/signup/client/selfie-capture';
    final onProcessing   = state.matchedLocation == '/signup/client/verification-processing';
    final onVerifyResult = state.matchedLocation == '/signup/client/verification-success'
                        || state.matchedLocation == '/signup/client/verification-failed';
    final onPersonalDetails = state.matchedLocation == '/signup/client/personal-details';
    final onAddressContact = state.matchedLocation == '/signup/client/address-contact';
    final onEmploymentDetails = state.matchedLocation == '/signup/client/employment-details';
    final onKycCrs = state.matchedLocation == '/signup/client/kyc-crs';
    final onPepDeclaration = state.matchedLocation == '/signup/client/pep-declaration';
    final onOnboardingAgreement = state.matchedLocation == '/signup/client/onboarding-agreement';
    final onSignupSuccess = state.matchedLocation == '/signup/client/success';
    final onSignupFlow = onDeclaration || onDisclaimer || onIdentity || onDocUpload || onDocReview || onSelfieInst || onSelfieCapture || onProcessing || onVerifyResult || onPersonalDetails || onAddressContact || onEmploymentDetails || onKycCrs || onPepDeclaration || onOnboardingAgreement || onSignupSuccess || state.matchedLocation == '/signup/client/document-selection' || onRegister;

    if (authState is AuthAuthenticated) {
      if (!onSignupFlow) {
        return _dashboardRoute(authState.userType);
      }
    } else if (authState is AuthUnauthenticated) {
      if (!onLogin && !onSignup && !onSignupFlow) return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(path: '/signup/register', builder: (context, state) {
      final userType = state.extra as String? ?? 'CLIENT';
      return RegisterScreen(userType: userType);
    }),
    GoRoute(path: '/signup/client/declaration', builder: (context, state) => const BankruptcyDeclarationScreen()),
    GoRoute(path: '/signup/client/disclaimer', builder: (context, state) => const DisclaimerScreen()),
    GoRoute(path: '/signup/client/document-selection', builder: (context, state) => const DocumentSelectionScreen()),
    GoRoute(path: '/signup/client/identity-verification', builder: (context, state) => const IdentityVerificationScreen()),
    GoRoute(path: '/signup/client/document-upload', builder: (context, state) => DocumentUploadScreen(
      onDocumentCaptured: (result) => context.push('/signup/client/document-review', extra: result),
    )),
    GoRoute(path: '/signup/client/document-review', builder: (context, state) {
      final result = state.extra as DocumentUploadResult;
      return DocumentReviewScreen(
        result: result,
        onConfirm: () => context.push('/signup/client/selfie-instruction', extra: result),
        onRetry: () => context.pop(),
      );
    }),
    GoRoute(path: '/signup/client/selfie-instruction', builder: (context, state) {
      final result = state.extra as DocumentUploadResult;
      return SelfieInstructionScreen(
        docImageKey: result.frontImageKey ?? '',
        onStart: () => context.push('/signup/client/selfie-capture', extra: result),
      );
    }),
    GoRoute(path: '/signup/client/selfie-capture', builder: (context, state) {
      final result = state.extra as DocumentUploadResult;
      return SelfieCaptureScreen(
        docImageKey: result.frontImageKey ?? '',
        onUpload: (selfiePath) => context.push('/signup/client/verification-processing',
          extra: _SelfieData(selfiePath: selfiePath, docImageKey: result.frontImageKey ?? '', docUploadResult: result)),
        onBack: () => context.pop(),
      );
    }),
    GoRoute(path: '/signup/client/verification-processing', builder: (context, state) {
      final data = state.extra as _SelfieData;
      return VerificationProcessingScreen(
        selfieImagePath: data.selfiePath,
        docImageKey: data.docImageKey,
        docUploadResult: data.docUploadResult,
        onSuccess: () => context.go('/signup/client/verification-success', extra: data.docUploadResult),
        onFailure: () => context.go('/signup/client/verification-failed', extra: data.docUploadResult),
      );
    }),
    GoRoute(path: '/signup/client/verification-success', builder: (context, state) {
      final result = state.extra as DocumentUploadResult;
      return VerificationResultScreen(
        isMatch: true,
        docUploadResult: result,
        onContinue: () => context.go('/signup/client/personal-details', extra: result.ocrResult?.nationality ?? 'Malaysian'),
        onRetry: () => context.go('/signup/client/selfie-instruction', extra: result),
      );
    }),
    GoRoute(path: '/signup/client/verification-failed', builder: (context, state) {
      final result = state.extra as DocumentUploadResult;
      return VerificationResultScreen(
        isMatch: false,
        errorMessage: 'Your selfie does not match your ID photo.',
        docUploadResult: result,
        onContinue: () {},
        onRetry: () => context.go('/signup/client/selfie-instruction', extra: result),
      );
    }),
    GoRoute(path: '/signup/client/personal-details', builder: (context, state) {
      final nationality = state.extra as String? ?? 'Malaysian';
      return PersonalDetailsScreen(nationality: nationality);
    }),
    GoRoute(path: '/signup/client/address-contact', builder: (context, state) {
      return const AddressContactScreen();
    }),
    GoRoute(path: '/signup/client/employment-details', builder: (context, state) {
      return const EmploymentDetailsScreen();
    }),
    GoRoute(path: '/signup/client/kyc-crs', builder: (context, state) {
      return const KycCrsScreen();
    }),
    GoRoute(path: '/signup/client/pep-declaration', builder: (context, state) {
      return const PepDeclarationScreen();
    }),
    GoRoute(path: '/signup/client/onboarding-agreement', builder: (context, state) {
      return const OnboardingAgreementScreen();
    }),
    GoRoute(path: '/signup/client/success', builder: (context, state) {
      return const SignupSuccessScreen();
    }),
    GoRoute(path: '/client/dashboard', builder: (context, state) => const ClientDashboardScreen()),
    GoRoute(path: '/agent/dashboard', builder: (context, state) => const AgentDashboardScreen()),
  ],
);

String _dashboardRoute(String userType) {
  return switch (userType) {
    'AGENT' => '/agent/dashboard',
    _ => '/client/dashboard', // CLIENT and CORPORATE both go to client dashboard
  };
}

/// Data class for passing selfie verification parameters through GoRouter.
class _SelfieData {
  final String selfiePath;
  final String docImageKey;
  final DocumentUploadResult docUploadResult;
  const _SelfieData({required this.selfiePath, required this.docImageKey, required this.docUploadResult});
}