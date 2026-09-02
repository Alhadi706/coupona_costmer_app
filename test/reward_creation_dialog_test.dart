import 'package:coupona_app/widgets/reward_creation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared reward form includes gallery and camera actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showRewardCreationDialog(
                context: context,
                onSave: (_) async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('إضافة جائزة'), findsOneWidget);
    expect(find.text('أين وكيف يتم الاستلام؟'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.text('التقاط صورة بالكاميرا'), findsOneWidget);
    expect(find.text('سحب عشوائي عند انتهاء المدة'), findsOneWidget);
  });
}