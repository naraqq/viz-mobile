import '../config/app_remote_config.dart';

class ApiEndpoints {
  // Dynamic — resolves after AppRemoteConfig.init() runs.
  static String get baseUrl => '${AppRemoteConfig.apiBaseUrl}/api';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String user = '/auth/user';
  static const String googleAuth = '/auth/google';
  static const String appleAuth = '/auth/apple';
  static const String setPassword = '/auth/set-password';
  static const String phoneCheck = '/auth/phone/check';
  static const String phonePinLogin = '/auth/phone/pin';
  static const String phoneRegister = '/auth/phone/register';
  static const String phoneSms = '/auth/phone/sms';
  static const String phoneSmsStatus = '/auth/phone/sms/status';
  static const String phoneSmsComplete = '/auth/phone/sms/complete';
  static const String profilePhoneVerification = '/profile/phone/verification';
  static String profilePhoneVerificationStatus(int id) =>
      '/profile/phone/verification/$id';

  static const String notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';

  static const String config = '/config';
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

  // Short dramas
  static const String dramaHome = '/drama-home';
  static const String dramas = '/dramas';
  static const String feed = '/feed';
  static const String library = '/library';
  static const String coins = '/coins';
  static String episodePlay(int id) => '/episodes/$id/play';
  static String episodeUnlock(int id) => '/episodes/$id/unlock';
  static String dramaSave(int id) => '/dramas/$id/save';
  static String dramaLike(int id) => '/dramas/$id/like';

  static const String qpayCreateInvoice = '/qpay/create-invoice';
  static const String qpayCheckPayment = '/qpay/check-payment';
}
