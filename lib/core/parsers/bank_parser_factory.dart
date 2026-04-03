import 'bank_parser_base.dart';
import 'hdfc_bank_parser.dart';
import 'indian_bank_parsers.dart';
import 'indian_bank_parsers_extended.dart';
import 'international_bank_parsers.dart';
import '../../services/compiled_patterns.dart';

/// Factory for creating bank-specific parsers
/// Registry of 5+ bank parsers with easy extensibility
class BankParserFactory {
  static final List<BankParser> _parsers = [
    // Specific Indian Bank Parsers (High Priority)
    HDFCBankParser(),
    SBIBankParser(),
    ICICIBankParser(),
    AxisBankParser(),
    KotakBankParser(),

    // Extended Indian Bank Parsers (Batch 2 — PSU Banks)
    BOIBankParser(),
    PNBBankParser(),
    CanaraBankParser(),
    UnionBankParser(),
    BOBBankParser(),
    IDBIBankParser(),
    IOBBankParser(),
    UCOBankParser(),
    CentralBankParser(),
    BankOfMaharashtraParser(),
    PunjabSindBankParser(),
    IndianBankParser(),

    // Extended Indian Bank Parsers (Batch 3 — Private Banks)
    YesBankParser(),
    IDFCFirstBankParser(),
    IndusIndBankParser(),
    BandhanBankParser(),
    FederalBankParser(),
    RBLBankParser(),
    AUBankParser(),
    KVBBankParser(),
    SouthIndianBankParser(),
    KarnatakaBankParser(),
    CSBBankParser(),
    DCBBankParser(),
    TMBBankParser(),

    // Extended Indian Bank Parsers (Batch 4 — Payments Banks)
    PaytmBankParser(),
    AirtelBankParser(),
    IPPBParser(),

    // International Parsers
    ChaseBankParser(),
    WellsFargoParser(),
    BankOfAmericaParser(),
    HSBCBankParser(),
    BarclaysBankParser(),
    EmiratesNBDParser(),
    ADCBParser(),

    // Generic Fallback for 100+ Indian Banks
    GenericIndianBankParser(),
  ];

  /// Get appropriate parser for the given sender
  static BankParser? getParser(String sender) {
    for (final parser in _parsers) {
      if (parser.canHandle(sender)) {
        return parser;
      }
    }
    return null;
  }

  /// Parse SMS and return ParsedTransaction
  static ParsedTransaction? parseTransaction(
    String smsBody,
    String sender,
    int timestamp,
  ) {
    // Reject blacklisted (spam/scam) senders early
    final senderUpper = sender
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (CompiledPatterns.blacklistedSenderIds.contains(senderUpper)) {
      return null;
    }

    final parser = getParser(sender);
    if (parser == null) {
      return null;
    }

    return parser.parse(smsBody, sender, timestamp);
  }

  /// Get all registered parsers
  static List<BankParser> getAllParsers() {
    return List.unmodifiable(_parsers);
  }

  /// Get parser by bank name
  static BankParser? getParserByName(String bankName) {
    try {
      return _parsers.firstWhere(
        (parser) =>
            parser.getBankName().toLowerCase() == bankName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get count of registered parsers
  static int getParserCount() {
    return _parsers.length;
  }

  /// Get list of supported banks
  static List<String> getSupportedBanks() {
    return _parsers.map((parser) => parser.getBankName()).toList();
  }
}
