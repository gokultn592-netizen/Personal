import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/cache/cache_service.dart';

import 'firebase_options.dart';
import 'core/constants.dart';
import 'core/config/app_config.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/nexus_service.dart';
import 'services/firestore_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/push_notification_service.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_shell.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
  } else {
    await Firebase.initializeApp();
  }
  await Hive.initFlutter();
  await dotenv.load(fileName: '.env');
  await AppConfig.init();
  await CacheService().init();
  await NexusService().initialize();
  await PermissionService().requestNotificationPermission();
  await PushNotificationService.instance.initialize(navKey: navigatorKey);
  runApp(const NexoraApp());
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: NexoraTheme.darkTheme.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _SmoothPageTransitionBuilder(),
              TargetPlatform.fuchsia: _SmoothPageTransitionBuilder(),
            },
          ),
        ),
        home: const AuthGate(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/shell': (_) => const MainShell(),
        },
      ),
    );
  }
}

/// Silky smooth fade + vertical-micro-slide transition.
/// Uses static Animatable chains without instantiating leaky CurvedAnimations on every frame.
class _SmoothPageTransitionBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionBuilder();

  static final Animatable<double> _fadeAnimatable = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).chain(CurveTween(curve: const Interval(0.0, 0.75, curve: Curves.easeOut)));

  static final Animatable<Offset> _slideAnimatable = Tween<Offset>(
    begin: const Offset(0.035, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: _fadeAnimatable.animate(animation),
      child: SlideTransition(
        position: _slideAnimatable.animate(animation),
        child: child,
      ),
    );
  }
}