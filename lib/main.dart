import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

import 'foundation/app_logger.dart';
import 'screens/login_screen.dart'; // استيراد شاشة تسجيل الدخول
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart'; // استيراد الشاشة الرئيسية
import 'screens/merchant_analytics_screen.dart';
import 'services/app_session.dart';
import 'theme/app_themes.dart';
import 'widgets/app_build_error_view.dart';
import 'widgets/session_route_guard.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error('Flutter framework error', details.exception, details.stack);
      FlutterError.presentError(details);
    };

    // Release builds render a bare grey box on build failures; show a readable
    // recoverable message instead so a single widget error cannot blank a page.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      AppLogger.error('Widget build error', details.exception, details.stack);
      return const AppBuildErrorView();
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger.error('Unhandled platform error', error, stack);
      return true;
    };

    try {
      await EasyLocalization.ensureInitialized().timeout(const Duration(seconds: 3));
    } catch (error, stackTrace) {
      AppLogger.error('Localization initialization failed', error, stackTrace);
    }
    AppLogger.info('Booting in server-only mode.');

    runApp(
      EasyLocalization(
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
          Locale('fr'),
          Locale('es'),
          Locale('tr'),
          Locale('ru'),
          Locale('zh'),
          Locale('de'),
          Locale('it'),
          Locale('pt'),
          Locale('hi'),
          Locale('id'),
          Locale('ja'),
          Locale('ko'),
          Locale('bn'),
          Locale('ur'),
        ],
        path: 'assets/lang',
        fallbackLocale: const Locale('ar'),
        saveLocale: true,
        useOnlyLangCode: true,
        useFallbackTranslations: true,
        child: const MyApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    AppLogger.error('Unhandled zoned error', error, stack);
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<Map<String, dynamic>> _resolveLaunchState() async {
    try {
      // Run independent lookups in parallel instead of sequentially awaiting
      // each one, so a slow/hanging call caps the wait at its own timeout
      // rather than adding up (was up to 3s+2s+2s = 7s worst case).
      final results = await Future.wait<Object?>([
        SharedPreferences.getInstance().timeout(const Duration(seconds: 3)),
        AppSession.token().timeout(const Duration(seconds: 3)),
        AppSession.role().timeout(const Duration(seconds: 3)),
      ]);
      final prefs = results[0] as SharedPreferences;
      final token = results[1] as String?;
      final activeRole = results[2] as String?;
      final shouldShowOnboarding = !(prefs.getBool('onboarding_done') ?? false);
      final hasSession = token != null && token.trim().isNotEmpty;
      return <String, dynamic>{
        'shouldShowOnboarding': shouldShowOnboarding,
        'hasSession': hasSession,
        'activeRole': activeRole,
      };
    } catch (e, st) {
      AppLogger.error('Failed _resolveLaunchState', e, st);
      return <String, dynamic>{
        'shouldShowOnboarding': false,
        'hasSession': false,
        'activeRole': 'customer',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final easy = EasyLocalization.of(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: easy?.locale ?? const Locale('ar'),
      supportedLocales: easy?.supportedLocales ?? const [Locale('ar')],
      localizationsDelegates: easy?.delegates ?? const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: navigatorKey,
      title: 'Coupona App',
      theme: customerTheme,
      darkTheme: adminTheme,
      themeMode: ThemeMode.light,
      routes: {
        '/merchant/analytics': (context) => SessionRouteGuard(
          allowedRoles: const ['merchant'],
          builder: (_) => const MerchantAnalyticsScreen(),
          fallbackBuilder: (_) => LoginPage(),
        ),
      },
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => LoginPage(),
      ),
      home: FutureBuilder<Map<String, dynamic>>(
        future: _resolveLaunchState(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            AppLogger.error('Launch state snapshot error', snapshot.error ?? 'Unknown error', snapshot.stackTrace);
            return LoginPage();
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final state = snapshot.data!;
          final shouldShowOnboarding = state['shouldShowOnboarding'] ?? true;
          final hasSession = state['hasSession'] ?? false;
          final activeRole = (state['activeRole'] ?? 'customer').toString();

          // Rebuild MaterialApp with the role-aware theme once launch state is resolved.
          final roleTheme = themeForRole(activeRole);

          Widget home;
          if (shouldShowOnboarding) {
            home = OnboardingScreen(
              onFinish: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LoginPage()),
              ),
            );
          } else if (!hasSession) {
            home = LoginPage();
          } else {
            home = const MainAppWithFeatures();
          }

          return Theme(
            data: roleTheme,
            child: home,
          );
        },
      ),
    );
  }
}

class MainAppWithFeatures extends StatefulWidget {
  const MainAppWithFeatures({super.key});

  @override
  State<MainAppWithFeatures> createState() => _MainAppWithFeaturesState();
}

class _MainAppWithFeaturesState extends State<MainAppWithFeatures> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    setState(() => _isOffline = false); // اجعلها true لتجربة الشريط
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HomeScreen(
          phone: '0500000000', // مرر بيانات المستخدم الحقيقية هنا
          age: '25',
          gender: 'ذكر',
        ),
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text('offline_no_internet'.tr(), style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }
}

