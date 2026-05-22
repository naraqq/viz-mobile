import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'app.dart';
import 'core/config/app_remote_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/utils/pending_deep_link.dart';
import 'firebase_options.dart';

const _oneSignalAppId = '9cfdd213-db44-4594-b508-e1b95a96c65c';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Firebase initializes Remote Config; falls back gracefully if not yet configured.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AppRemoteConfig.init();
  } catch (e) {
    debugPrint('[Firebase] init failed — using Remote Config fallback. $e');
    AppRemoteConfig.useFallback(reason: e);
  }

  OneSignal.initialize(_oneSignalAppId);
  OneSignal.Notifications.requestPermission(true);
  OneSignal.Notifications.addClickListener((event) {
    final deepLink =
        event.notification.additionalData?['deep_link'] as String?;
    if (deepLink == null || !deepLink.startsWith('/')) return;

    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) {
      try {
        final container = ProviderScope.containerOf(ctx);
        if (container.read(authProvider).isAuthenticated) {
          GoRouter.of(ctx).push(deepLink);
          return;
        }
      } catch (_) {}
    }
    PendingDeepLink.store(deepLink);
  });

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: VizApp()));
}
