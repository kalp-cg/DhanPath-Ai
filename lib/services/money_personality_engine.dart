import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Money Personality Engine
///
/// Behavioral finance personality analysis based on actual
/// spending patterns. Not a quiz — it's data-driven.
///
/// PERSONALITY TYPES (5):
///  1. Guardian — cautious, high savings rate, consistent
///  2. Strategist — planned, goal-oriented, balanced
///  3. Spontaneous — impulsive, variable, experience-driven
///  4. Achiever — income-focused, growth-oriented
///  5. Social Spender — generous, social, dining/entertainment heavy
///
/// TRAITS (scored 0-100):
///  - Discipline: consistency in spending
///  - Generosity: social/gift spending ratio
///  - Risk Tolerance: investment ratio
///  - Impulsiveness: spending variance
///  - Frugality: savings rate
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum PersonalityType {
  guardian,
  strategist,
  spontaneous,
  achiever,
  socialSpender,
}

class PersonalityTrait {
  final String name;
  final IconData icon;
  final int score; // 0-100
  final String description;

  const PersonalityTrait({
    required this.name,
    required this.icon,
    required this.score,
    required this.description,
  });
}

class MoneyPersonality {
  final PersonalityType type;
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final List<PersonalityTrait> traits;
  final List<String> strengths;
  final List<String> watchOuts;
  final String financialMantra;
  final double confidenceScore; // How confident we are in the analysis (0-1)
  final DateTime analyzedAt;
  final int transactionsAnalyzed;

  const MoneyPersonality({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.traits,
    required this.strengths,
    required this.watchOuts,
    required this.financialMantra,
    required this.confidenceScore,
    required this.analyzedAt,
    required this.transactionsAnalyzed,
  });

  // Backward-compatible aliases for older callers/tests.
  String get personalityType => title;
  String get mantra => financialMantra;
}

class MoneyPersonalityEngine {
  /// Analyze spending patterns and return a personality profile
  static MoneyPersonality analyze(List<Transaction> allTransactions) {
    final now = DateTime.now();
    final active = allTransactions.where((t) => !t.isDeleted).toList();

    if (active.length < 10) {
      return _insufficientData(now, active.length);
    }

    final expenses = active
        .where((t) => t.type == TransactionType.expense)
        .toList();
    final incomes = active
        .where((t) => t.type == TransactionType.income)
        .toList();
    final investments = active
        .where((t) => t.type == TransactionType.investment)
        .toList();

    // ── Calculate raw scores ──

    final disciplineScore = _calcDiscipline(expenses, now);
    final generosityScore = _calcGenerosity(expenses);
    final riskScore = _calcRiskTolerance(investments, incomes);
    final impulseScore = _calcImpulsiveness(expenses, now);
    final frugalityScore = _calcFrugality(expenses, incomes, now);

    // ── Determine personality type ──
    final type = _determineType(
      discipline: disciplineScore,
      generosity: generosityScore,
      riskTolerance: riskScore,
      impulsiveness: impulseScore,
      frugality: frugalityScore,
    );

    final traits = [
      PersonalityTrait(
        name: 'Discipline',
        icon: Icons.straighten_rounded,
        score: disciplineScore,
        description: _traitDescription('discipline', disciplineScore),
      ),
      PersonalityTrait(
        name: 'Generosity',
        icon: Icons.handshake_rounded,
        score: generosityScore,
        description: _traitDescription('generosity', generosityScore),
      ),
      PersonalityTrait(
        name: 'Risk Tolerance',
        icon: Icons.casino_rounded,
        score: riskScore,
        description: _traitDescription('risk', riskScore),
      ),
      PersonalityTrait(
        name: 'Impulsiveness',
        icon: Icons.bolt_rounded,
        score: impulseScore,
        description: _traitDescription('impulse', impulseScore),
      ),
      PersonalityTrait(
        name: 'Frugality',
        icon: Icons.monetization_on_rounded,
        score: frugalityScore,
        description: _traitDescription('frugality', frugalityScore),
      ),
    ];

    final profile = _buildProfile(type);
    final confidence = _calcConfidence(active.length, expenses.length);

    return MoneyPersonality(
      type: type,
      icon: profile['icon']! as IconData,
      title: profile['title']!,
      subtitle: profile['subtitle']!,
      description: profile['description']!,
      traits: traits,
      strengths: (profile['strengths']! as String).split('|'),
      watchOuts: (profile['watchOuts']! as String).split('|'),
      financialMantra: profile['mantra']!,
      confidenceScore: confidence,
      analyzedAt: now,
      transactionsAnalyzed: active.length,
    );
  }

  // ── Discipline: How consistent is spending week-to-week? ──
  static int _calcDiscipline(List<Transaction> expenses, DateTime now) {
    final last60 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 60))))
        .toList();
    if (last60.length < 5) return 50;

    // Group by week
    final weeklyTotals = <int, double>{};
    for (final t in last60) {
      final weekNum =
          t.date.difference(now.subtract(const Duration(days: 60))).inDays ~/ 7;
      weeklyTotals[weekNum] = (weeklyTotals[weekNum] ?? 0) + t.amount;
    }
    if (weeklyTotals.length < 3) return 50;

    final values = weeklyTotals.values.toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 50;

    final cv = _coefficientOfVariation(values, mean);
    // Low CV = high discipline
    return (100 - (cv * 100).clamp(0, 100)).round();
  }

  // ── Generosity: Social, gift, donation spending ──
  static int _calcGenerosity(List<Transaction> expenses) {
    if (expenses.isEmpty) return 50;

    final socialCats = {'Gift', 'Donation', 'Social', 'Charity'};
    final social = expenses.where(
      (t) => socialCats.any(
        (c) => t.category.toLowerCase().contains(c.toLowerCase()),
      ),
    );
    final socialTotal = social.fold(0.0, (s, t) => s + t.amount);
    final totalExpense = expenses.fold(0.0, (s, t) => s + t.amount);
    if (totalExpense == 0) return 50;

    final ratio = socialTotal / totalExpense;
    return (ratio * 500).clamp(0, 100).round(); // 20% social = 100 score
  }

  // ── Risk Tolerance: Investment ratio ──
  static int _calcRiskTolerance(
    List<Transaction> investments,
    List<Transaction> incomes,
  ) {
    if (incomes.isEmpty) return 30;

    final investTotal = investments.fold(0.0, (s, t) => s + t.amount);
    final incomeTotal = incomes.fold(0.0, (s, t) => s + t.amount);
    if (incomeTotal == 0) return 30;

    final ratio = investTotal / incomeTotal;
    return (ratio * 300).clamp(0, 100).round(); // 33% investing = 100 score
  }

  // ── Impulsiveness: Spending variance day-to-day ──
  static int _calcImpulsiveness(List<Transaction> expenses, DateTime now) {
    final last30 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();
    if (last30.length < 5) return 50;

    final dailyTotals = <String, double>{};
    for (final t in last30) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      dailyTotals[key] = (dailyTotals[key] ?? 0) + t.amount;
    }
    if (dailyTotals.length < 3) return 50;

    final values = dailyTotals.values.toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 50;

    final cv = _coefficientOfVariation(values, mean);
    // High CV = high impulsiveness
    return (cv * 100).clamp(0, 100).round();
  }

  // ── Frugality: Savings rate ──
  static int _calcFrugality(
    List<Transaction> expenses,
    List<Transaction> incomes,
    DateTime now,
  ) {
    final last90 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 90))))
        .toList();
    final last90Income = incomes
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 90))))
        .toList();

    if (last90Income.isEmpty) return 50;

    final expenseTotal = last90.fold(0.0, (s, t) => s + t.amount);
    final incomeTotal = last90Income.fold(0.0, (s, t) => s + t.amount);
    if (incomeTotal == 0) return 50;

    final savingsRate = (incomeTotal - expenseTotal) / incomeTotal;
    return (savingsRate * 200).clamp(0, 100).round(); // 50% savings = 100 score
  }

  // ── Determine personality type from trait scores ──
  static PersonalityType _determineType({
    required int discipline,
    required int generosity,
    required int riskTolerance,
    required int impulsiveness,
    required int frugality,
  }) {
    // Score matrix for each type
    final scores = <PersonalityType, double>{};

    scores[PersonalityType.guardian] =
        frugality * 2.0 + discipline * 1.5 + (100 - impulsiveness) * 1.0;
    scores[PersonalityType.strategist] =
        discipline * 2.0 + riskTolerance * 1.0 + frugality * 1.0;
    scores[PersonalityType.spontaneous] =
        impulsiveness * 2.5 + (100 - discipline) * 1.0 + generosity * 0.5;
    scores[PersonalityType.achiever] =
        riskTolerance * 2.0 + discipline * 1.0 + (100 - frugality) * 0.5;
    scores[PersonalityType.socialSpender] =
        generosity * 2.5 + impulsiveness * 1.0 + (100 - frugality) * 0.5;

    return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  static Map<String, dynamic> _buildProfile(PersonalityType type) {
    switch (type) {
      case PersonalityType.guardian:
        return {
          'icon': Icons.shield_rounded,
          'title': 'The Guardian',
          'subtitle': 'Cautious & Consistent',
          'description':
              'You\'re a natural protector of your finances. You prefer stability over risk, and your consistent spending patterns show strong financial discipline. You\'re the type who reads the fine print.',
          'strengths':
              'Strong savings habit|Consistent spending patterns|Financial emergency readiness|Low debt risk',
          'watchOuts':
              'May miss growth opportunities|Could be too conservative with investments|Might under-enjoy life experiences',
          'mantra': '"Security today builds freedom tomorrow."',
        };
      case PersonalityType.strategist:
        return {
          'icon': Icons.track_changes_rounded,
          'title': 'The Strategist',
          'subtitle': 'Planned & Balanced',
          'description':
              'You approach money like a chess game — always thinking moves ahead. Your balanced approach to spending and saving puts you in a strong financial position. You make money work for you.',
          'strengths':
              'Balanced spending & saving|Goal-oriented financial decisions|Diversified financial approach|Good risk management',
          'watchOuts':
              'Over-analysis can delay action|May miss spontaneous joys|Could be inflexible when plans change',
          'mantra': '"Every rupee has a job. Plan the work, work the plan."',
        };
      case PersonalityType.spontaneous:
        return {
          'icon': Icons.theater_comedy_rounded,
          'title': 'The Spontaneous',
          'subtitle': 'Flexible & Experience-Driven',
          'description':
              'You live in the moment and value experiences over things. Your spending is variable but reflects a rich life. With just a bit more structure, you could have the best of both worlds.',
          'strengths':
              'Rich life experiences|Flexible & adaptable|Open to new opportunities|Values quality of life',
          'watchOuts':
              'Inconsistent savings|Impulse purchases can add up|Emergency fund may be low|Hard to predict monthly expenses',
          'mantra': '"Live fully today, but save a seat for tomorrow."',
        };
      case PersonalityType.achiever:
        return {
          'icon': Icons.emoji_events_rounded,
          'title': 'The Achiever',
          'subtitle': 'Growth-Oriented & Ambitious',
          'description':
              'You see money as a tool for growth. You\'re willing to invest and take calculated risks. Your focus on building wealth shows in your investment choices and income diversification.',
          'strengths':
              'Growth-oriented mindset|Willing to invest for returns|Income diversification|Long-term wealth building',
          'watchOuts':
              'May take excessive risks|Could neglect short-term enjoyment|Emergency buffer might be thin|Overconfidence in returns',
          'mantra': '"Invest in yourself — the returns are unlimited."',
        };
      case PersonalityType.socialSpender:
        return {
          'icon': Icons.festival_rounded,
          'title': 'The Social Spender',
          'subtitle': 'Generous & Community-Driven',
          'description':
              'You value relationships and experiences with others. Your spending reflects a generous heart — you\'re the first to pick up the tab. Building in a savings buffer would make you unstoppable.',
          'strengths':
              'Strong relationships|Generous nature|Rich social life|Values community',
          'watchOuts':
              'Social pressure can increase spending|May neglect personal savings|Gift/dining budget may be high|Hard to say no to plans',
          'mantra':
              '"Generosity starts with being generous to your future self too."',
        };
    }
  }

  static String _traitDescription(String trait, int score) {
    final level = score > 70 ? 'high' : (score > 40 ? 'moderate' : 'low');

    switch (trait) {
      case 'discipline':
        if (level == 'high')
          return 'Your spending is remarkably consistent week-to-week. You rarely deviate from your patterns.';
        if (level == 'moderate')
          return 'You maintain decent spending consistency with occasional splurges.';
        return 'Your spending varies significantly — some weeks high, some low.';
      case 'generosity':
        if (level == 'high')
          return 'You\'re notably generous — social and gift spending is a meaningful part of your budget.';
        if (level == 'moderate')
          return 'You balance personal and social spending well.';
        return 'You spend conservatively on social occasions and gifts.';
      case 'risk':
        if (level == 'high')
          return 'You actively invest a significant portion of your income. Growth-oriented mindset!';
        if (level == 'moderate')
          return 'You invest some but keep most money in safe instruments.';
        return 'You prefer safety over growth — minimal investment activity detected.';
      case 'impulse':
        if (level == 'high')
          return 'Your daily spending varies a lot — some big spending days mixed with quiet ones.';
        if (level == 'moderate')
          return 'Occasional unplanned purchases, but generally controlled.';
        return 'Very controlled spending — you rarely make impulse purchases.';
      case 'frugality':
        if (level == 'high')
          return 'Excellent savings rate! You spend well below your means.';
        if (level == 'moderate')
          return 'Decent savings — room to optimize but not in danger zone.';
        return 'Spending is close to or exceeding income. Building a buffer would help.';
      default:
        return '';
    }
  }

  static double _coefficientOfVariation(List<double> values, double mean) {
    if (mean == 0 || values.length < 2) return 0;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    final stdDev = _sqrt(variance);
    return stdDev / mean;
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }

  static double _calcConfidence(int totalTxns, int expenseTxns) {
    // More data = higher confidence
    // 50+ expenses = 0.9, 20-50 = proportional, <10 = low
    if (totalTxns < 10) return 0.3;
    if (expenseTxns < 20) return 0.5;
    if (expenseTxns < 50) return 0.5 + (expenseTxns - 20) / 30 * 0.4;
    return 0.9;
  }

  static MoneyPersonality _insufficientData(DateTime now, int count) {
    return MoneyPersonality(
      type: PersonalityType.strategist,
      icon: Icons.psychology_rounded,
      title: 'Discovering...',
      subtitle: 'More data needed',
      description:
          'We need at least 10 transactions to analyze your personality. Keep tracking and check back soon!',
      traits: const [
        PersonalityTrait(
          name: 'Discipline',
          icon: Icons.straighten_rounded,
          score: 50,
          description: 'Not enough data yet. Add more transactions.',
        ),
      ],
      strengths: ['You\'ve started tracking — that\'s step one!'],
      watchOuts: ['Add more transactions for accurate analysis'],
      financialMantra:
          '"The journey of a thousand miles begins with a single step."',
      confidenceScore: 0.1,
      analyzedAt: now,
      transactionsAnalyzed: count,
    );
  }
}
