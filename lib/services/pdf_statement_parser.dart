import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/transaction_model.dart';
import 'database_helper.dart';

class PdfStatementParser {
  static final PdfStatementParser _instance = PdfStatementParser._internal();
  factory PdfStatementParser() => _instance;
  PdfStatementParser._internal();

  /// Parses an offline PDF bank statement and inserts unique transactions.
  Future<int> parseAndImportStatement(String filePath, String bankName) async {
    int insertedCount = 0;
    try {
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();

      if (extractedText.trim().isEmpty) {
        debugPrint(
          'PDF import skipped: no selectable text found. This parser currently supports text-based PDFs only.',
        );
        return 0;
      }

      final List<Transaction> transactions = extractTransactionsFromText(extractedText, bankName);

      for (var txn in transactions) {
        try {
          final db = await DatabaseHelper.instance.database;
          
          final existingList = await db.query(
            'transactions',
            where: 'transaction_hash = ?',
            whereArgs: [txn.transactionHash],
            limit: 1,
          );

          if (existingList.isEmpty) {
            await db.insert('transactions', txn.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
            insertedCount++;
          }
        } catch (e) {
          debugPrint("Error inserting transaction: $e");
        }
      }

      return insertedCount;
    } catch (e) {
      debugPrint("Error reading PDF: $e");
      return 0;
    }
  }

  /// Routes to the correct highly-tuned parser for each bank format.
  /// Public so unit tests can verify parser logic directly with raw text.
  List<Transaction> extractTransactionsFromText(String rawText, String bankName) {
    if (bankName == 'SBI') {
      return _extractSbiStateful(rawText, bankName);
    } else {
      // HDFC & Defaults to universal regex
      return _extractHdfcRegex(rawText, bankName);
    }
  }

  /// State-Machine Parser specifically designed for SBI's multi-line extracted cells
  List<Transaction> _extractSbiStateful(String rawText, String bankName) {
    final List<Transaction> results = [];
    final lines = rawText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    DateTime? currentTxnDate;
    List<String> currentDescLines = [];
    List<double> currentNumbers = [];

    // SBI dates often appear at start of a row: "21 Mar 2026 ..."
    // OCR/table extraction may keep date+description+amount on one line.
    final dateAtStartRegex = RegExp(
      r'^(\d{1,2})[-/\s]+([A-Za-z]{3})[-/\s]*(\d{2,4})(?:\s+(.*))?$',
    );
    final amountRegex = RegExp(r'(?<![\d,])([\d,]+\.\d{2})(?!\d)');

    void flushTxn() {
      if (currentTxnDate != null && currentNumbers.isNotEmpty) {
        final DateTime txnDate = currentTxnDate;
        double balance = currentNumbers.last;
        double amount = currentNumbers.length > 1 ? currentNumbers[currentNumbers.length - 2] : currentNumbers.first;

        final fullDesc = currentDescLines.join(' ').trim();
        if (fullDesc.isNotEmpty) {
          final TransactionType type = _inferSbiType(fullDesc);

          String merchantName = fullDesc;
          if (fullDesc.contains('UPI/DR/') || fullDesc.contains('UPI/CR/')) {
             final parts = fullDesc.split('/');
             if (parts.length >= 4) {
               merchantName = parts[3].trim(); 
             }
          }
          if (merchantName.length > 30) merchantName = merchantName.substring(0, 30);

          String category = "Other";
          final mLower = merchantName.toLowerCase();
          if (mLower.contains("zomato") || mLower.contains("swiggy")) {
            category = "Food";
          } else if (mLower.contains("amazon") || mLower.contains("flipkart")) {
            category = "Shopping";
          } else {
            category = type == TransactionType.income ? "Income" : "Transfer";
          }

            final rawHashData =
              "$bankName|${txnDate.toIso8601String().substring(0, 10)}|$amount|$fullDesc|$balance";
          final hash = sha256.convert(utf8.encode(rawHashData)).toString().substring(0, 16);

          results.add(Transaction(
            amount: amount,
            merchantName: merchantName.isEmpty ? "Unknown" : merchantName,
            category: category,
            type: type,
            date: txnDate,
            balance: balance,
            description: fullDesc,
            bankName: bankName,
            transactionHash: hash,
            isFromCard: false,
            currency: "INR",
          ));
        }
      }
    }

    for (var line in lines) {
      final dateMatch = dateAtStartRegex.firstMatch(line);
      if (dateMatch != null) {
        if (currentTxnDate != null && currentNumbers.isNotEmpty) {
          flushTxn();
          currentTxnDate = null;
          currentDescLines = [];
          currentNumbers = [];
        }
        
        if (currentTxnDate == null) {
          int day = int.parse(dateMatch.group(1)!);
          int year = int.parse(dateMatch.group(3)!);
          if (year < 100) year += 2000;
          
          int month = 1;
          switch (dateMatch.group(2)!.toLowerCase()) {
            case 'jan': month = 1; break;
            case 'feb': month = 2; break;
            case 'mar': month = 3; break;
            case 'apr': month = 4; break;
            case 'may': month = 5; break;
            case 'jun': month = 6; break;
            case 'jul': month = 7; break;
            case 'aug': month = 8; break;
            case 'sep': month = 9; break;
            case 'oct': month = 10; break;
            case 'nov': month = 11; break;
            case 'dec': month = 12; break;
          }
          currentTxnDate = DateTime(year, month, day);

          final trailingContent = dateMatch.group(4)?.trim();
          if (trailingContent != null && trailingContent.isNotEmpty) {
            // Capture numeric values from the same row when OCR keeps full transaction in one line
            for (final match in amountRegex.allMatches(trailingContent)) {
              currentNumbers.add(double.parse(match.group(1)!.replaceAll(',', '')));
            }

            final descWithoutAmounts = trailingContent
                .replaceAll(amountRegex, ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

            if (descWithoutAmounts.isNotEmpty) {
              currentDescLines.add(descWithoutAmounts);
            }
          }
        }
        continue;
      }

      final numMatch = RegExp(r'^([\d,]+)\.\d{2}$').firstMatch(line);
      if (numMatch != null && currentTxnDate != null) {
        currentNumbers.add(double.parse(line.replaceAll(',', '')));
        continue;
      }

      if (currentTxnDate != null) {
        currentDescLines.add(line);
      }
    }
    
    if (currentTxnDate != null && currentNumbers.isNotEmpty) {
      flushTxn();
    }

    return results;
  }

  TransactionType _inferSbiType(String description) {
    final normalized = description.toUpperCase();

    // Explicit DR/CR indicators are the most reliable for statement rows.
    if (normalized.contains('UPI/DR/') ||
        normalized.contains(' DEBIT ') ||
        normalized.contains(' DEBITED ') ||
        normalized.contains(' WITHDRAW ') ||
        normalized.contains(' WITHDRAWN ') ||
        normalized.contains(' SPENT ')) {
      return TransactionType.expense;
    }

    if (normalized.contains('UPI/CR/') ||
        normalized.contains(' CREDIT ') ||
        normalized.contains(' CREDITED ') ||
        normalized.contains(' DEPOSIT ') ||
        normalized.contains(' REFUND ') ||
        normalized.contains(' SALARY ')) {
      return TransactionType.income;
    }

    return TransactionType.expense;
  }

  /// Single-line Regex Parser for HDFC format
  List<Transaction> _extractHdfcRegex(String rawText, String bankName) {
    final List<Transaction> results = [];
    final lines = rawText.split('\n');
    
    final RegExp universalRowRegex = RegExp(
      r'^(\d{1,2}[-/\s]+[A-Za-z0-9]{2,4}[-/\s]+\d{2,4})\s+(?:(\d{1,2}[-/\s]+[A-Za-z0-9]{2,4}[-/\s]+\d{2,4})\s+)?(.+?)\s+([\d,]+\.\d{2})\s+([\d,]+\.\d{2})\s*$'
    );

    for (var line in lines) {
      final match = universalRowRegex.firstMatch(line.trim());
      if (match != null) {
        final dateStr = match.group(1)!;
        final descriptionAndRef = match.group(3)!; 
        
        final amountStr = match.group(4)!.replaceAll(',', '');
        final balanceStr = match.group(5)!.replaceAll(',', '');
        
        final double amount = double.tryParse(amountStr) ?? 0.0;
        final double balance = double.tryParse(balanceStr) ?? 0.0;
        
        TransactionType type = TransactionType.expense;
        if (descriptionAndRef.contains('UPI/CR') || descriptionAndRef.contains('BY LNS') || descriptionAndRef.contains('CREDIT')) {
          type = TransactionType.income;
        }

        String merchantName = descriptionAndRef;
        if (descriptionAndRef.contains('UPI/DR/') || descriptionAndRef.contains('UPI/CR/')) {
           final parts = descriptionAndRef.split('/');
           if (parts.length >= 4) {
             merchantName = parts[3].trim(); 
           }
        }
        if (merchantName.length > 30) merchantName = merchantName.substring(0, 30);

        String category = "Other";
        final mLower = merchantName.toLowerCase();
        if (mLower.contains("zomato") || mLower.contains("swiggy")) {
          category = "Food";
        } else if (mLower.contains("amazon") || mLower.contains("flipkart")) {
          category = "Shopping";
        } else {
          category = type == TransactionType.income ? "Income" : "Transfer";
        }

        final DateTime parsedDate = _parseAnyDate(dateStr) ?? DateTime.now();

        final rawHashData =
          "$bankName|${parsedDate.toIso8601String().substring(0, 10)}|$amountStr|$descriptionAndRef|$balanceStr";
        final String hash = sha256.convert(utf8.encode(rawHashData)).toString().substring(0, 16);

        results.add(Transaction(
          amount: amount,
          merchantName: merchantName,
          category: category,
          type: type,
          date: parsedDate,
          balance: balance,
          description: descriptionAndRef, 
          bankName: bankName,
          transactionHash: hash,
          isFromCard: false,
          currency: "INR"
        ));
      }
    }
    return results;
  }

  DateTime? _parseAnyDate(String dateStr) {
    final cleanStr = dateStr.trim().replaceAll(RegExp(r'[-/]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    final parts = cleanStr.split(' ');
    if (parts.length != 3) return null;
    
    int day = int.tryParse(parts[0]) ?? 1;
    int year = int.tryParse(parts[2]) ?? 2025;
    if (year < 100) year += 2000; 
    
    int month = 1;
    if (int.tryParse(parts[1]) != null) {
      month = int.parse(parts[1]); 
    } else {
      switch (parts[1].toLowerCase().substring(0, 3)) {
        case 'jan': month = 1; break;
        case 'feb': month = 2; break;
        case 'mar': month = 3; break;
        case 'apr': month = 4; break;
        case 'may': month = 5; break;
        case 'jun': month = 6; break;
        case 'jul': month = 7; break;
        case 'aug': month = 8; break;
        case 'sep': month = 9; break;
        case 'oct': month = 10; break;
        case 'nov': month = 11; break;
        case 'dec': month = 12; break;
      }
    }
    return DateTime(year, month, day);
  }
}
