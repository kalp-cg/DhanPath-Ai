import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dhanpath/screens/monthly_report_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Widget createTestWidget() {
    return const MaterialApp(home: MonthlyReportScreen(autoLoad: false));
  }

  group('MonthlyReportScreen', () {
    testWidgets('renders monthly report screen', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(MonthlyReportScreen), findsOneWidget);
    });

    testWidgets('has refresh button in app bar', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('shows month/year in app bar', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Should show current month name
      final now = DateTime.now();
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final expectedMonth = '${months[now.month - 1]} ${now.year}';
      expect(find.text(expectedMonth), findsOneWidget);
    });
  });
}
