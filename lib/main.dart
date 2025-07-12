import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'services/supabase_invoice_service.dart'; // استيراد خدمة Supabase لحذف العروض

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: context.locale,
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
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;

    if (!onboardingDone) {
      return OnboardingScreen(onFinish: () async {
        await prefs.setBool('onboarding_done', true);
        // Re-run the check to navigate to the correct screen
        setState(() {});
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return LoginPage();
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      return HomeScreen(
        phone: user.email ?? user.phoneNumber ?? '',
        age: userData?['age']?.toString(),
        gender: userData?['gender'] as String?,
      );
    } catch (e) {
      // If there's an error fetching data, fallback to login
      return LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getInitialScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        // Fallback to login page in case of error
        return LoginPage();
      },
    );
  }
}

