import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import 'package:printing/printing.dart';

class ExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> exportTransactions({
    required DateTime startDate,
    required DateTime endDate,
    bool isPdf = false,
  }) async {
    final transactions = await _dbHelper.readAllTransactions();
    final filtered = transactions
        .where(
          (t) =>
              t.date.isAfter(startDate) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))),
        )
        .toList();

    if (filtered.isEmpty) {
      throw Exception('No transactions found in the selected range');
    }

    if (isPdf) {
      await _generateAndSharePdf(filtered, startDate, endDate);
    } else {
      await _generateAndShareCsv(filtered);
    }
  }

  Future<void> _generateAndShareCsv(List<Transaction> transactions) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Date',
      'Merchant',
      'Category',
      'Type',
      'Amount',
      'Description',
      'Bank',
      'Account Number',
    ]);

    // Data
    for (var t in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(t.date),
        t.merchantName,
        t.category,
        t.type.toString().split('.').last,
        t.amount,
        t.description,
        t.bankName,
        t.accountNumber,
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/dhanpath_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
    await file.writeAsString(csv);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Here is your DhanPath transaction data');
  }

  Future<void> _generateAndSharePdf(
    List<Transaction> transactions,
    DateTime start,
    DateTime end,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DhanPath Finance Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfSummaryItem(
                    'Total Income',
                    totalIncome,
                    PdfColors.green,
                  ),
                  _buildPdfSummaryItem(
                    'Total Expense',
                    totalExpense,
                    PdfColors.red,
                  ),
                  _buildPdfSummaryItem(
                    'Net Savings',
                    totalIncome - totalExpense,
                    PdfColors.blue,
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),
            pw.Text(
              'Transactions (${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)})',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              headers: ['Date', 'Merchant', 'Category', 'Amount'],
              data: transactions
                  .map(
                    (t) => [
                      DateFormat('dd/MM').format(t.date),
                      t.merchantName,
                      t.category,
                      '${t.type == TransactionType.income ? '+' : '-'}${t.amount.toStringAsFixed(2)}',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {3: pw.Alignment.centerRight},
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/dhanpath_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Here is your DhanPath PDF report');
  }

  pw.Widget _buildPdfSummaryItem(String label, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
        ),
        pw.Text(
          '${amount.toStringAsFixed(0)}',
          style: pw.TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Static method to share CSV directly from detailed list
  static Future<void> shareCSV(List<Transaction> transactions) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Date',
      'Merchant',
      'Category',
      'Type',
      'Amount',
      'Description',
      'Bank',
      'Account Number',
    ]);

    // Data
    for (var t in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(t.date),
        t.merchantName,
        t.category,
        t.type.toString().split('.').last,
        t.amount,
        t.description,
        t.bankName,
        t.accountNumber,
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/dhanpath_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
    );
    await file.writeAsString(csv);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'DhanPath Transaction Export');
  }
}
