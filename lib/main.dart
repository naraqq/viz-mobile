import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'app.dart';
import 'core/config/app_remote_config.dart';
import 'firebase_options.dart';

const _oneSignalAppId = '9cfdd213-db44-4594-b508-e1b95a96c65c';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
