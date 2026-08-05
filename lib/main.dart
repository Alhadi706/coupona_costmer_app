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
import 'services/app_session.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error('Flutter framework error', details.exception, details.stack);
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger.error('Unhandled platform error', error, stack);
      return true;
    };

    await EasyLocalization.ensureInitialized();
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
  Future<Map<String, bool>> _resolveLaunchState() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShowOnboarding = !(prefs.getBool('onboarding_done') ?? false);
    final token = await AppSession.token();
    final hasSession = token != null && token.trim().isNotEmpty;
    return <String, bool>{
      'shouldShowOnboarding': shouldShowOnboarding,
      'hasSession': hasSession,
    };
  }

  @override
  Widget build(BuildContext context) {
    final easy = EasyLocalization.of(context);

    return MaterialApp(
      locale: easy?.locale ?? const Locale('ar'),
      supportedLocales: easy?.supportedLocales ?? const [Locale('ar')],
      localizationsDelegates: easy?.delegates ?? const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: navigatorKey,
      title: 'Coupona App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF181A20),
        cardColor: const Color(0xFF23242B),
        dialogTheme:
            const DialogThemeData(backgroundColor: Color(0xFF23242B)),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF23242B)),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      ),
      themeMode: ThemeMode.system, // دعم الوضع الليلي تلقائي
      home: FutureBuilder<Map<String, bool>>(
        future: _resolveLaunchState(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final state = snapshot.data!;
          final shouldShowOnboarding = state['shouldShowOnboarding'] ?? true;
          final hasSession = state['hasSession'] ?? false;

          if (shouldShowOnboarding) {
            return OnboardingScreen(
              onFinish: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LoginPage()),
              ),
            );
          }

          if (!hasSession) {
            return LoginPage();
          }

          return const MainAppWithFeatures();
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

