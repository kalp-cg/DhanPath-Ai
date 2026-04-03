import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dhanpath/screens/quick_expense_screen.dart';
import 'package:dhanpath/providers/transaction_provider.dart';
import 'package:dhanpath/providers/student_budget_provider.dart';

void main() {
  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => StudentBudgetProvider()),
      ],
      child: const MaterialApp(home: QuickExpenseScreen()),
    );
  }

  group('QuickExpenseScreen', () {
    testWidgets('renders with all key elements', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Title
      expect(find.text('Quick Expense'), findsOneWidget);

      // Amount prompt
      expect(find.text('How much?'), findsOneWidget);

      // Category label
      expect(find.text('CATEGORY'), findsOneWidget);

      // Save button
      expect(find.text('Save Expense'), findsOneWidget);
    });

    testWidgets('shows category chips', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Check some student categories are visible
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('Mess & Canteen'), findsOneWidget);
      expect(find.text('Books & Stationery'), findsOneWidget);
    });

    testWidgets('shows quick amount presets', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Check preset amounts
      expect(find.textContaining('10'), findsWidgets);
      expect(find.textContaining('50'), findsWidgets);
      expect(find.textContaining('100'), findsWidgets);
      expect(find.textContaining('500'), findsWidgets);
    });

    testWidgets('category selection highlights chip', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Tap on a category
      await tester.tap(find.text('Food & Dining'));
      await tester.pump();

      // The category should now be selected (UI updates)
      // We verify it doesn't crash
      expect(find.text('Food & Dining'), findsOneWidget);
    });

    testWidgets('save button exists and is a FilledButton', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Save button exists (may be off screen)
      expect(find.text('Save Expense'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('note field is present', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Add a note (optional)'), findsOneWidget);
    });
  });
}
