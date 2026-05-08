import '../config/app_remote_config.dart';

class ApiEndpoints {
  // Dynamic — resolves after AppRemoteConfig.init() runs.
  static String get baseUrl => '${AppRemoteConfig.apiBaseUrl}/api';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String user = '/auth/user';
  static const String googleAuth = '/auth/google';
  static const String setPassword = '/auth/set-password';

  static const String notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';

  static const String home = '/home';
  static const String content = '/content';
  static const String genres = '/genres';

  static const String movies = '/movies';
  static String movieDetail(String slug) => '/movies/$slug';

  static const String shows = '/shows';
  static String showDetail(String slug) => '/shows/$slug';

  static const String plans = '/plans';
  static const String watchProgress = '/watch-progress';
  static const String playerEvents = '/player-events';
  static const String rentals = '/rentals';
  static const String profile = '/profile';

  static const String qpayCreateInvoice = '/qpay/create-invoice';
  static const String qpayCheckPayment = '/qpay/check-payment';
}
