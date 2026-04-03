import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../services/spending_story_service.dart';
import '../theme/app_theme.dart';
import '../services/user_preferences_service.dart';

/// Instagram-story-style monthly spending summary
class SpendingStoryScreen extends StatefulWidget {
  const SpendingStoryScreen({super.key});

  @override
  State<SpendingStoryScreen> createState() => _SpendingStoryScreenState();
}

class _SpendingStoryScreenState extends State<SpendingStoryScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentPage = 0;
  MonthlyStory? _story;

  // Gradient pairs for each card
  static const _gradients = [
    [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], // headline
    [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)], // top cat
    [Color(0xFF2D0036), Color(0xFF40004D), Color(0xFF1A0025)], // merchant
    [Color(0xFF1B1B1B), Color(0xFF2E2E2E), Color(0xFF1A1A1A)], // comparison
    [Color(0xFF0D1B2A), Color(0xFF1B2838), Color(0xFF2A3D50)], // biggest day
    [Color(0xFF1A1A1A), Color(0xFF2E2E2E), Color(0xFF1A1A1A)], // no-spend
    [Color(0xFF0B3D0B), Color(0xFF145214), Color(0xFF1A6B1A)], // savings
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _nextPage();
            }
          });

    WidgetsBinding.instance.addPostFrameCallback((_) => _buildStory());
  }

  void _buildStory() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final now = DateTime.now();

    // Get all transactions
    final all = provider.transactions;

    // Last month transactions for comparison
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    final lastMonthTxns = all
        .where(
          (t) =>
              !t.isDeleted &&
              !t.date.isBefore(lastMonth) &&
              t.date.isBefore(lastMonthEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    final story = SpendingStoryService.generate(
      allTransactions: all,
      month: now,
      lastMonthTransactions: lastMonthTxns,
    );

    setState(() {
      _story = story;
    });
    _progressController.forward();
  }

  void _nextPage() {
    if (_story == null) return;
    if (_currentPage < _story!.insights.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Loop back or stay on last
      _progressController.stop();
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _progressController.reset();
    _progressController.forward();
  }

  void _onTapLeft() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTapRight() {
    if (_story != null && _currentPage < _story!.insights.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_story == null || _story!.insights.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: const CloseButton(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            'Not enough data for a story yet.\nKeep tracking!',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final insights = _story!.insights;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Page View (swipe between insight cards) ──
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: insights.length,
            itemBuilder: (context, index) {
              final insight = insights[index];
              final gradient = _gradients[index % _gradients.length];
              return _InsightCard(
                insight: insight,
                story: _story!,
                gradientColors: gradient,
                isFirst: index == 0,
                isLast: index == insights.length - 1,
                currency: CurrencyHelper.symbol,
              );
            },
          ),

          // ── Tap zones (left / right) ──
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _onTapLeft,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _onTapRight,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ],
            ),
          ),

          // ── Progress bars (Instagram-style) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: List.generate(insights.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _StoryProgressBar(
                      isCompleted: i < _currentPage,
                      isCurrent: i == _currentPage,
                      animation: _progressController,
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Close button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // ── Month label ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 16,
            child: Text(
              _story!.monthLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single story page — gradient background + big icon + text
class _InsightCard extends StatelessWidget {
  final StoryInsight insight;
  final MonthlyStory story;
  final List<Color> gradientColors;
  final bool isFirst;
  final bool isLast;
  final String currency;

  const _InsightCard({
    required this.insight,
    required this.story,
    required this.gradientColors,
    required this.isFirst,
    required this.isLast,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Big icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Icon(
                  insight.icon,
                  size: size.width * 0.2,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  insight.title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Body text — the human-readable insight
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  insight.body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Show mini stats on first card
              if (isFirst) ...[
                const SizedBox(height: 48),
                _MiniStatsRow(story: story, currency: currency),
              ],

              // Show "DhanPath" branding on last card
              if (isLast) ...[const SizedBox(height: 48), _BrandFooter()],
            ],
          ),
        ),
      ),
    );
  }
}

/// Three mini stat pills on the headline card
class _MiniStatsRow extends StatelessWidget {
  final MonthlyStory story;
  final String currency;

  const _MiniStatsRow({required this.story, required this.currency});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatPill(
            label: 'INCOME',
            value: '$currency${_shortFormat(story.totalIncome)}',
            color: AppTheme.incomeDark,
          ),
          _StatPill(
            label: 'SPENT',
            value: '$currency${_shortFormat(story.totalExpenses)}',
            color: AppTheme.expenseDark,
          ),
          _StatPill(
            label: 'TXN',
            value: '${story.transactionCount}',
            color: AppTheme.brandPurple,
          ),
        ],
      ),
    );
  }

  static String _shortFormat(double amount) {
    if (amount >= 10000000)
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

/// A single stat pill
class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// DhanPath branding footer on the last card
class _BrandFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.brandGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.brandGreen.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 18,
                  color: AppTheme.brandGreen,
                ),
                SizedBox(width: 8),
                Text(
                  'DhanPath',
                  style: TextStyle(
                    color: AppTheme.brandGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your money, your story',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Instagram-style segmented progress bar
class _StoryProgressBar extends StatelessWidget {
  final bool isCompleted;
  final bool isCurrent;
  final Animation<double> animation;

  const _StoryProgressBar({
    required this.isCompleted,
    required this.isCurrent,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: isCompleted
            ? Container(color: Colors.white)
            : isCurrent
            ? AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: animation.value,
                    child: Container(color: Colors.white),
                  );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
