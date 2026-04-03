// DhanPath App - Smoke Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dhanpath/providers/transaction_provider.dart';
import 'package:dhanpath/providers/theme_provider.dart';
import 'package:dhanpath/providers/student_budget_provider.dart';
import 'package:dhanpath/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => StudentBudgetProvider()),
        ],
        child: const DhanPathApp(),
      ),
    );
    await tester.pump();
    // App should render without throwing
    expect(find.byType(MaterialApp), findsOneWidget);
    // Should show splash screen initially
    expect(find.text('DhanPath'), findsOneWidget);
  });

  testWidgets('App has scaffold structure', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => StudentBudgetProvider()),
        ],
        child: const DhanPathApp(),
      ),
    );
    await tester.pump();
    // Should find a Scaffold (splash screen has scaffold)
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
