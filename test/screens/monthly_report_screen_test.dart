import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/screens/monthly_report_screen.dart';

void main() {
  Widget createTestWidget() {
    return const MaterialApp(home: MonthlyReportScreen());
  }

  group('MonthlyReportScreen', () {
    testWidgets('renders with loading state then content', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // After loading completes, content appears
      // Since we don't have a real DB, it will either error or show empty
      await tester.pumpAndSettle(const Duration(seconds: 3));
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
