class ApiConstants {
  static const String baseUrl = 'https://taiwanmate-backend-production.up.railway.app/api/v1';

  /// Goc server (khong co /api/v1) — dung cho static file (vd audio Mock
  /// Exam Listening phuc vu qua /static/audio/mock-exam/..., xem main.py
  /// backend), khac han cac route API deu nam duoi /api/v1.
  static const String origin = 'https://taiwanmate-backend-production.up.railway.app';

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  static const String translateText = '/translate/text';
  static const String translateTools = '/translate/tools';

  static const String vocabulary = '/vocabulary';
  static const String vocabularyReview = '/vocabulary/review';

  static const String createCheckout = '/payment/create-checkout';
  static const String paymentStatus = '/payment/status';}
