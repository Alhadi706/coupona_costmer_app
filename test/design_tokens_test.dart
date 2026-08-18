import 'package:coupona_app/theme/app_themes.dart';
import 'package:coupona_app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('customerTheme uses customer surface tokens', () {
    expect(customerTheme.scaffoldBackgroundColor, kSand);
    expect(customerTheme.colorScheme.primary, kTeal);
    expect(customerTheme.colorScheme.surface, kWhite);
  });

  test('merchantBrandTheme uses indigo role tokens', () {
    expect(merchantBrandTheme.scaffoldBackgroundColor, kIndigo);
    expect(merchantBrandTheme.colorScheme.surface, kIndigoLight);
    expect(merchantBrandTheme.colorScheme.primary, kIndigo);
  });

  test('adminTheme uses ink dark-mode token', () {
    expect(adminTheme.scaffoldBackgroundColor, kInk);
    expect(adminTheme.brightness, Brightness.dark);
  });

  test('cashierTheme uses violet token', () {
    expect(cashierTheme.scaffoldBackgroundColor, kViolet);
    expect(cashierTheme.colorScheme.primary, kViolet);
  });

  test('role mapping returns expected theme for each role', () {
    expect(themeForRole('customer').scaffoldBackgroundColor, kSand);
    expect(themeForRole('merchant').scaffoldBackgroundColor, kIndigo);
    expect(themeForRole('brand').scaffoldBackgroundColor, kIndigo);
    expect(themeForRole('admin').scaffoldBackgroundColor, kInk);
    expect(themeForRole('cashier').scaffoldBackgroundColor, kViolet);
    expect(themeForRole('unknown').scaffoldBackgroundColor, kSand);
  });
}
