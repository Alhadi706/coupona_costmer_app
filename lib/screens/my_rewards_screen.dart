import 'package:flutter/material.dart';

class MyRewardsScreen extends StatefulWidget {
  const MyRewardsScreen({super.key});

  @override
  State<MyRewardsScreen> createState() => _MyRewardsScreenState();
}

class _MyRewardsScreenState extends State<MyRewardsScreen> {
  // بيانات تجريبية للنقاط والجوائز
  int totalPoints = 1250;
  int nextPrizePoints = 1500;
  List<Map<String, dynamic>> prizes = [
    {
      'image': 'https://via.placeholder.com/80x80.png?text=Prize+1',
      'name': 'قسيمة شراء 10 دينار',
      'requiredPoints': 1000,
      'earned': true,
    },
    {
      'image': 'https://via.placeholder.com/80x80.png?text=Prize+2',
      'name': 'هدية من محل الذواقة',
      'requiredPoints': 1500,
      'earned': false,
    },
    {
      'image': 'https://via.placeholder.com/80x80.png?text=Prize+3',
      'name': 'قسيمة خصم 20%',
      'requiredPoints': 2000,
      'earned': false,
    },
  ];
  List<Map<String, dynamic>> pointsHistory = [
    {
      'date': '2025-06-01',
      'amount': 200,
      'source': 'شراء من مطعم الذواقة',
      'balance': 1250,
    },
    {
      'date': '2025-05-28',
      'amount': 300,
      'source': 'تحميل كوبون',
      'balance': 1050,
    },
    {
      'date': '2025-05-20',
      'amount': 500,
      'source': 'شراء من محل النخبة',
      'balance': 750,
    },
  ];

  @override
  Widget build(BuildContext context) {
    double progress = totalPoints / nextPrizePoints;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مكافآتي', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عدد النقاط الحالي
            Center(
              child: Column(
                children: [
                  const Text('رصيد نقاطك', style: TextStyle(fontSize: 20, color: Colors.deepPurple)),
                  Text('$totalPoints', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress > 1 ? 1 : progress,
                    minHeight: 10,
                    backgroundColor: Colors.deepPurple.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                  const SizedBox(height: 4),
                  Text('تحتاج ${nextPrizePoints - totalPoints} نقطة لتحصل على الجائزة القادمة', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // زر زيد أرباحي (مكان بارز أعلى الجوائز)
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('كيف تزيد نقاطك؟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 12),
                          Text('1. الشراء من المحلات المشاركة: كل فاتورة تمنحك نقاط حسب سياسة المحل.'),
                          SizedBox(height: 8),
                          Text('2. استخدام كوبونات: عند استخدام كوبونك من قبل مستخدم آخر تحصل على نقاط.'),
                          SizedBox(height: 8),
                          Text('3. تحميل عروض من المحلات غير النشيطة: تحصل على نقاط رمزية كمكافأة.'),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.trending_up, color: Colors.white),
                label: const Text('زيد أرباحي', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // الجوائز القريبة والممكنة
            const Text('الجوائز المتاحة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 180, // زيادة الارتفاع لحل مشكلة overflow
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: prizes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final prize = prizes[i];
                  return Card(
                    color: prize['earned'] ? Colors.green.shade100 : Colors.white,
                    child: Container(
                      width: 130,
                      height: 170,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Image.network(prize['image'], width: 56, height: 56),
                          const SizedBox(height: 8),
                          Text(prize['name'], style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text('النقاط: ${prize['requiredPoints']}', style: const TextStyle(fontSize: 12, color: Colors.deepPurple)),
                          const Spacer(),
                          if (prize['earned'])
                            ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text('استلام الجائزة'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('يرجى إبراز رمز QR للكاشير لمسحه واستلام جائزتك'),
                                        const SizedBox(height: 16),
                                        Container(
                                          width: 160,
                                          height: 160,
                                          color: Colors.grey.shade200,
                                          alignment: Alignment.center,
                                          child: Text('QR CODE\n#${prize['name']}', textAlign: TextAlign.center),
                                        ),
                                        const SizedBox(height: 12),
                                        Text('بعد المسح سيتم خصم النقاط واستلام الجائزة تلقائياً'),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('إغلاق'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text('استلم الجائزة', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                minimumSize: Size(90, 32),
                                foregroundColor: Colors.white, // تأكيد وضوح النص
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            OutlinedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text('تفاصيل الجائزة'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('اسم الجائزة: ${prize['name']}'),
                                        Text('النقاط المطلوبة: ${prize['requiredPoints']}'),
                                        const SizedBox(height: 8),
                                        Text('اجمع المزيد من النقاط للحصول على هذه الجائزة!'),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('إغلاق'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text('تفاصيل'),
                              style: OutlinedButton.styleFrom(minimumSize: Size(90, 32)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // سجل النقاط
            const Text('سجل النقاط', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DataTable(
              columns: const [
                DataColumn(label: Text('التاريخ')),
                DataColumn(label: Text('الكمية')),
                DataColumn(label: Text('المصدر')),
                DataColumn(label: Text('الرصيد')),
              ],
              rows: pointsHistory.map((row) => DataRow(cells: [
                DataCell(Text(row['date'])),
                DataCell(Text(row['amount'].toString())),
                DataCell(Text(row['source'])),
                DataCell(Text(row['balance'].toString())),
              ])).toList(),
            ),
            const SizedBox(height: 24),
            // تنبيه انتهاء صلاحية النقاط
            if (totalPoints > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(child: Text('تنبيه: بعض نقاطك ستنتهي صلاحيتها قريباً!')),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // خريطة مصغرة (مكان المحلات)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text('خريطة المحلات المشاركة (تجريبية)')),
            ),
            const SizedBox(height: 24),
            // رسم بياني مبسط (تجريبي)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text('رسم بياني لتطور النقاط (تجريبي)')),
            ),
          ],
        ),
      ),
    );
  }
}

