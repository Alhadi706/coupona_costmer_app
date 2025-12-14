import 'package:flutter/material.dart';

class MerchantLoyaltyRulesScreen extends StatelessWidget {
  final String merchantId;
  const MerchantLoyaltyRulesScreen({Key? key, required this.merchantId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قواعد نقاط الولاء'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, size: 64, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text(
                'هنا ستظهر قواعد نقاط الولاء الخاصة بهذا التاجر.\nيمكنك مراجعة إعدادات النقاط من شاشة الإعدادات.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              Text('Merchant ID: $merchantId', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
