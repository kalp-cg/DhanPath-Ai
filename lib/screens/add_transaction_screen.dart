import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../services/database_helper.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../utils/category_icons.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? prefilledDescription;

  const AddTransactionScreen({super.key, this.prefilledDescription});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Food & Dining';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;
  bool _speechReady = false;
  bool _isListening = false;
  String _voiceText = '';
  String _selectedVoiceLocaleId = 'auto';

  static const List<_VoiceLocaleOption> _voiceLocales = [
    _VoiceLocaleOption(id: 'auto', label: 'Auto'),
    _VoiceLocaleOption(id: 'en_IN', label: 'English'),
    _VoiceLocaleOption(id: 'hi_IN', label: 'Hindi'),
    _VoiceLocaleOption(id: 'gu_IN', label: 'Gujarati'),
  ];

  // Top-level categories shown as chips (most common)
  static const _quickCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Utilities',
    'Entertainment',
    'Healthcare',
    'Education',
    'Groceries',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledDescription != null &&
        widget.prefilledDescription!.isNotEmpty) {
      _noteController.text = widget.prefilledDescription!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocus.requestFocus();
    });
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ready = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );

    if (!mounted) return;
    setState(() => _speechReady = ready);
  }

  Future<void> _toggleVoiceInput() async {
    if (!_speechReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input is not available on this device')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    setState(() {
      _voiceText = '';
      _isListening = true;
    });

    await _speech.listen(
      localeId: _selectedVoiceLocaleId == 'auto' ? null : _selectedVoiceLocaleId,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(partialResults: true),
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _voiceText = result.recognizedWords;
        });
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _applyVoiceCommand(result.recognizedWords);
        }
      },
    );
  }

  void _applyVoiceCommand(String speechText) {
    final parsed = _parseVoiceCommand(speechText);

    setState(() {
      if (parsed.amount != null && parsed.amount! > 0) {
        _amountController.text = parsed.amount!.toStringAsFixed(
          parsed.amount! % 1 == 0 ? 0 : 2,
        );
      }
      if (parsed.type != null) {
        _selectedType = parsed.type!;
      }
      if (parsed.category != null) {
        _selectedCategory = parsed.category!;
      }
      if (parsed.merchant != null && parsed.merchant!.isNotEmpty) {
        _merchantController.text = parsed.merchant!;
      }
      if (parsed.note != null && parsed.note!.isNotEmpty) {
        _noteController.text = parsed.note!;
      }
    });

    final hasAmount = parsed.amount != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasAmount
              ? 'Voice command captured. Review and tap save.'
              : 'Could not detect amount. Please say amount clearly.',
        ),
      ),
    );
  }

  _VoiceParseResult _parseVoiceCommand(String input) {
    final normalizedInput = _normalizeNumerals(input);
    final cleanedInput = _sanitizeRoughLanguage(normalizedInput);
    final lower = cleanedInput.toLowerCase().trim();

    TransactionType type = TransactionType.expense;
    const expenseKeywords = [
      'spent',
      'spend',
      'spending',
      'paid',
      'pay',
      'payment',
      'debit',
      'debited',
      'expense',
      'gave',
      'sent',
      'send',
      'buy',
      'bought',
      'purchase',
      'rent',
      'emi',
      'bill',
      'kharch',
      'kharcha',
      'kharch kiya',
      'kharch kiye',
      'kharch kara',
      'खर्च',
      'खर्चा',
      'दिया',
      'भुगतान',
      'kharid',
      'chukavya',
      'kharchyu',
      'ખર્ચ',
      'ચૂકવ્યું',
      'આપ્યું',
      'ચુકવણી',
    ];
    const incomeKeywords = [
      'receive',
      'received',
      'receiving',
      'got',
      'income',
      'salary',
      'credit',
      'credited',
      'deposit',
      'deposited',
      'earned',
      'aaya',
      'aayi',
      'mila',
      'mili',
      'prapt',
      'refund',
      'cashback',
      'आया',
      'आई',
      'मिला',
      'मिली',
      'प्राप्त',
      'aavak',
      'aavyu',
      'malyu',
      'jama',
      'જમા',
      'મળ્યું',
      'આવક',
      'ક્રેડિટ',
      'પગાર',
    ];

    final expenseScore = _countMatches(lower, expenseKeywords);
    final incomeScore = _countMatches(lower, incomeKeywords);

    if (expenseScore > incomeScore) {
      type = TransactionType.expense;
    } else if (incomeScore > expenseScore) {
      type = TransactionType.income;
    } else {
      final hasFromCue = _containsAny(lower, [
        ' from ',
        ' se ',
        'से',
        'થી',
        ' thi ',
      ]);
      final hasToCue = _containsAny(lower, [
        ' to ',
        ' at ',
        ' ko ',
        'को',
        ' par ',
        'पे',
        'પર',
        ' ne ',
        'ને',
      ]);
      if (hasFromCue && !hasToCue) {
        type = TransactionType.income;
      } else if (hasToCue) {
        type = TransactionType.expense;
      } else if (_looksLikeIncomeText(lower)) {
        type = TransactionType.income;
      } else {
        // Safer fallback for finance logging: unknown statements are usually spend entries.
        type = TransactionType.expense;
      }
    }

    double? amount;
    final taggedAmount = RegExp(
      r'(?:rs\.?|inr|rupees?|₹)\s*([0-9]+(?:[,.][0-9]{1,2})?)',
    ).firstMatch(lower);
    if (taggedAmount != null) {
      amount = double.tryParse(taggedAmount.group(1)!.replaceAll(',', ''));
    } else {
      final genericAmount = RegExp(r'\b([0-9]+(?:[,.][0-9]{1,2})?)\b').firstMatch(lower);
      if (genericAmount != null) {
        amount = double.tryParse(genericAmount.group(1)!.replaceAll(',', ''));
      }
    }
    amount ??= _extractAmountFromWords(lower);

    String? merchant;
    if (type == TransactionType.income) {
      merchant = _extractEntityAfterCue(lower, [
        'from',
        'se',
        'से',
        'થી',
        'thi',
      ]);
    } else {
      merchant = _extractEntityAfterCue(lower, [
        'to',
        'at',
        'ko',
        'को',
        'ને',
        'par',
        'પર',
      ]);
    }

    final category = _guessCategoryFromText(lower, type);

    return _VoiceParseResult(
      amount: amount,
      type: type,
      category: category,
      merchant: merchant == null ? null : _toTitleCase(merchant),
      note: _toTitleCase(cleanedInput.trim()),
    );
  }

  String _sanitizeRoughLanguage(String text) {
    final roughWords = [
      'bc',
      'mc',
      'bkl',
      'gandu',
      'chutiya',
      'bhenchod',
      'madarchod',
      'saala',
      'saali',
      'bakwas',
      'bekar',
      'kharab',
    ];
    var cleaned = text;
    for (final word in roughWords) {
      cleaned = cleaned.replaceAll(RegExp(RegExp.escape(word), caseSensitive: false), ' ');
    }
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _countMatches(String text, List<String> keywords) {
    var score = 0;
    for (final keyword in keywords) {
      if (_containsKeyword(text, keyword)) score++;
    }
    return score;
  }

  bool _containsKeyword(String text, String keyword) {
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    // Latin keywords should use word-boundary style matching to reduce false positives.
    final isLatin = RegExp(r'^[a-z0-9 ]+$').hasMatch(lowerKeyword);
    if (isLatin) {
      final escaped = RegExp.escape(lowerKeyword.trim()).replaceAll(' ', r'\s+');
      final pattern = RegExp(r'(^|\s)' + escaped + r'(\s|$)', caseSensitive: false);
      return pattern.hasMatch(lowerText);
    }

    // Non-Latin scripts (Hindi/Gujarati) are matched as contains.
    return lowerText.contains(lowerKeyword);
  }

  bool _looksLikeIncomeText(String text) {
    return _containsAny(text, [
      'salary',
      'refund',
      'cashback',
      'bonus',
      'stipend',
      'commission',
      'payout',
      'मिला',
      'मिली',
      'जमा',
      'પગાર',
      'જમા',
      'મળ્યું',
    ]);
  }

  double? _extractAmountFromWords(String text) {
    final units = <String, int>{
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'ek': 1,
      'do': 2,
      'teen': 3,
      'char': 4,
      'chaar': 4,
      'paanch': 5,
      'che': 6,
      'chhe': 6,
      'saat': 7,
      'aath': 8,
      'nau': 9,
      'das': 10,
      'એક': 1,
      'બે': 2,
      'ત્રણ': 3,
      'ચાર': 4,
      'પાંચ': 5,
      'છ': 6,
      'સાત': 7,
      'આઠ': 8,
      'નવ': 9,
      'દસ': 10,
      'एक': 1,
      'दो': 2,
      'तीन': 3,
      'चार': 4,
      'पांच': 5,
      'छह': 6,
      'सात': 7,
      'आठ': 8,
      'नौ': 9,
      'दस': 10,
    };
    final multipliers = <String, int>{
      'hundred': 100,
      'thousand': 1000,
      'lakh': 100000,
      'so': 100,
      'sau': 100,
      'hazaar': 1000,
      'hazar': 1000,
      'hajar': 1000,
      'hajaar': 1000,
      'સો': 100,
      'હજાર': 1000,
      'સૌ': 100,
      'हजार': 1000,
      'सौ': 100,
    };

    final tokens = text
        .replaceAll(RegExp(r'[^\w\u0900-\u097F\u0A80-\u0AFF\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    var total = 0;
    var current = 0;
    var found = false;

    for (final tokenRaw in tokens) {
      final token = tokenRaw.toLowerCase();
      if (units.containsKey(token)) {
        current += units[token]!;
        found = true;
      } else if (multipliers.containsKey(token)) {
        final factor = multipliers[token]!;
        if (current == 0) current = 1;
        current *= factor;
        found = true;
      } else if (found) {
        total += current;
        current = 0;
      }
    }

    total += current;
    if (!found || total <= 0) return null;
    return total.toDouble();
  }

  String? _extractEntityAfterCue(String text, List<String> cues) {
    for (final cue in cues) {
      final pattern = RegExp('${RegExp.escape(cue)}\\s+([^,.!?]{2,40})', caseSensitive: false);
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)?.trim() ?? '';
        if (raw.isEmpty) continue;
        final stopWords = [
          'for',
          'on',
          'at',
          'in',
          'rupees',
          'rs',
          'inr',
          'ke liye',
          'लिए',
          'માટે',
        ];
        var entity = raw;
        for (final stop in stopWords) {
          final idx = entity.toLowerCase().indexOf(stop);
          if (idx > 0) {
            entity = entity.substring(0, idx).trim();
          }
        }
        if (entity.isNotEmpty) return entity;
      }
    }
    return null;
  }

  String _normalizeNumerals(String text) {
    const map = {
      '०': '0',
      '१': '1',
      '२': '2',
      '३': '3',
      '४': '4',
      '५': '5',
      '६': '6',
      '७': '7',
      '८': '8',
      '९': '9',
      '૦': '0',
      '૧': '1',
      '૨': '2',
      '૩': '3',
      '૪': '4',
      '૫': '5',
      '૬': '6',
      '૭': '7',
      '૮': '8',
      '૯': '9',
    };

    var result = text;
    map.forEach((source, target) {
      result = result.replaceAll(source, target);
    });
    return result;
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  String _toTitleCase(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return cleaned;
    return cleaned
        .split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _guessCategoryFromText(String text, TransactionType type) {
    final keywordToCategory = <String, String>{
      'grocery': 'Groceries',
      'groceries': 'Groceries',
      'kirana': 'Groceries',
      'ration': 'Groceries',
      'કિરાણા': 'Groceries',
      'રાશન': 'Groceries',
      'किराना': 'Groceries',
      'राशन': 'Groceries',
      'food': 'Food & Dining',
      'restaurant': 'Food & Dining',
      'lunch': 'Food & Dining',
      'dinner': 'Food & Dining',
      'khana': 'Food & Dining',
      'jamvanu': 'Food & Dining',
      'खाना': 'Food & Dining',
      'भोजन': 'Food & Dining',
      'જમવાનું': 'Food & Dining',
      'ખાવાનું': 'Food & Dining',
      'petrol': 'Transportation',
      'fuel': 'Transportation',
      'uber': 'Transportation',
      'ola': 'Transportation',
      'bus': 'Transportation',
      'travel': 'Transportation',
      'yatra': 'Transportation',
      'યાત્રા': 'Transportation',
      'सफर': 'Transportation',
      'shopping': 'Shopping',
      'amazon': 'Shopping',
      'flipkart': 'Shopping',
      'खरीदारी': 'Shopping',
      'ખરીદી': 'Shopping',
      'movie': 'Entertainment',
      'netflix': 'Entertainment',
      'cinema': 'Entertainment',
      'मनोरंजन': 'Entertainment',
      'મનોરંજન': 'Entertainment',
      'electricity': 'Utilities',
      'bill': 'Utilities',
      'bijli': 'Utilities',
      'पानी': 'Utilities',
      'વીજળી': 'Utilities',
      'બિલ': 'Utilities',
      'medicine': 'Healthcare',
      'hospital': 'Healthcare',
      'dawai': 'Healthcare',
      'दवा': 'Healthcare',
      'દવા': 'Healthcare',
      'school': 'Education',
      'college': 'Education',
      'fees': 'Education',
      'padhai': 'Education',
      'फीस': 'Education',
      'શાળા': 'Education',
      'salary': 'Income',
      'bonus': 'Income',
      'tankhwa': 'Income',
      'वेतन': 'Income',
      'પગાર': 'Income',
    };

    for (final entry in keywordToCategory.entries) {
      if (text.contains(entry.key)) return entry.value;
    }

    final available = CategoryIcons.getAllCategories().keys
        .map((cat) => cat.toLowerCase())
        .toSet();
    for (final cat in available) {
      if (text.contains(cat)) {
        final exact = CategoryIcons.getAllCategories().keys.firstWhere(
          (element) => element.toLowerCase() == cat,
          orElse: () => _selectedCategory,
        );
        return exact;
      }
    }

    return type == TransactionType.income ? 'Income' : _selectedCategory;
  }

  bool get _canSave {
    final text = _amountController.text;
    if (text.isEmpty) return false;
    final val = double.tryParse(text);
    return val != null && val > 0;
  }

  Future<void> _saveTransaction() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final uniqueSmsBody =
        'Manually added transaction at ${DateTime.now().toIso8601String()}';

    final transaction = Transaction(
      amount: double.parse(_amountController.text),
      merchantName: _merchantController.text.isNotEmpty
          ? _merchantController.text
          : _selectedCategory,
      category: _selectedCategory,
      type: _selectedType,
      date: dateTime,
      description: _noteController.text.isEmpty ? null : _noteController.text,
      smsBody: uniqueSmsBody,
    );

    final id = await DatabaseHelper.instance.create(transaction);

    if (mounted) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      provider.loadTransactions();
      Navigator.pop(context);

      final typeLabel = _selectedType == TransactionType.income
          ? 'Income'
          : 'Expense';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$typeLabel saved'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await provider.deleteTransaction(id, permanent: true);
            },
          ),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _showAllCategories() {
    final cs = Theme.of(context).colorScheme;
    final allCats = CategoryIcons.getAllCategories();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All Categories',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: allCats.length,
                  itemBuilder: (_, idx) {
                    final cat = allCats.keys.elementAt(idx);
                    final icon = allCats.values.elementAt(idx);
                    final isSelected = _selectedCategory == cat;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: cs.primary, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 24,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurface.withOpacity(0.7),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? cs.primary
                                    : cs.onSurface.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isExpense = _selectedType == TransactionType.expense;
    final typeColor = isExpense ? cs.expense : cs.income;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isExpense ? 'Add Expense' : 'Add Income'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── Expense / Income Toggle ──
            Center(
              child: SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  setState(() => _selectedType = set.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: typeColor.withOpacity(
                    isDark ? 0.2 : 0.12,
                  ),
                  selectedForegroundColor: typeColor,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _voiceLocales.map((locale) {
                      return ChoiceChip(
                        label: Text(locale.label),
                        selected: _selectedVoiceLocaleId == locale.id,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() => _selectedVoiceLocaleId = locale.id);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _voiceText.isNotEmpty
                              ? _voiceText
                              : 'Tap mic and speak naturally. Example: "Rent 12000 Rahul ko" or "Mane 700 malyu"',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: _toggleVoiceInput,
                        icon: Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        ),
                        tooltip: _isListening ? 'Stop listening' : 'Speak transaction',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No need to say expense/income. App infers intent in English, Hindi, Gujarati.',
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Hero Amount Input ──
            Center(
              child: IntrinsicWidth(
                child: TextField(
                  controller: _amountController,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface,
                    letterSpacing: -1,
                  ),
                  decoration: InputDecoration(
                    prefixText: '${CurrencyHelper.symbol} ',
                    prefixStyle: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurface,
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: cs.outlineVariant,
                    ),
                    border: InputBorder.none,
                    constraints: const BoxConstraints(minWidth: 120),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Category Chips (horizontal scroll) ──
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickCategories.length + 1, // +1 for "More"
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == _quickCategories.length) {
                    // "More" chip
                    return FilterChip(
                      label: const Text('More'),
                      avatar: const Icon(Icons.expand_more_rounded, size: 18),
                      onSelected: (_) => _showAllCategories(),
                      side: BorderSide(color: cs.outlineVariant),
                    );
                  }

                  final cat = _quickCategories[index];
                  final isSelected = _selectedCategory == cat;
                  final catIcon = CategoryIcons.getIcon(cat);

                  return FilterChip(
                    selected: isSelected,
                    label: Text(cat),
                    avatar: Icon(catIcon, size: 16),
                    selectedColor: cs.primaryContainer,
                    checkmarkColor: cs.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    side: isSelected
                        ? BorderSide(color: cs.primary.withOpacity(0.5))
                        : BorderSide(color: cs.outlineVariant),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Merchant / Note Field ──
            TextField(
              controller: _merchantController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.store_rounded),
                hintText: 'Merchant name (optional)',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.notes_rounded),
                hintText: 'Note (optional)',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Date + Time Chips ──
            Row(
              children: [
                Expanded(
                  child: _buildDateTimeChip(
                    icon: Icons.calendar_today_rounded,
                    label: _isToday(_selectedDate)
                        ? 'Today'
                        : DateFormat('d MMM').format(_selectedDate),
                    onTap: _pickDate,
                    cs: cs,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateTimeChip(
                    icon: Icons.access_time_rounded,
                    label: _selectedTime.format(context),
                    onTap: _pickTime,
                    cs: cs,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Save Button ──
            FilledButton(
              onPressed: _canSave ? _saveTransaction : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isExpense ? 'Save Expense' : 'Save Income',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme cs,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : cs.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _VoiceParseResult {
  final double? amount;
  final TransactionType? type;
  final String? category;
  final String? merchant;
  final String? note;

  const _VoiceParseResult({
    this.amount,
    this.type,
    this.category,
    this.merchant,
    this.note,
  });
}

class _VoiceLocaleOption {
  final String id;
  final String label;

  const _VoiceLocaleOption({required this.id, required this.label});
}
