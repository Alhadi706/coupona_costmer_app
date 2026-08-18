import 'package:coupona_app/screens/report_issue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('report issue screen renders three quick report actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportIssueScreen(),
      ),
    );

    expect(find.byType(ElevatedButton), findsNWidgets(3));
  });
}
