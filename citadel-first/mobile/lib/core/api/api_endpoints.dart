import 'environment_config.dart';

class ApiEndpoints {
  static String get baseUrl => EnvironmentConfig.baseUrl;

  // Auth
  static const String login    = '/auth/login';
  static const String register = '/auth/register';
  static const String adminLogin = '/auth/admin/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Users
  static const String me = '/users/me';
  static const String userMeDetails = '/users/me/details';

  // Signup flow
  static const String bankruptcyDeclaration = '/signup/bankruptcy-declaration';
  static const String disclaimerAcceptance  = '/signup/disclaimer-acceptance';

  // Identity document
  static const String presignedUrl = '/signup/presigned-url';
  static const String identityDocument = '/signup/identity-document';
  static const String ocr = '/signup/ocr';

  // Face verification (eKYC)
  static const String selfiePresignedUrl = '/signup/selfie-presigned-url';
  static const String faceVerify = '/signup/face-verify';
  static const String faceDetect = '/signup/face-detect';

  // Post-eKYC information capture
  static const String personalDetails = '/signup/personal-details';
  static const String addressContact = '/signup/address-contact';
  static const String employmentDetails = '/signup/employment-details';
  static const String kycCrs = '/signup/kyc-crs';
  static const String crsTaxResidency = '/signup/crs-tax-residency';
  static const String pepDeclaration = '/signup/pep-declaration';

  // Onboarding agreement (E-Sign)
  static const String signupUserDetails = '/signup/user-details';
  static const String onboardingAgreement = '/signup/onboarding-agreement';

  // Auth
  static const String incompleteSignup = '/auth/incomplete-signup';
  static const String resendVerification = '/auth/resend-verification';

  // Beneficiaries
  static const String beneficiaries = '/signup/beneficiaries';
  static const String beneficiaryPresignedUrl = '/signup/beneficiaries/presigned-url';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationReadAll = '/notifications/read-all';

  // Trust Orders
  static const String trustOrders = '/trust-orders';
  static const String trustOrderMe = '/trust-orders/me';
  static const String trustOrderPresignedUrl = '/trust-orders/presigned-url';
  static const String trustProductCwdDeckUrl = '/trust-orders/products/cwd-deck-url';
}