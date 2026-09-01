import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <({String title, String body})>[
      (
        title: 'البيانات التي يجمعها كوبونا',
        body: 'نجمع بيانات الحساب مثل الاسم والبريد، تاريخ الميلاد، الجنس، الموقع الجغرافي عند السماح به، صور/نصوص الفواتير، سجل الشراء، النقاط، الكوبونات، وتفاعلات الرسائل داخل التطبيق.',
      ),
      (
        title: 'استخدام الموقع الجغرافي',
        body: 'نستخدم موقعك لعرض أقرب العروض والتجار، وقد يُستخدم لتخصيص عروض ترويجية داخل التطبيق. لا نستخدم الموقع لتتبعك خارج كوبونا.',
      ),
      (
        title: 'الفواتير وسجل الشراء',
        body: 'تُستخدم بيانات الفواتير لحساب النقاط، مكافحة الاحتيال، تحليل الولاء، واستهداف عروض داخلية مثل العملاء الأكثر شراءً أو العملاء المنقطعين.',
      ),
      (
        title: 'الاستهداف الداخلي',
        body: 'تُستخدم بيانات الولاء داخل تطبيق كوبونا فقط لإرسال عروض أو كوبونات أو تذاكر سحب مؤهلة. لا نضيف شبكات إعلانات خارجية أو نشارك بياناتك معها دون سياسة وإذن واضحين.',
      ),
      (
        title: 'القرعات والهدايا',
        body: 'أي سحب ترويجي داخل كوبونا مبني على أهلية أو نشاط ولاء سابق. لا حاجة لأي شراء إضافي للمشاركة في السحب.',
      ),
      (
        title: 'حقوقك',
        body: 'يمكنك مراجعة بياناتك داخل التطبيق وطلب تحديثها أو حذفها وفق القنوات الرسمية للدعم.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(section.body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}