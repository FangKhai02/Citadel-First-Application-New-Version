class ApiEndpoints {
  // static const String baseUrl = 'http://localhost:8000/api/v1'; // adb reverse tcp:8000 tcp:8000
  static const String baseUrl = 'http://88.88.1.22:8000/api/v1'; // Physical device → host machine IP (company wifi)

  // Auth
  static const String login    = '/auth/login';
  static const String register = '/auth/register';
  static const String adminLogin = '/auth/admin/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Users
  static const String me = '/users/me';

  // Signup flow
  static const String bankruptcyDeclaration = '/signup/bankruptcy-declaration';
  static const String disclaimerAcceptance  = '/signup/disclaimer-acceptance';
  static const String trustFormB6           = '/signup/trust-form-b6';
  static String trustFormB6Pdf(int id)      => '/signup/trust-form-b6/$id/pdf';

  // Identity document
  static const String presignedUrl = '/signup/presigned-url';
  static const String identityDocument = '/signup/identity-document';
  static const String ocr = '/signup/ocr';
}
