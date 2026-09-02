import 'package:coupona_app/screens/home_screen.dart';
import 'package:coupona_app/screens/my_roles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('Customer role is always shown active in My Roles screen', (tester) async {
    await tester.pumpWidget(
      app(
        MyRolesScreen(
          currentRole: 'customer',
          rolesLoader: () async => <String, dynamic>{
            'customer': true,
            'merchant': false,
            'brand': false,
            'cashier': <dynamic>[],
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('role_customer'), findsOneWidget);
    expect(find.text('role_status_active'), findsWidgets);
  });

  testWidgets('My Roles shows a retry action when loading fails', (tester) async {
    await tester.pumpWidget(
      app(
        MyRolesScreen(
          currentRole: 'customer',
          rolesLoader: () => Future<Map<String, dynamic>>.error('unauthorized'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Customer and merchant mode surfaces are not rendered together', (tester) async {
    await tester.pumpWidget(
      app(
        const HomeScreen(
          phone: '0500000000',
          age: '25',
          gender: 'M',
          initialRoleOverride: 'merchant',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey<String>('merchant_mode_surface')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('customer_mode_surface')), findsNothing);
  });

  testWidgets('Admin role renders admin surface in HomeScreen', (tester) async {
    await tester.pumpWidget(
      app(
        const HomeScreen(
          phone: '0500000000',
          age: '25',
          gender: 'M',
          initialRoleOverride: 'admin',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey<String>('admin_mode_surface')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('customer_mode_surface')), findsNothing);
  });
}
