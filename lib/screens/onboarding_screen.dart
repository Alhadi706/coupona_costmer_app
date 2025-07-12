import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'مرحبًا بك في كوبونا!',
      'desc': 'كل كوبون، كل عرض، كل نقاطك في مكان واحد. استمتع بتجربة تسوق ذكية ومكافآت حقيقية.'
    },
    {
      'title': 'اجمع النقاط بسهولة',
      'desc': 'امسح فواتيرك، استخدم كوبوناتك، وادعُ أصدقاءك لتحصل على المزيد من النقاط.'
    },
    {
      'title': 'جوائز وعروض حصرية',
      'desc': 'استبدل نقاطك بجوائز حقيقية، وكن أول من يعرف عن العروض الجديدة.'
    },
  ];

  void _playClickSound() {
    if (!kIsWeb) {
      FlutterRingtonePlayer().playNotification();
    }
  }

  void _playSuccessSound() {
    if (!kIsWeb) {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.triTone,
        volume: 0.8,
        looping: false,
        asAlarm: false,
      );
    }
  }

  void _finishOnboarding() async {
    _playSuccessSound();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration, size: 80, color: Colors.blue.shade700),
                      const SizedBox(height: 32),
                      Text(_pages[i]['title']!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(_pages[i]['desc']!, style: const TextStyle(fontSize: 18, color: Colors.blueGrey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                width: _currentPage == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? Colors.blue : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
              )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                children: [
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: () {
                        _playClickSound();
                        _finishOnboarding();
                      },
                      child: const Text('تخطي'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _currentPage == _pages.length - 1
                        ? () {
                            _playSuccessSound();
                            _finishOnboarding();
                          }
                        : () {
                            _playClickSound();
                            _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.ease);
                          },
                    child: Text(_currentPage == _pages.length - 1 ? 'ابدأ' : 'التالي'),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
