import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Achievement & Gamification Service
///
/// XP system, levels, badges, and milestones that make
/// personal finance addictive. No server required.
///
/// XP SOURCES:
///  - Adding transactions: +5 XP
///  - Daily login: +10 XP
///  - No-spend day: +20 XP
///  - Weekly budget met: +50 XP
///  - Streaks: multiplier
///
/// LEVELS:
///  Level 1-5: Beginner → Level 50+: Legend
///
/// BADGES (20+):
///  Categories: Tracking, Saving, Streaks, Milestones, Special
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum BadgeCategory { tracking, saving, streak, milestone, special }

enum BadgeRarity { common, uncommon, rare, epic, legendary }

class Badge {
  final String id;
  final IconData icon;
  final String name;
  final String description;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progress; // 0.0 - 1.0 (for partially completed)
  final String? progressLabel; // "15/30 days"

  const Badge({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.isUnlocked,
    this.unlockedAt,
    required this.progress,
    this.progressLabel,
  });
}

class LevelInfo {
  final int level;
  final String title;
  final IconData icon;
  final int currentXP;
  final int xpForNextLevel;
  final double progress; // 0.0 - 1.0

  const LevelInfo({
    required this.level,
    required this.title,
    required this.icon,
    required this.currentXP,
    required this.xpForNextLevel,
    required this.progress,
  });
}

class AchievementStats {
  final int totalXP;
  final LevelInfo level;
  final List<Badge> badges;
  final List<Badge> recentUnlocks; // last 3 unlocked badges
  final int unlockedCount;
  final int totalBadges;
  final int currentStreak;
  final int longestStreak;
  final int noSpendDays;
  final int totalTransactions;
  final double completionPercent; // overall badge completion
  final String nextMilestone;

  const AchievementStats({
    required this.totalXP,
    required this.level,
    required this.badges,
    required this.recentUnlocks,
    required this.unlockedCount,
    required this.totalBadges,
    required this.currentStreak,
    required this.longestStreak,
    required this.noSpendDays,
    required this.totalTransactions,
    required this.completionPercent,
    required this.nextMilestone,
  });
}

class AchievementService {
  // XP per level = base * level^1.5
  static const int _baseXP = 100;

  static final List<Map<String, dynamic>> _levelTitles = [
    {'title': 'Newcomer', 'icon': Icons.eco_rounded}, // 1-4
    {'title': 'Budgeter', 'icon': Icons.assignment_rounded}, // 5-9
    {'title': 'Saver', 'icon': Icons.savings_rounded}, // 10-14
    {'title': 'Planner', 'icon': Icons.bar_chart_rounded}, // 15-19
    {'title': 'Analyst', 'icon': Icons.search_rounded}, // 20-24
    {'title': 'Optimizer', 'icon': Icons.bolt_rounded}, // 25-29
    {'title': 'Strategist', 'icon': Icons.track_changes_rounded}, // 30-34
    {'title': 'Expert', 'icon': Icons.military_tech_rounded}, // 35-39
    {'title': 'Master', 'icon': Icons.workspace_premium_rounded}, // 40-44
    {'title': 'Legend', 'icon': Icons.star_rounded}, // 45-49
    {'title': 'DhanPath Elite', 'icon': Icons.diamond_rounded}, // 50+
  ];

  /// Calculate complete achievement stats from transaction history
  static AchievementStats calculate(List<Transaction> allTransactions) {
    final now = DateTime.now();
    final active = allTransactions.where((t) => !t.isDeleted).toList();
    final expenses = active
        .where((t) => t.type == TransactionType.expense)
        .toList();
    final incomes = active
        .where((t) => t.type == TransactionType.income)
        .toList();

    // ── Calculate XP ──
    int xp = 0;

    // XP from transactions (5 per transaction, cap at 500/day)
    final txnsByDate = <String, int>{};
    for (final t in active) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      txnsByDate[key] = (txnsByDate[key] ?? 0) + 1;
    }
    for (final count in txnsByDate.values) {
      xp += (count * 5).clamp(0, 500);
    }

    // XP from no-spend days (20 per day)
    final first = active.isEmpty
        ? now
        : active.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final daysSinceFirst = now.difference(first).inDays + 1;
    final expenseDates = <String>{};
    for (final t in expenses) {
      expenseDates.add('${t.date.year}-${t.date.month}-${t.date.day}');
    }

    int noSpendDays = 0;
    for (int i = 0; i < daysSinceFirst; i++) {
      final d = first.add(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';
      if (!expenseDates.contains(key)) noSpendDays++;
    }
    xp += noSpendDays * 20;

    // XP from streaks
    final currentStreak = _calcCurrentStreak(active, now);
    final longestStreak = _calcLongestStreak(active);
    xp += currentStreak * 10; // 10 XP per streak day
    xp += longestStreak * 5; // Bonus for longest streak

    // ── Level ──
    final level = _calcLevel(xp);

    // ── Badges ──
    final badges = _evaluateBadges(
      active,
      expenses,
      incomes,
      now,
      noSpendDays,
      currentStreak,
      longestStreak,
      xp,
    );

    final unlocked = badges.where((b) => b.isUnlocked).toList();
    unlocked.sort(
      (a, b) => (b.unlockedAt ?? now).compareTo(a.unlockedAt ?? now),
    );
    final recentUnlocks = unlocked.take(3).toList();

    // Next milestone
    final nextBadge = badges
        .where((b) => !b.isUnlocked && b.progress > 0)
        .toList();
    nextBadge.sort((a, b) => b.progress.compareTo(a.progress));
    final nextMilestone = nextBadge.isNotEmpty
        ? '${nextBadge.first.name} — ${(nextBadge.first.progress * 100).round()}% complete'
        : 'Keep tracking to unlock more badges!';

    return AchievementStats(
      totalXP: xp,
      level: level,
      badges: badges,
      recentUnlocks: recentUnlocks,
      unlockedCount: unlocked.length,
      totalBadges: badges.length,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      noSpendDays: noSpendDays,
      totalTransactions: active.length,
      completionPercent: badges.isEmpty ? 0 : unlocked.length / badges.length,
      nextMilestone: nextMilestone,
    );
  }

  static LevelInfo _calcLevel(int xp) {
    int level = 1;
    int remaining = xp;

    while (true) {
      final required = (_baseXP * _pow(level.toDouble(), 1.5)).round();
      if (remaining < required) {
        final titleIdx = ((level - 1) / 5).floor().clamp(
          0,
          _levelTitles.length - 1,
        );
        return LevelInfo(
          level: level,
          title: _levelTitles[titleIdx]['title']!,
          icon: _levelTitles[titleIdx]['icon']! as IconData,
          currentXP: xp,
          xpForNextLevel: required,
          progress: remaining / required,
        );
      }
      remaining -= required;
      level++;
    }
  }

  static int _calcCurrentStreak(List<Transaction> txns, DateTime now) {
    if (txns.isEmpty) return 0;

    int streak = 0;
    var check = DateTime(now.year, now.month, now.day);

    while (true) {
      final hasTxn = txns.any(
        (t) =>
            t.date.year == check.year &&
            t.date.month == check.month &&
            t.date.day == check.day,
      );

      if (!hasTxn && streak > 0) break; // Allow today to have no transactions
      if (!hasTxn && streak == 0) {
        // Check yesterday
        check = check.subtract(const Duration(days: 1));
        continue;
      }

      streak++;
      check = check.subtract(const Duration(days: 1));
    }

    return streak;
  }

  static int _calcLongestStreak(List<Transaction> txns) {
    if (txns.isEmpty) return 0;

    final dates =
        txns
            .map((t) => '${t.date.year}-${t.date.month}-${t.date.day}')
            .toSet()
            .toList()
          ..sort();
    if (dates.isEmpty) return 0;

    int longest = 1, current = 1;

    for (int i = 1; i < dates.length; i++) {
      final prev = _parseDate(dates[i - 1]);
      final curr = _parseDate(dates[i]);
      if (curr.difference(prev).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }

    return longest;
  }

  static DateTime _parseDate(String s) {
    final parts = s.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static List<Badge> _evaluateBadges(
    List<Transaction> all,
    List<Transaction> expenses,
    List<Transaction> incomes,
    DateTime now,
    int noSpendDays,
    int currentStreak,
    int longestStreak,
    int totalXP,
  ) {
    final badges = <Badge>[];
    final totalTxns = all.length;
    final totalExpense = expenses.fold(0.0, (s, t) => s + t.amount);
    final totalIncome = incomes.fold(0.0, (s, t) => s + t.amount);
    final savingsRate = totalIncome > 0
        ? (totalIncome - totalExpense) / totalIncome
        : 0.0;

    // ── TRACKING BADGES ──

    badges.add(
      _badge(
        id: 'first_entry',
        icon: Icons.edit_rounded,
        name: 'First Entry',
        desc: 'Track your first transaction',
        cat: BadgeCategory.tracking,
        rarity: BadgeRarity.common,
        unlocked: totalTxns >= 1,
        progress: (totalTxns / 1).clamp(0, 1).toDouble(),
        label: '$totalTxns/1',
      ),
    );

    badges.add(
      _badge(
        id: 'tracker_10',
        icon: Icons.bar_chart_rounded,
        name: 'Getting Started',
        desc: 'Track 10 transactions',
        cat: BadgeCategory.tracking,
        rarity: BadgeRarity.common,
        unlocked: totalTxns >= 10,
        progress: (totalTxns / 10).clamp(0, 1).toDouble(),
        label: '$totalTxns/10',
      ),
    );

    badges.add(
      _badge(
        id: 'tracker_50',
        icon: Icons.trending_up_rounded,
        name: 'Habit Forming',
        desc: 'Track 50 transactions',
        cat: BadgeCategory.tracking,
        rarity: BadgeRarity.uncommon,
        unlocked: totalTxns >= 50,
        progress: (totalTxns / 50).clamp(0, 1).toDouble(),
        label: '$totalTxns/50',
      ),
    );

    badges.add(
      _badge(
        id: 'tracker_200',
        icon: Icons.local_fire_department_rounded,
        name: 'Data Driven',
        desc: 'Track 200 transactions',
        cat: BadgeCategory.tracking,
        rarity: BadgeRarity.rare,
        unlocked: totalTxns >= 200,
        progress: (totalTxns / 200).clamp(0, 1).toDouble(),
        label: '$totalTxns/200',
      ),
    );

    badges.add(
      _badge(
        id: 'tracker_500',
        icon: Icons.star_rounded,
        name: 'Finance Nerd',
        desc: 'Track 500 transactions',
        cat: BadgeCategory.tracking,
        rarity: BadgeRarity.epic,
        unlocked: totalTxns >= 500,
        progress: (totalTxns / 500).clamp(0, 1).toDouble(),
        label: '$totalTxns/500',
      ),
    );

    badges.add(
      _badge(
        id: 'tracker_1000',
        icon: Icons.diamond_rounded,
        name: 'Legendary Tracker',
        desc: 'Track 1000 transactions',
        cat: BadgeCategory.tracking,
        rarity: BadgeRarity.legendary,
        unlocked: totalTxns >= 1000,
        progress: (totalTxns / 1000).clamp(0, 1).toDouble(),
        label: '$totalTxns/1000',
      ),
    );

    // ── SAVING BADGES ──

    badges.add(
      _badge(
        id: 'no_spend_7',
        icon: Icons.beach_access_rounded,
        name: 'Minimalist Week',
        desc: '7 no-spend days total',
        cat: BadgeCategory.saving,
        rarity: BadgeRarity.common,
        unlocked: noSpendDays >= 7,
        progress: (noSpendDays / 7).clamp(0, 1).toDouble(),
        label: '$noSpendDays/7',
      ),
    );

    badges.add(
      _badge(
        id: 'no_spend_30',
        icon: Icons.self_improvement_rounded,
        name: 'Zen Saver',
        desc: '30 no-spend days total',
        cat: BadgeCategory.saving,
        rarity: BadgeRarity.uncommon,
        unlocked: noSpendDays >= 30,
        progress: (noSpendDays / 30).clamp(0, 1).toDouble(),
        label: '$noSpendDays/30',
      ),
    );

    badges.add(
      _badge(
        id: 'savings_10',
        icon: Icons.savings_outlined,
        name: 'Piggy Bank',
        desc: 'Maintain 10%+ savings rate',
        cat: BadgeCategory.saving,
        rarity: BadgeRarity.common,
        unlocked: savingsRate >= 0.10,
        progress: (savingsRate / 0.10).clamp(0, 1).toDouble(),
        label: '${(savingsRate * 100).round()}%/10%',
      ),
    );

    badges.add(
      _badge(
        id: 'savings_20',
        icon: Icons.account_balance_wallet_rounded,
        name: 'Smart Saver',
        desc: 'Maintain 20%+ savings rate',
        cat: BadgeCategory.saving,
        rarity: BadgeRarity.uncommon,
        unlocked: savingsRate >= 0.20,
        progress: (savingsRate / 0.20).clamp(0, 1).toDouble(),
        label: '${(savingsRate * 100).round()}%/20%',
      ),
    );

    badges.add(
      _badge(
        id: 'savings_40',
        icon: Icons.account_balance_rounded,
        name: 'Wealth Builder',
        desc: 'Maintain 40%+ savings rate',
        cat: BadgeCategory.saving,
        rarity: BadgeRarity.epic,
        unlocked: savingsRate >= 0.40,
        progress: (savingsRate / 0.40).clamp(0, 1).toDouble(),
        label: '${(savingsRate * 100).round()}%/40%',
      ),
    );

    // ── STREAK BADGES ──

    badges.add(
      _badge(
        id: 'streak_7',
        icon: Icons.local_fire_department_rounded,
        name: 'Week Warrior',
        desc: '7-day tracking streak',
        cat: BadgeCategory.streak,
        rarity: BadgeRarity.common,
        unlocked: longestStreak >= 7,
        progress: (longestStreak / 7).clamp(0, 1).toDouble(),
        label: '$longestStreak/7 days',
      ),
    );

    badges.add(
      _badge(
        id: 'streak_30',
        icon: Icons.bolt_rounded,
        name: 'Monthly Master',
        desc: '30-day tracking streak',
        cat: BadgeCategory.streak,
        rarity: BadgeRarity.rare,
        unlocked: longestStreak >= 30,
        progress: (longestStreak / 30).clamp(0, 1).toDouble(),
        label: '$longestStreak/30 days',
      ),
    );

    badges.add(
      _badge(
        id: 'streak_100',
        icon: Icons.volcano_rounded,
        name: 'Unstoppable',
        desc: '100-day tracking streak',
        cat: BadgeCategory.streak,
        rarity: BadgeRarity.legendary,
        unlocked: longestStreak >= 100,
        progress: (longestStreak / 100).clamp(0, 1).toDouble(),
        label: '$longestStreak/100 days',
      ),
    );

    // ── MILESTONE BADGES ──

    final uniqueMerchants = expenses
        .map((t) => t.merchantName.toLowerCase().trim())
        .toSet()
        .length;
    badges.add(
      _badge(
        id: 'merchants_20',
        icon: Icons.store_rounded,
        name: 'Explorer',
        desc: 'Transact with 20+ different merchants',
        cat: BadgeCategory.milestone,
        rarity: BadgeRarity.uncommon,
        unlocked: uniqueMerchants >= 20,
        progress: (uniqueMerchants / 20).clamp(0, 1).toDouble(),
        label: '$uniqueMerchants/20',
      ),
    );

    final uniqueCategories = expenses.map((t) => t.category).toSet().length;
    badges.add(
      _badge(
        id: 'categories_8',
        icon: Icons.palette_rounded,
        name: 'Diversified',
        desc: 'Spend across 8+ categories',
        cat: BadgeCategory.milestone,
        rarity: BadgeRarity.uncommon,
        unlocked: uniqueCategories >= 8,
        progress: (uniqueCategories / 8).clamp(0, 1).toDouble(),
        label: '$uniqueCategories/8',
      ),
    );

    // ── SPECIAL BADGES ──

    badges.add(
      _badge(
        id: 'xp_1000',
        icon: Icons.star_outline_rounded,
        name: 'Rising Star',
        desc: 'Earn 1,000 XP',
        cat: BadgeCategory.special,
        rarity: BadgeRarity.common,
        unlocked: totalXP >= 1000,
        progress: (totalXP / 1000).clamp(0, 1).toDouble(),
        label: '$totalXP/1000 XP',
      ),
    );

    badges.add(
      _badge(
        id: 'xp_5000',
        icon: Icons.star_rounded,
        name: 'All Star',
        desc: 'Earn 5,000 XP',
        cat: BadgeCategory.special,
        rarity: BadgeRarity.rare,
        unlocked: totalXP >= 5000,
        progress: (totalXP / 5000).clamp(0, 1).toDouble(),
        label: '$totalXP/5000 XP',
      ),
    );

    badges.add(
      _badge(
        id: 'xp_10000',
        icon: Icons.diamond_rounded,
        name: 'Diamond Club',
        desc: 'Earn 10,000 XP',
        cat: BadgeCategory.special,
        rarity: BadgeRarity.legendary,
        unlocked: totalXP >= 10000,
        progress: (totalXP / 10000).clamp(0, 1).toDouble(),
        label: '$totalXP/10000 XP',
      ),
    );

    // Income tracker
    final hasIncome = incomes.isNotEmpty;
    badges.add(
      _badge(
        id: 'first_income',
        icon: Icons.attach_money_rounded,
        name: 'Income Logged',
        desc: 'Log your first income',
        cat: BadgeCategory.tracking,
        rarity: BadgeRarity.common,
        unlocked: hasIncome,
        progress: hasIncome ? 1.0 : 0.0,
        label: hasIncome ? '1/1' : '0/1',
      ),
    );

    return badges;
  }

  static Badge _badge({
    required String id,
    required IconData icon,
    required String name,
    required String desc,
    required BadgeCategory cat,
    required BadgeRarity rarity,
    required bool unlocked,
    required double progress,
    String? label,
  }) {
    return Badge(
      id: id,
      icon: icon,
      name: name,
      description: desc,
      category: cat,
      rarity: rarity,
      isUnlocked: unlocked,
      unlockedAt: unlocked ? DateTime.now() : null,
      progress: progress,
      progressLabel: label,
    );
  }

  static double _pow(double base, double exp) {
    // Simple power function without dart:math
    if (exp == 0) return 1;
    if (exp == 1) return base;
    if (exp == 1.5) return base * _sqrt(base);
    // Fallback for other exponents
    double result = 1;
    for (int i = 0; i < exp.floor(); i++) {
      result *= base;
    }
    return result;
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }
}
