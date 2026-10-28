import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_health_monitor/l10n/app_localizations.dart';
import 'package:smart_health_monitor/main.dart';
import 'package:smart_health_monitor/pages/home.dart';

void main() {
  testWidgets('home page renders app title and menus', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MyHomePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RESPIRA'), findsOneWidget);
    expect(find.text('Diagnose'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('BMI Calculator'), findsOneWidget);
    expect(find.text('Healthy Living'), findsOneWidget);
  });
}
