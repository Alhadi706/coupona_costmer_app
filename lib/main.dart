import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'screens/login_screen.dart'; // استيراد شاشة تسجيل الدخول
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart'; // استيراد الشاشة الرئيسية
import 'screens/language_selection_screen.dart';
import 'screens/role_selection_screen.dart';
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
<<<<<<< HEAD
  Future<bool> _shouldShowOnboarding() async {
=======
  String? _languageSelected;
  bool? _showOnboarding;
  bool _onboardingDone = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
>>>>>>> 39ebec2 (نسخة نهائية: إصلاح التنقل من شاشة البداية إلى شاشة اختيار الدور)
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_language_code');
    final onboarding = prefs.getBool('onboarding_done') ?? false;
    setState(() {
      _languageSelected = lang;
      _showOnboarding = !onboarding;
      _onboardingDone = onboarding;
    });
  }

  Future<void> _handleLanguageSelected() async {
    setState(() => _languageSelected = 'done');
  }

<<<<<<< HEAD
  // زر مؤقت لإضافة فاتورة وهمية
  void _addTestInvoice() async {
  await SupabaseInvoiceService.addInvoice(
      invoiceNumber: 'INV-2025-TEST-002',
      storeName: 'الشعاب',
      date: DateTime.parse('2025-07-09'),
      products: [
        {'name': 'لميس', 'quantity': 2, 'unit_price': 8, 'total_price': 16},
        {'name': 'توري', 'quantity': 1, 'unit_price': 5, 'total_price': 5},
        {'name': 'زبادي النسيم', 'quantity': 3, 'unit_price': 2, 'total_price': 6},
        {'name': 'حفاظات ليلاس', 'quantity': 1, 'unit_price': 25, 'total_price': 25},
        {'name': 'تن الجيد', 'quantity': 2, 'unit_price': 7, 'total_price': 14},
        {'name': 'عصير الريحان', 'quantity': 4, 'unit_price': 1.5, 'total_price': 6},
        {'name': 'عصير المزرعة', 'quantity': 2, 'unit_price': 2, 'total_price': 4},
        {'name': 'مكرونة اللمة', 'quantity': 5, 'unit_price': 1, 'total_price': 5},
        {'name': 'أزر المبروك', 'quantity': 1, 'unit_price': 18, 'total_price': 18},
        {'name': 'طماطم الصفوة', 'quantity': 3, 'unit_price': 3, 'total_price': 9},
      ],
      total: 108,
      userId: 'user_test_1', // ضع هنا user_id حقيقي أو تجريبي
      merchantId: 'your-merchant-uuid-here',
      uniqueHash: 'test-hash-002',
  merchantCode: 'TRPCF2',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الفاتورة التجريبية بنجاح!')),
      );
    }
=======
  Future<void> _handleOnboardingFinish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    setState(() {
>>>>>>> 39ebec2 (نسخة نهائية: إصلاح التنقل من شاشة البداية إلى شاشة اختيار الدور)
  }

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
<<<<<<< HEAD
      themeMode: ThemeMode.system, // دعم الوضع الليلي تلقائي
      home: FutureBuilder<bool>(
        future: _shouldShowOnboarding(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.data == true) {
            return OnboardingScreen(onFinish: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LoginPage()),
              );
            });
          }
          return Stack(
            children: [
              LoginPage(),
              Positioned(
                bottom: 40,
                right: 20,
                child: FloatingActionButton.extended(
                  onPressed: _addTestInvoice,
                  label: const Text('فاتورة تجريبية'),
                  icon: const Icon(Icons.receipt_long),
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
          );
        },
      ),
=======
      themeMode: ThemeMode.system,
      home: _languageSelected == null
          ? LanguageSelectionScreen()
          : (_showOnboarding ?? true)
              ? OnboardingScreen(onFinish: _handleOnboardingFinish)
              : (_onboardingDone ? RoleSelectionScreen() : const Scaffold(body: Center(child: CircularProgressIndicator()))),
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

