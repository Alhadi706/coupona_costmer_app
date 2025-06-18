import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'screens/login_screen.dart'; // استيراد شاشة تسجيل الدخول
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart'; // استيراد الشاشة الرئيسية
import 'firebase_options.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SupabaseService.init();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en'), Locale('fr'), Locale('es'), Locale('tr'), Locale('ru'), Locale('zh')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: const MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<bool> _shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_done') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: context.locale, // استخدم locale من easy_localization
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
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
        dialogBackgroundColor: const Color(0xFF23242B),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF23242B)),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      ),
      themeMode: ThemeMode.system, // دعم الوضع الليلي تلقائي
      home: FutureBuilder<bool>(
        future: _shouldShowOnboarding(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data == true) {
            return OnboardingScreen(
              onFinish: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LoginPage()),
              ),
            );
          }
          return MainAppWithFeatures();
        },
      ),
    );
  }
}

class MainAppWithFeatures extends StatefulWidget {
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
              child: const Center(
                child: Text('لا يوجد اتصال بالإنترنت', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }
}

