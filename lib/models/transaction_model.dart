import 'dart:convert';
import 'package:crypto/crypto.dart';

enum TransactionType {
  income,
  expense,
  credit,
  transfer,
  investment,
  balance_update,
}

class Transaction {
  final int? id;
  final double amount;
  final String merchantName;
  final String category;
  final TransactionType type;
  final DateTime date;
  final String? description;
  final String? smsBody;
  final String? bankName;
  final String? accountNumber;
  final bool isRecurring;
  final bool isDeleted;
  final String? reference;
  final double? balance;
  final double? creditLimit;
  final bool isFromCard;
  final String currency;
  final String? fromAccount;
  final String? toAccount;
  final String? transactionHash;

  Transaction({
    this.id,
    required this.amount,
    required this.merchantName,
    required this.category,
    required this.type,
    required this.date,
    this.description,
    this.smsBody,
    this.bankName,
    this.accountNumber,
    this.isRecurring = false,
    this.isDeleted = false,
    this.reference,
    this.balance,
    this.creditLimit,
    this.isFromCard = false,
    this.currency = "INR",
    this.fromAccount,
    this.toAccount,
    this.transactionHash,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchant_name': merchantName,
      'category': category,
      'type': type.name, // Store enum as string
      'date': date.toIso8601String(),
      'description': description,
      'sms_body': smsBody,
      'bank_name': bankName,
      'account_number': accountNumber,
      'is_recurring': isRecurring ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'reference': reference,
      'balance': balance,
      'credit_limit': creditLimit,
      'is_from_card': isFromCard ? 1 : 0,
      'currency': currency,
      'from_account': fromAccount,
      'to_account': toAccount,
      'transaction_hash': transactionHash,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: map['amount'],
      merchantName: map['merchant_name'],
      category: map['category'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      date: DateTime.parse(map['date']),
      description: map['description'],
      smsBody: map['sms_body'],
      bankName: map['bank_name'],
      accountNumber: map['account_number'],
      isRecurring: map['is_recurring'] == 1,
      isDeleted: map['is_deleted'] == 1,
      reference: map['reference'],
      balance: map['balance']?.toDouble(),
      creditLimit: map['credit_limit']?.toDouble(),
      isFromCard: map['is_from_card'] == 1,
      currency: map['currency'] ?? "INR",
      fromAccount: map['from_account'],
      toAccount: map['to_account'],
      transactionHash: map['transaction_hash'],
    );
  }

  // Generate transaction hash for deduplication (matching Kotlin implementation)
  String generateTransactionId() {
    final normalizedAmount = amount.toStringAsFixed(2);
    final smsBodyForHash = smsBody ?? '';
    final data = "$bankName|$normalizedAmount|$smsBodyForHash";
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Creates a copy of this transaction with modified fields
  Transaction copyWith({
    int? id,
    double? amount,
    String? merchantName,
    String? category,
    TransactionType? type,
    DateTime? date,
    String? description,
    String? smsBody,
    String? bankName,
    String? accountNumber,
    bool? isRecurring,
    bool? isDeleted,
    String? reference,
    double? balance,
    double? creditLimit,
    bool? isFromCard,
    String? currency,
    String? fromAccount,
    String? toAccount,
    String? transactionHash,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchantName: merchantName ?? this.merchantName,
      category: category ?? this.category,
      type: type ?? this.type,
      date: date ?? this.date,
      description: description ?? this.description,
      smsBody: smsBody ?? this.smsBody,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      isRecurring: isRecurring ?? this.isRecurring,
      isDeleted: isDeleted ?? this.isDeleted,
      reference: reference ?? this.reference,
      balance: balance ?? this.balance,
      creditLimit: creditLimit ?? this.creditLimit,
      isFromCard: isFromCard ?? this.isFromCard,
      currency: currency ?? this.currency,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
      transactionHash: transactionHash ?? this.transactionHash,
    );
  }
}
