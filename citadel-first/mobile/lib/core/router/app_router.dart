import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_bloc.dart';
import '../auth/auth_state.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/bankruptcy_declaration_screen.dart';
import '../../features/auth/disclaimer_screen.dart';
import '../../features/auth/document_selection_screen.dart';
import '../../features/auth/identity_verification_screen.dart';
import '../../features/auth/document_upload_screen.dart';
import '../../features/auth/document_review_screen.dart';
import '../../features/auth/selfie_instruction_screen.dart';
import '../../features/client/dashboard/client_dashboard_screen.dart';
import '../../features/agent/dashboard/agent_dashboard_screen.dart';
import '../../models/document_upload.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final onLogin        = state.matchedLocation == '/login';
    final onSignup       = state.matchedLocation == '/signup';
    final onDeclaration  = state.matchedLocation == '/signup/client/declaration';
    final onDisclaimer   = state.matchedLocation == '/signup/client/disclaimer';
    final onIdentity     = state.matchedLocation == '/signup/client/identity-verification';
    final onDocUpload    = state.matchedLocation == '/signup/client/document-upload';
    final onDocReview    = state.matchedLocation == '/signup/client/document-review';
    final onSelfieInst   = state.matchedLocation == '/signup/client/selfie-instruction';
    final onSignupFlow = onDeclaration || onDisclaimer || onIdentity || onDocUpload || onDocReview || onSelfieInst || state.matchedLocation == '/signup/client/document-selection';

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
        onConfirm: () => context.push('/signup/client/selfie-instruction'),
        onRetry: () => context.pop(),
      );
    }),
    GoRoute(path: '/signup/client/selfie-instruction', builder: (context, state) => SelfieInstructionScreen(
      onStart: () {
        // TODO: navigate to selfie capture screen
      },
    )),
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
