/// Compiled regex patterns for SMS parsing
/// Ported from Kotlin parser-core/CompiledPatterns.kt

class CompiledPatterns {
  // =====================================
  // AMOUNT PATTERNS
  // =====================================
  static final amountRs = RegExp(
    r'Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final amountINR = RegExp(
    r'INR\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final amountRupee = RegExp(r'₹\s*([0-9,]+(?:\.[0-9]{1,2})?)');
  static final amountDebitedBy = RegExp(
    r'debited\s+by\s+([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final amountPatterns = [
    amountRs,
    amountINR,
    amountRupee,
    amountDebitedBy,
  ];

  // =====================================
  // REFERENCE PATTERNS
  // =====================================
  static final refGeneric = RegExp(
    r'(?:Ref|Reference|Txn|Transaction)(?:\s+No)?[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );
  static final refUPI = RegExp(r'UPI[:\s]+([0-9]+)', caseSensitive: false);
  static final refNumber = RegExp(
    r'Reference\s+Number[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );
  static final refNo = RegExp(
    r'Ref\s+No\.?\s+([A-Z0-9]+)',
    caseSensitive: false,
  );
  static final refRefno = RegExp(r'Refno\s+([A-Z0-9]+)', caseSensitive: false);
  // Handles "UPI Ref:DR/979247477" format - extracts numeric portion after DR/
  static final refUpiDr = RegExp(
    r'UPI\s+Ref[:\s]+DR/([0-9]+)',
    caseSensitive: false,
  );
  static final refPatterns = [
    refUpiDr,
    refGeneric,
    refUPI,
    refNumber,
    refNo,
    refRefno,
  ];

  // =====================================
  // ACCOUNT PATTERNS
  // =====================================
  static final accountWithMask = RegExp(
    r'(?:A/c|Account|Acct)(?:\s+No)?(?:\s+ending)?\.?\s+(?:XX+|\*+)?(\d{3,4})',
    caseSensitive: false,
  );
  // Handles "A/c ...3" or "A/c ....0693" - ellipsis followed by 1-4 digits
  static final accountEllipsis = RegExp(
    r'(?:A/c|Account|Acct)(?:\s+No)?\.?\s+\.{2,}(\d{1,4})',
    caseSensitive: false,
  );
  static final cardWithMask = RegExp(
    r'Card\s+(?:XX+|\*+)?(\d{4})',
    caseSensitive: false,
  );
  static final accountXX = RegExp(
    r'(?:A/c|Ac)\s*XX(\d{4})',
    caseSensitive: false,
  );
  static final accountPatterns = [accountWithMask, cardWithMask, accountXX];

  // =====================================
  // BALANCE PATTERNS
  // =====================================
  static final balanceRs = RegExp(
    r'(?:Clear\s+Bal|Bal|Balance|Avl\s+Bal|Available\s+Balance)[:\s]+Rs\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final balanceINR = RegExp(
    r'(?:Bal|Balance|Avl Bal|Available Balance)[:\s]+INR\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final balanceAvl = RegExp(
    r'Avl\s+Bal\s+([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final balancePatterns = [balanceRs, balanceINR, balanceAvl];

  // =====================================
  // MERCHANT PATTERNS (Generic)
  // =====================================
  // Direct person name pattern: "sent to Firstname Lastname" (strictly 2+ capitalized words)
  static final merchantToPerson = RegExp(
    r'(?:to|sent to|paid to)\s+([A-Z][a-zA-Z]+(?:\s+(?!On\b|At\b)[A-Z][A-Za-z\.]+)+)',
    caseSensitive: false,
  );
  static final merchantToPersonAllCaps = RegExp(
    r'(?:to|sent to|paid to)\s+([A-Z\s]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  static final merchantUpiRef = RegExp(
    r'UPI Ref\.?\s*([A-Za-z0-9]+)\s+to\s+([^\.]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  static final merchantInfo = RegExp(
    r'Info:\s*(?:UPI/)?([^/\.]+?)(?:/|$)',
    caseSensitive: false,
  );
  static final merchantTowards = RegExp(
    r'towards\s+([^\.]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  static final merchantFor = RegExp(
    r'for\s+([^\.]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  static final merchantBy = RegExp(
    r'by\s+([^\.]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  static final merchantSentTo = RegExp(
    r'sent\s+to\s+([^\.]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  static final merchantReceivedFrom = RegExp(
    r'received\s+from\s+([^\.]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  static final merchantPaidTo = RegExp(
    r'paid\s+to\s+([^\.]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  static final merchantVpaDotName = RegExp(
    r'VPA\s+[^@\s]+@[^\s]+\s*\.\s*([^\.]+?)(?:\s+on|\s+Ref|\s+UPI|\.|$)',
    caseSensitive: false,
  );
  // Updated patterns to catch UPI VPAs better
  static final merchantTo = RegExp(
    r'to\s+([^(\n]+?)(?:\s+\(UPI|\s+on\s+\d{2}|\.\s+Ref|\.\s*$)',
    caseSensitive: false,
  );
  static final merchantFrom = RegExp(
    r'from\s+([^(\n]+?)(?:\s+\(UPI|\s+on\s+\d{2})',
    caseSensitive: false,
  );
  static final merchantAt = RegExp(
    r'at\s+([^\.\n]+?)(?:\s+on|\s+Ref)',
    caseSensitive: false,
  );
  static final merchantVPA = RegExp(r'VPA\s+([^@\s]+)@', caseSensitive: false);
  static final merchantVPAWithName = RegExp(
    r'VPA\s+[^@]+@[^\s]+\s*\(([^)]+)\)',
    caseSensitive: false,
  );
  static final merchantTrfTo = RegExp(
    r'trf\s+to\s+([A-Za-z\s]+?)(?:\s+Ref|\s+UPI|\.|$|\s+Refno)',
    caseSensitive: false,
  );

  static final hdfcToOn = RegExp(
    r'(?:To|Sent to)\s+([A-Z\s\.]+?)\s+On\s+\d{2}',
    caseSensitive: false,
  );

  static final merchantPatterns = [
    merchantVpaDotName,
    hdfcToOn, // Added as priority
    merchantToPerson,
    merchantToPersonAllCaps,
    merchantUpiRef,
    merchantInfo,
    merchantTowards,
    merchantFor,
    merchantBy,
    merchantTo,
    merchantFrom,
    merchantAt,
    merchantVPA,
    merchantVPAWithName,
    merchantTrfTo,
    merchantSentTo,
    merchantReceivedFrom,
    merchantPaidTo,
  ];

  // =====================================
  // HDFC SPECIFIC PATTERNS
  // =====================================
  static final hdfcSenders = ['HDFCBK', 'HDFCBANK', 'HDFC', 'HDFCB'];
  static final hdfcDltPatterns = [
    RegExp(r'^[A-Z]{2}-HDFCBK'),
    RegExp(r'^[A-Z]{2}-HDFC'),
    RegExp(r'^HDFC-[A-Z]+$'),
  ];
  static final hdfcSalary = RegExp(
    r'SALARY[-\s]([^\.]+?)(?:\s+Info|$)',
    caseSensitive: false,
  );
  static final hdfcInfo = RegExp(
    r'Info:\s*(?:UPI/)?([^/\.]+?)(?:/|$)',
    caseSensitive: false,
  );
  static final hdfcSpentAt = RegExp(
    r'at\s+([^\.]+?)\s+on\s+\d{2}',
    caseSensitive: false,
  );
  static final hdfcCardAt = RegExp(
    r'From HDFC Bank Card\s+\w+\s+At\s+([^O]+?)\s+On',
    caseSensitive: false,
  );
  static final hdfcDebitFor = RegExp(
    r'debited\s+for\s+([^\.]+?)\s+on\s+\d{2}',
    caseSensitive: false,
  );

  // VPA patterns ported from Kotlin
  static final hdfcFromVpa = RegExp(
    r'from\s+VPA\s*([^@\s]+)@[^\s]+\s*\(UPI\s+\d+\)',
    caseSensitive: false,
  );
  static final hdfcVpaWithName = RegExp(
    r'VPA\s+[^@\s]+@[^\s]+\s*\(([^)]+)\)',
    caseSensitive: false,
  );
  static final hdfcVpaPattern = RegExp(
    r'VPA\s+([^@\s]+)@',
    caseSensitive: false,
  );

  // =====================================
  // ICICI SPECIFIC PATTERNS
  // =====================================
  static final iciciSenders = ['ICICIB', 'ICICI', 'ICICIBK'];
  static final iciciDltPatterns = [
    RegExp(r'^[A-Z]{2}-ICICIB'),
    RegExp(r'^[A-Z]{2}-ICICI'),
  ];

  // =====================================
  // SBI SPECIFIC PATTERNS
  // =====================================
  static final sbiSenders = ['SBIINB', 'SBI', 'SBIPSG', 'SBISMS'];
  static final sbiDltPatterns = [
    RegExp(r'^[A-Z]{2}-SBIINB'),
    RegExp(r'^[A-Z]{2}-SBI'),
  ];

  // =====================================
  // AXIS SPECIFIC PATTERNS
  // =====================================
  static final axisSenders = ['AXISBK', 'AXIS', 'AXISB'];
  static final axisDltPatterns = [
    RegExp(r'^[A-Z]{2}-AXISBK'),
    RegExp(r'^[A-Z]{2}-AXIS'),
  ];

  // =====================================
  // KOTAK SPECIFIC PATTERNS
  // =====================================
  static final kotakSenders = ['KOTAKB', 'KOTAK', 'KOTAKBK'];
  static final kotakDltPatterns = [
    RegExp(r'^[A-Z]{2}-KOTAKB'),
    RegExp(r'^[A-Z]{2}-KOTAK'),
  ];

  // =====================================
  // BOI (Bank of India) PATTERNS
  // =====================================
  static final boiSenders = ['BOIIND', 'BOI', 'BOISMS'];
  static final boiDltPatterns = [
    RegExp(r'^[A-Z]{2}-BOIIND'),
    RegExp(r'^[A-Z]{2}-BOI'),
    RegExp(r'-BOI$'),
  ];
  static final boiCreditedTo = RegExp(
    r'credited\s+to\s+([A-Za-z\s]+?)(?:\s+via|\s+on)',
    caseSensitive: false,
  );
  static final boiCreditedBy = RegExp(
    r'Credited.*?by\s+UPI\s+ref',
    caseSensitive: false,
  );

  // =====================================
  // PNB PATTERNS
  // =====================================
  static final pnbSenders = ['PNBSMS', 'PNB', 'PUNBAN'];
  static final pnbDltPatterns = [
    RegExp(r'^[A-Z]{2}-PNBSMS'),
    RegExp(r'^[A-Z]{2}-PNB'),
  ];

  // =====================================
  // CANARA PATTERNS
  // =====================================
  static final canaraSenders = ['CANBNK', 'CANARA', 'CANBKS'];
  static final canaraDltPatterns = [
    RegExp(r'^[A-Z]{2}-CANBNK'),
    RegExp(r'^[A-Z]{2}-CANARA'),
  ];

  // =====================================
  // UNION BANK PATTERNS
  // =====================================
  static final unionSenders = ['UNIONB', 'UBOI', 'UBIINB'];
  static final unionDltPatterns = [
    RegExp(r'^[A-Z]{2}-UNIONB'),
    RegExp(r'^[A-Z]{2}-UBOI'),
  ];

  // =====================================
  // BOB (Bank of Baroda) PATTERNS
  // =====================================
  static final bobSenders = ['BOBTXN', 'BOBSMS', 'BARODA'];
  static final bobDltPatterns = [
    RegExp(r'^[A-Z]{2}-BOBTXN'),
    RegExp(r'^[A-Z]{2}-BOB'),
  ];

  // =====================================
  // YES BANK PATTERNS
  // =====================================
  static final yesSenders = ['YESBK', 'YESBNK', 'YESBANK', 'YES', 'YESB'];
  static final yesDltPatterns = [
    RegExp(r'^[A-Z]{2}-YESBK'),
    RegExp(r'^[A-Z]{2}-YESB'),
  ];

  // =====================================
  // IDFC FIRST PATTERNS
  // =====================================
  static final idfcSenders = ['IDFCFB', 'IDFC', 'IDFCBK'];
  static final idfcDltPatterns = [
    RegExp(r'^[A-Z]{2}-IDFCFB'),
    RegExp(r'^[A-Z]{2}-IDFC'),
  ];

  // =====================================
  // INDUSIND PATTERNS
  // =====================================
  static final indusindSenders = ['INDUSB', 'INDBNK', 'INDUS', 'INDB'];
  static final indusindDltPatterns = [
    RegExp(r'^[A-Z]{2}-INDUSB'),
    RegExp(r'^[A-Z]{2}-INDBNK'),
  ];

  // =====================================
  // BANDHAN PATTERNS
  // =====================================
  static final bandhanSenders = ['BANDHN', 'BANDHAN', 'BANDBN'];
  static final bandhanDltPatterns = [RegExp(r'^[A-Z]{2}-BANDHN')];

  // =====================================
  // FEDERAL BANK PATTERNS
  // =====================================
  static final federalSenders = ['FEDBNK', 'FEDERAL', 'FEDSMS'];
  static final federalDltPatterns = [
    RegExp(r'^[A-Z]{2}-FEDBNK'),
    RegExp(r'^[A-Z]{2}-FEDERAL'),
  ];

  // =====================================
  // UPI APP PATTERNS
  // =====================================
  static final phonepeSenders = ['PHONPE', 'PHONEPE'];
  static final gpaySenders = ['GPAY', 'GOOGLEPAY', 'GOOGLE'];
  static final paytmSenders = ['PAYTM', 'PYTM', 'PAYTMB'];
  static final bhimSenders = ['BHIMUPI', 'BHIM'];

  // =====================================
  // INVESTMENT KEYWORDS
  // =====================================
  static final investmentKeywords = [
    'iccl',
    'indian clearing corporation',
    'nsccl',
    'nse clearing',
    'clearing corporation',
    'nach',
    'ach',
    'ecs',
    'groww',
    'zerodha',
    'upstox',
    'kite',
    'kuvera',
    'paytm money',
    'etmoney',
    'coin by zerodha',
    'smallcase',
    'angel one',
    'angel broking',
    '5paisa',
    'icici securities',
    'icici direct',
    'hdfc securities',
    'kotak securities',
    'motilal oswal',
    'sharekhan',
    'mutual fund',
    'sip',
    'elss',
    'ipo',
    'folio',
    'demat',
    'stockbroker',
    'digital gold',
    'sovereign gold',
    'nse',
    'bse',
    'cdsl',
    'nsdl',
  ];

  // =====================================
  // NEW BANKS SUPPORT (Batch 2 & 3)
  // =====================================
  static final airtelSenders = ['AIRBNK', 'AIRTEL', 'AIRPRB'];
  static final jioSenders = ['JIOPAY', 'JIOBNK', 'JIO'];
  static final ippbSenders = ['IPPB', 'IPPBNK'];

  static final scSenders = ['SCBEST', 'SCBL', 'SCBANK', 'STANCB'];
  static final citiSenders = ['CITIBK', 'CITI', 'CITIB'];
  static final hsbcSenders = ['HSBC', 'HSBCBK'];
  static final dbsSenders = ['DBSBNK', 'DBS', 'DBSSG'];
  static final amexSenders = ['AMEX', 'AMEXEP'];

  static final auSenders = ['AUBANK', 'AUBK', 'AUFIN'];
  static final equitasSenders = ['EQUITAS', 'EQITAS'];
  static final ujjivanSenders = ['UJJIVN', 'UJJVAN'];
  static final utkarshSenders = ['UTKRSH', 'UTKARSH'];

  static final southIndianSenders = ['SIBL', 'SIB'];
  static final karnatakaSenders = ['KARB', 'KARBNK', 'KTKBNK'];
  static final saraswatSenders = ['SRC', 'SARASWAT'];
  static final cityUnionSenders = ['CUB', 'CITYUB'];
  static final jkSenders = ['JKBANK', 'J&K', 'JKB'];
  static final dhanlaxmiSenders = ['DHANBA', 'DHAN'];
  static final indianOverseasSenders = ['IOB', 'IOBA'];
  static final ucoSenders = ['UCO', 'UCOBNK'];
  static final centralSenders = ['CBIN', 'CENTRAL'];
  static final punjabSindSenders = ['PSB', 'PSBANK'];
  static final bomSenders = ['MAHB', 'BOM']; // Bank of Maharashtra
  static final rblSenders = ['RBL', 'RBLBNK', 'RATNAKAR'];
  static final idbiSenders = ['IDBIBK', 'IDBI'];

  // DLT Patterns for generic matching (e.g. BZ-AIRBNK)
  static final genericDltPatterns = [
    RegExp(r'^[A-Z]{2}-AIRBNK'),
    RegExp(r'^[A-Z]{2}-JIOPAY'),
    RegExp(r'^[A-Z]{2}-PAYTMB'),
    RegExp(r'^[A-Z]{2}-IPPB'),
    RegExp(r'^[A-Z]{2}-SCBL'),
    RegExp(r'^[A-Z]{2}-CITI'),
    RegExp(r'^[A-Z]{2}-HSBC'),
    RegExp(r'^[A-Z]{2}-DBS'),
    RegExp(r'^[A-Z]{2}-AUBANK'),
    RegExp(r'^[A-Z]{2}-RBL'),
    RegExp(r'^[A-Z]{2}-IDBIBK'),
  ];

  // =====================================
  // CLEANING PATTERNS
  // =====================================
  static final cleanTrailingParens = RegExp(r'\s*\(.*?\)\s*$');
  static final cleanRefSuffix = RegExp(r'\s+Ref\s+No.*', caseSensitive: false);
  static final cleanDateSuffix = RegExp(r'\s+on\s+\d{2}.*');
  static final cleanUpiSuffix = RegExp(r'\s+UPI.*', caseSensitive: false);
  static final cleanTimeSuffix = RegExp(r'\s+at\s+\d{2}:\d{2}.*');
  static final cleanPvtLtd = RegExp(
    r'(\s+PVT\.?\s*LTD\.?|\s+PRIVATE\s+LIMITED)$',
    caseSensitive: false,
  );
  static final cleanLtd = RegExp(
    r'(\s+LTD\.?|\s+LIMITED)$',
    caseSensitive: false,
  );

  // =====================================
  // SKIP PATTERNS (Non-transactions)
  // =====================================
  static final skipOTP = RegExp(
    r'otp|one\s*time\s*password|verification\s*code',
    caseSensitive: false,
  );
  static final skipPromo = RegExp(
    r'offer|discount|cashback\s+offer|win\s+|click\s+link|click\s+here|tap\s+here|show\s+that\s+you\s+care|enjoy\s+special\s+benefits|download|p\.paytm\.me|bit\.ly|http|https',
    caseSensitive: false,
  );
  static final skipMandate = RegExp(
    r'e-mandate|upi-mandate|mandate.*successfully\s+created',
    caseSensitive: false,
  );
  static final skipFutureDebit = RegExp(
    r'will\s+be\s+debited|mandate\s+set\s+for|upcoming.*mandate',
    caseSensitive: false,
  );
  static final skipBillAlert = RegExp(
    r'bill\s+alert|bill.*is\s+due\s+on',
    caseSensitive: false,
  );
  static final skipPaymentRequest = RegExp(
    r'has\s+requested|payment\s+request|collect\s+request',
    caseSensitive: false,
  );

  // =====================================
  // DATE & VALIDATION PATTERNS (New)
  // =====================================
  // Matches dd/mm/yyyy, dd-mm-yyyy, etc.
  static final dateGeneric = RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}');
  static final dateYearFirst = RegExp(r'\d{4}[/-]\d{1,2}[/-]\d{1,2}');
  static final dateOn = RegExp(
    r'\bon\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}',
    caseSensitive: false,
  );
  static final dateDated = RegExp(
    r'\bdated\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}',
    caseSensitive: false,
  );

  // RRN (Reference Number) Patterns - to distinguish from accounts
  static final rrnPattern = RegExp(
    r'(?:RRN|Ref)\s*(?:No\.?)?\s*(\d{8,16})',
    caseSensitive: false,
  );

  // Year context - to distinguish year 2024 from account 2024
  static final yearContext = RegExp(
    r'(?:20[2-3][0-9])',
  ); // 2020-2039 provided as standalone

  // =====================================
  // INTERNATIONAL CURRENCY PATTERNS
  // =====================================
  static final amountUSD = RegExp(r'\$\s*([0-9,]+(?:\.[0-9]{1,2})?)');
  static final amountGBP = RegExp(r'\u00A3\s*([0-9,]+(?:\.[0-9]{1,2})?)');
  static final amountAED = RegExp(
    r'AED\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final amountIntlPatterns = [amountUSD, amountGBP, amountAED];

  // =====================================
  // COMPREHENSIVE INDIAN BANK LIST (128+ Banks)
  // Used by GenericIndianBankParser
  // =====================================
  static final Map<String, String> senderIdToBankName = {
    // Public Sector
    'SBI': 'State Bank of India',
    'SBIN': 'State Bank of India',
    'SBIINB': 'State Bank of India',
    'SBIPSG': 'State Bank of India',
    'PNB': 'Punjab National Bank',
    'PNBSMS': 'Punjab National Bank',
    'PUNBAN': 'Punjab National Bank',
    'BOB': 'Bank of Baroda',
    'BOBTXN': 'Bank of Baroda',
    'BARODA': 'Bank of Baroda',
    'BOBSMS': 'Bank of Baroda',
    'CANARA': 'Canara Bank', 'CANBNK': 'Canara Bank', 'CANBKS': 'Canara Bank',
    'UNION': 'Union Bank',
    'UNIONB': 'Union Bank',
    'UBI': 'Union Bank',
    'UBOI': 'Union Bank',
    'UBIINB': 'Union Bank',
    'BOI': 'Bank of India',
    'BOIIND': 'Bank of India',
    'BOISMS': 'Bank of India',
    'INDIAN': 'Indian Bank', 'INDBNK': 'Indian Bank',
    'CENTRAL': 'Central Bank of India', 'CBIN': 'Central Bank of India',
    'IOB': 'Indian Overseas Bank', 'IOBA': 'Indian Overseas Bank',
    'UCO': 'UCO Bank', 'UCOBNK': 'UCO Bank',
    'BOM': 'Bank of Maharashtra',
    'MAHABK': 'Bank of Maharashtra',
    'MAHB': 'Bank of Maharashtra',
    'PSB': 'Punjab & Sind Bank', 'PSBANK': 'Punjab & Sind Bank',

    // Private Sector
    'HDFC': 'HDFC Bank', 'HDFCBK': 'HDFC Bank', 'HDFCB': 'HDFC Bank',
    'ICICI': 'ICICI Bank', 'ICICIB': 'ICICI Bank',
    'AXIS': 'Axis Bank', 'AXISBK': 'Axis Bank',
    'KOTAK': 'Kotak Mahindra Bank', 'KOTAKB': 'Kotak Mahindra Bank',
    'INDUS': 'IndusInd Bank',
    'INDUSB': 'IndusInd Bank',
    'INDB': 'IndusInd Bank',
    'YES': 'Yes Bank',
    'YESBNK': 'Yes Bank',
    'YESBK': 'Yes Bank',
    'YESBANK': 'Yes Bank',
    'YESB': 'Yes Bank',
    'IDFC': 'IDFC First Bank',
    'IDFCFB': 'IDFC First Bank',
    'IDFCBK': 'IDFC First Bank',
    'FEDERAL': 'Federal Bank',
    'FEDBNK': 'Federal Bank',
    'FEDSMS': 'Federal Bank',
    'IDBI': 'IDBI Bank', 'IDBIBK': 'IDBI Bank',
    'BANDHAN': 'Bandhan Bank',
    'BANDHN': 'Bandhan Bank',
    'BANDBN': 'Bandhan Bank',
    'RBL': 'RBL Bank', 'RBLBNK': 'RBL Bank', 'RATNAKAR': 'RBL Bank',
    'SOUTH': 'South Indian Bank',
    'SIBL': 'South Indian Bank',
    'SIB': 'South Indian Bank',
    'KVB': 'Karur Vysya Bank', 'KVBANK': 'Karur Vysya Bank',
    'CUB': 'City Union Bank', 'CITYUB': 'City Union Bank',
    'J&K': 'J&K Bank', 'JKBANK': 'J&K Bank',
    'KARNATAKA': 'Karnataka Bank',
    'KARBNK': 'Karnataka Bank',
    'KTKBNK': 'Karnataka Bank',
    'KARB': 'Karnataka Bank',
    'TAMIL': 'Tamilnad Mercantile Bank',
    'TMB': 'Tamilnad Mercantile Bank',
    'TMBBNK': 'Tamilnad Mercantile Bank',
    'NAINITAL': 'Nainital Bank', 'NTBL': 'Nainital Bank',
    'DHAN': 'Dhanlaxmi Bank', 'DHANBA': 'Dhanlaxmi Bank',
    'CSB': 'CSB Bank', 'CSBBNK': 'CSB Bank',
    'DCB': 'DCB Bank', 'DCBBNK': 'DCB Bank',

    // Small Finance Banks
    'AU': 'AU Small Finance Bank',
    'AUBANK': 'AU Small Finance Bank',
    'AUBK': 'AU Small Finance Bank',
    'AUFIN': 'AU Small Finance Bank',
    'EQUITAS': 'Equitas Small Finance Bank',
    'EQITAS': 'Equitas Small Finance Bank',
    'UJJIVAN': 'Ujjivan Small Finance Bank',
    'UJJVAN': 'Ujjivan Small Finance Bank',
    'JANA': 'Jana Small Finance Bank', 'JANABK': 'Jana Small Finance Bank',
    'CAPITAL': 'Capital Small Finance Bank',
    'CAPFB': 'Capital Small Finance Bank',
    'FINCARE': 'Fincare Small Finance Bank',
    'FINCAR': 'Fincare Small Finance Bank',
    'ESAF': 'ESAF Small Finance Bank', 'ESAFBK': 'ESAF Small Finance Bank',
    'NORTH': 'North East Small Finance Bank',
    'NESFB': 'North East Small Finance Bank',
    'SURYODAY': 'Suryoday Small Finance Bank',
    'SURYAB': 'Suryoday Small Finance Bank',
    'UTKARSH': 'Utkarsh Small Finance Bank',
    'UTKRSH': 'Utkarsh Small Finance Bank',
    'SHIVALIK': 'Shivalik Small Finance Bank',
    'SHIVAL': 'Shivalik Small Finance Bank',
    'UNITY': 'Unity Small Finance Bank', 'UNITYB': 'Unity Small Finance Bank',

    // Payments Banks
    'PAYTM': 'Paytm Payments Bank',
    'PAYTMB': 'Paytm Payments Bank',
    'PYTM': 'Paytm Payments Bank',
    'AIRTEL': 'Airtel Payments Bank',
    'AIRBNK': 'Airtel Payments Bank',
    'AIRPRB': 'Airtel Payments Bank',
    'JIO': 'Jio Payments Bank', 'JIOBNK': 'Jio Payments Bank',
    'IPPB': 'India Post Payments Bank', 'IPPBNK': 'India Post Payments Bank',
    'FINO': 'Fino Payments Bank', 'FINOBK': 'Fino Payments Bank',
    'NSDL': 'NSDL Payments Bank', 'NSDLBK': 'NSDL Payments Bank',

    // Co-operative Banks (Major ones)
    'SARASWAT': 'Saraswat Bank', 'SRC': 'Saraswat Bank',
    'COSMOS': 'Cosmos Bank', 'COSBNK': 'Cosmos Bank',
    'SVC': 'SVC Co-operative Bank', 'SVCBNK': 'SVC Co-operative Bank',
    'ABHYUDAYA': 'Abhyudaya Co-op Bank', 'ABHYUD': 'Abhyudaya Co-op Bank',
    'BHARAT': 'Bharat Co-operative Bank',
    'TJSB': 'TJSB Sahakari Bank', 'TJSBBK': 'TJSB Sahakari Bank',
    'NKGSB': 'NKGSB Co-operative Bank',
    'KALUPUR': 'Kalupur Commercial Co-op Bank',
    'KCCB': 'Kalupur Commercial Co-op Bank',
    'RAJKOT': 'Rajkot Nagarik Sahakari Bank',
    'RNSB': 'Rajkot Nagarik Sahakari Bank',
    'PUNE': 'Pune People\'s Co-op Bank', 'PMC': 'Pune People\'s Co-op Bank',
    'CITIZEN': 'Citizen Credit Co-op Bank', 'CCBL': 'Citizen Credit Co-op Bank',
    'BMCB': 'BMCB Bank', 'BMCBBK': 'BMCB Bank',

    // Regional Rural Banks (Sample)
    'APGVB': 'Andhra Pradesh Grameena Vikas Bank',
    'KGB': 'Kerala Gramin Bank',
    'PRATHAMA': 'Prathama UP Gramin Bank',
    'BARODAG': 'Baroda Gujarat Gramin Bank',
    'BGVB': 'Bangiya Gramin Vikash Bank',
    'BGGB': 'Baroda Gujarat Gramin Bank',
    'BGGRB': 'Baroda Gujarat Gramin Bank',

    // Foreign Banks in India
    'CITI': 'Citi Bank', 'CITIBK': 'Citi Bank',
    'HSBC': 'HSBC India', 'HSBCIN': 'HSBC India',
    'SC': 'Standard Chartered',
    'SCBL': 'Standard Chartered',
    'STANCB': 'Standard Chartered',
    'DBS': 'DBS Bank India', 'DBSBNK': 'DBS Bank India',
    'DEUTSCHE': 'Deutsche Bank', 'DB': 'Deutsche Bank',
  };

  // =====================================
  // SPAM / SCAM / FAKE SMS BLACKLIST
  // =====================================
  // Blacklisted sender IDs — messages from these senders are NEVER
  // treated as transactions, even if they contain debited/credited keywords.

  static final Set<String> blacklistedSenderIds = {
    // --- Online Rummy / Gambling / Fantasy Apps ---
    'RUMMY', 'RUMMYC', 'RUMMYB', 'RMYCIR', 'RMYGLD', 'RMYAPP',
    'JNGLRM', 'JUNGLR', 'RUMMYA', 'RUMMYL', 'RMYLRD',
    'DREAM1', 'DRM11', 'DRMC11', 'DRMGLD',
    'MPL', 'MPLAPP', 'MPLGME',
    'WINGO', 'WINZOG', 'WINZO',
    'POKERB', 'POKRST', 'ADDA52',
    'A23RMY', 'A23GAM',
    'MYTEAM', 'MY11CR', 'MY11CI',
    'FANTAS', 'FNTASY',
    'BETWAY', 'BET365', 'BETFAR', '1XBET',
    'CRICCR', 'VISION', 'BAAZI', 'BAAZII', 'BAAZIM',
    'SPARTN', 'POKERR', 'POKRGD', 'POKRZN',
    'TPOKR', 'TELRMY', 'TELRMM',
    'CLSCRM', 'CLASRM', 'SILKRM', 'SILKRY',
    'DANGAL', 'DANGLG', 'HOWZAT',
    'GETMGA', 'MEGACR',
    'TGRUMMY', 'TGRMMY',

    // --- Loan Scam / Instant Loan Apps ---
    'KCREDT', 'KCASH', 'KISTPAY', 'KISTP',
    'CASHE', 'CASHTM', 'CASHTAP',
    'EARNCR', 'KREDIT', 'KRDTBE',
    'LOANBZ', 'LOANCR', 'LOANDL', 'LOANFR', 'LOANAP',
    'MNYVI', 'MONEYW', 'MNYZEN', 'RUPYLK', 'RUPYAL',
    'RUPYLN', 'RUPIFI', 'RUPIKR', 'RUPIYO',
    'INSTLN', 'INSTCR', 'INSTMN',
    'NIRALN', 'DHNICR', 'TRUELN',
    'FRCASH', 'FNANCR', 'FLASHC',
    'SMRTCN', 'QSTCSH', 'EZCASH', 'EZCRED',
    'PYTSFE', 'SAFELN', 'LENDNG',
    'OKRUPEE', 'OLACSH', 'STARUP',

    // --- Crypto / Trading / Investment Scams ---
    'CRYPEX', 'BITCIN', 'BITMAP', 'BITCOI',
    'WAZIRX', 'COINDC', 'COINSWI',
    'BINANC', 'OLMPRD', 'IQOPTN', 'EXPOPN',
    'FXPRO', 'OCTAFX', 'FOREX',
    'ITSTRD', 'TRDVEW',
    'PMPGRP', 'STKCAL', 'SHRETIP', 'TIPSTR', 'TIPTRD',
    'JACKPT', 'JACKP', 'GOLDBX',

    // --- E-commerce / Shopping Spam ---
    'SHOPSY', 'SHOPEE', 'MEESHO', 'MEESHN',
    'AJIO', 'SNAPDL', 'CLBFCT',
    'TATAPL', 'TATACLQ',
    'LKSHOP', 'INDMRT',

    // --- Fake Reward / Lottery / Prize ---
    'REWARD', 'RWRDPT', 'RWRDST',
    'LOTERY', 'LOTTERY', 'LTRY', 'LOTWIN',
    'PRIZEW', 'PRZDRA', 'BIGWIN', 'JACKPZ',
    'SPINWN', 'LUCKYD', 'MEGAWM',
    'WINNRD', 'WINAPK', 'WINRCR',

    // --- Fake UPI / Wallet Promotion ---
    'FREERC', 'FREERCH', 'FREEUP',
    'CASBCK', 'CSHBAK', 'BNSCSH',
    'MOBKWK', 'FREPAY',

    // --- Insurance / Health Spam ---
    'PLCYBZ', 'PLCYBZR', 'INSRNC',
    'INSCVR', 'HLTHKR', 'MEDCRM',

    // --- Job / MLM Scam ---
    'JOBHNT', 'JOBSRK', 'WORKFM',
    'EASYDK', 'EASYTN', 'EARNDL',
    'AFFIMT', 'MLMPAY',
  };

  // Body-level keywords — if ANY of these appear in the SMS body, skip it.
  // These catch messages that slip through sender-ID checks because they
  // use legitimate-looking senders but contain scam/spam content.
  static final skipGambling = RegExp(
    r'rummy|teen\s*patti|poker|casino|betting|satta|matka|jackpot'
    r'|slot\s*machine|blackjack|baccarat|roulette|lucky\s*draw'
    r'|ludo\s*king|fantasy\s*league|dream\s*11|winzo|mpl\b',
    caseSensitive: false,
  );

  static final skipLoanScam = RegExp(
    r'instant\s*loan|personal\s*loan\s*(?:of|up\s*to|approved)'
    r'|pre[\-\s]*approved\s*loan|loan\s*(?:disbursed|available|offered)'
    r'|(?:get|avail)\s*(?:a\s+)?loan|(?:upto|up\s*to)\s*(?:rs\.?\s*)?\d+\s*(?:lakh|lac)'
    r'|credit\s*line\s*of|credit\s*limit\s*increased'
    r'|emi\s*starts?\s*(?:at|from)\s*rs'
    r'|low\s*interest\s*loan|zero\s*(?:%|percent)\s*interest'
    r'|apply\s*(?:now|here)\s*(?:for\s+)?loan',
    caseSensitive: false,
  );

  static final skipFakePrize = RegExp(
    r"congratulations?\s*!?\s*(?:you\s*(?:have\s*)?won|you\s*(?:are|'re)\s*selected)"
    r'|you\s*(?:have\s*)?won\s*(?:rs|inr|₹)'
    r'|lottery|lucky\s*winner|prize\s*money|claim\s*(?:your\s*)?(?:reward|prize|bonus)'
    r'|free\s*(?:gift|reward|money|cash)\b|(?:gift|cash)\s*voucher'
    r'|scratch\s*card|spin\s*(?:and|&|to)\s*win'
    r'|reward\s*points?\s*(?:credited|added|expire)',
    caseSensitive: false,
  );

  static final skipCryptoScam = RegExp(
    r'bitcoin|ethereum|crypto\s*(?:currency|trading|invest)'
    r'|blockchain|nft\s*(?:drop|free|mint)|web3\s*earn'
    r'|(?:guaranteed|daily)\s*(?:\d+%?\s*)?(?:return|profit|income)'
    r'|double\s*(?:your\s*)?(?:money|investment)'
    r'|invest\s*(?:rs|inr|₹)\s*\d+.*(?:earn|get|return)',
    caseSensitive: false,
  );

  static final skipJobScam = RegExp(
    r'work\s*from\s*home\s*(?:job|earn|opportunity)'
    r'|earn\s*(?:rs|inr|₹)\s*\d+\s*(?:daily|per\s*day|per\s*hour|monthly)'
    r'|part\s*time\s*(?:job|work|earning)|(?:data\s*entry|typing)\s*job'
    r'|join\s*(?:whatsapp|telegram)\s*(?:group|channel)'
    r'|simple\s*task|like\s*(?:and|&)\s*earn',
    caseSensitive: false,
  );

  static final skipFakeUpi = RegExp(
    r'cashback\s*(?:of|worth)\s*(?:rs|inr|₹)'
    r'|free\s*recharge|(?:refer|invite)\s*(?:and|&)\s*earn'
    r'|bonus\s*(?:credited|added|code)|promo\s*code'
    r'|use\s*code\s+\w+\s+(?:to\s+)?get|activate\s*(?:your\s*)?upi\s*(?:cashback|reward)',
    caseSensitive: false,
  );

  static final skipPhishing = RegExp(
    r'kyc\s*(?:update|expire|verify|suspend|block)'
    r'|account\s*(?:will\s*be|has\s*been)\s*(?:blocked|suspended|closed)'
    r'|pan\s*(?:card|number)\s*(?:link|update|expire)'
    r'|aadhar\s*(?:link|update)\s*(?:required|mandatory)'
    r'|click\s*(?:on\s*)?(?:this\s*)?link\s*to\s*(?:verify|update|activate|unlock)'
    r'|dear\s*customer.*(?:update|verify).*(?:immediately|urgently|within\s*\d+\s*hour)',
    caseSensitive: false,
  );

  /// All body-level spam patterns combined for a single-pass check.
  static final List<RegExp> allSpamBodyPatterns = [
    skipGambling,
    skipLoanScam,
    skipFakePrize,
    skipCryptoScam,
    skipJobScam,
    skipFakeUpi,
    skipPhishing,
  ];
}
