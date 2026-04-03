import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dhanpath/screens/student_dashboard_screen.dart';
import 'package:dhanpath/providers/student_budget_provider.dart';
import 'package:dhanpath/providers/transaction_provider.dart';

void main() {
  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StudentBudgetProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: const MaterialApp(home: StudentDashboardScreen()),
    );
  }

  group('StudentDashboardScreen', () {
    testWidgets('renders header with student budget label', (tester) async {
      await tester.pumpWidget(createTestWidget());
      // Allow the initial build + provider to load
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('STUDENT BUDGET'), findsOneWidget);
    });

    testWidgets('shows quick actions section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.text('Quick Expense'), findsWidgets); // appears in card + FAB
      expect(find.text('Set Budget'), findsOneWidget);
    });

    testWidgets('shows spending by category header', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SPENDING BY CATEGORY'), findsOneWidget);
    });

    testWidgets('shows budget overview card', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Monthly Budget'), findsOneWidget);
    });

    testWidgets('shows stat chips', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Daily Avg'), findsOneWidget);
      expect(find.text('Safe to Spend'), findsOneWidget);
      expect(find.text('Top Spend'), findsOneWidget);
    });

    testWidgets('shows empty state when no transactions', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No expenses yet this month'), findsOneWidget);
    });

    testWidgets('has floating action button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
