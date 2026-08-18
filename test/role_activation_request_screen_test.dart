import 'package:coupona_app/screens/role_activation_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) {
    return MaterialApp(home: child);
  }

  Future<Map<String, dynamic>> successSubmitter({
    required String businessName,
    required String commercialRegistration,
    required String planType,
    required String phone,
    required double locationLat,
    required double locationLng,
    String? locationAddress,
  }) async {
    return <String, dynamic>{'ok': true};
  }

  testWidgets('Does not submit merchant request when location is missing', (tester) async {
    var submitCalls = 0;

    await tester.pumpWidget(
      app(
        RoleActivationRequestScreen(
          roleType: 'merchant',
          merchantSubmitter: ({
            required String businessName,
            required String commercialRegistration,
            required String planType,
            required String phone,
            required double locationLat,
            required double locationLng,
            String? locationAddress,
          }) async {
            submitCalls += 1;
            return successSubmitter(
              businessName: businessName,
              commercialRegistration: commercialRegistration,
              planType: planType,
              phone: phone,
              locationLat: locationLat,
              locationLng: locationLng,
              locationAddress: locationAddress,
            );
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Store One');
    await tester.enterText(find.byType(TextFormField).at(1), 'CR-123');
    await tester.enterText(find.byType(TextFormField).at(2), '0911111111');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(submitCalls, 0);
  });

  testWidgets('Submits merchant request when required fields are complete', (tester) async {
    var submitCalls = 0;

    await tester.pumpWidget(
      app(
        RoleActivationRequestScreen(
          roleType: 'merchant',
          initialPickedLocation: const LatLng(32.88, 13.19),
          merchantSubmitter: ({
            required String businessName,
            required String commercialRegistration,
            required String planType,
            required String phone,
            required double locationLat,
            required double locationLng,
            String? locationAddress,
          }) async {
            submitCalls += 1;
            return successSubmitter(
              businessName: businessName,
              commercialRegistration: commercialRegistration,
              planType: planType,
              phone: phone,
              locationLat: locationLat,
              locationLng: locationLng,
              locationAddress: locationAddress,
            );
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Store One');
    await tester.enterText(find.byType(TextFormField).at(1), 'CR-123');
    await tester.enterText(find.byType(TextFormField).at(2), '0911111111');
    await tester.enterText(find.byType(TextFormField).at(3), 'Tripoli');

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(submitCalls, 1);
  });
}
