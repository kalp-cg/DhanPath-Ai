import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_preferences_service.dart';
import 'dart:ui';

/// Beautiful onboarding screen — asks name + country/currency
/// Shown only on first launch
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  CountryCurrency? _selectedCountry;
  int _step = 0; // 0 = name, 1 = country
  bool _isSaving = false;
  String _searchQuery = '';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  // Button press animation
  final _buttonScaleNotifier = ValueNotifier<double>(1.0);

  @override
  void initState() {
    super.initState();
    // Smoother spring-based animations
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideCtrl,
            curve: const Cubic(0.34, 1.56, 0.64, 1), // Spring curve
          ),
        );
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _buttonScaleNotifier.dispose();
    super.dispose();
  }

  void _goToCountryStep() {
    if (_nameController.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }
    // Smooth haptic feedback
    HapticFeedback.mediumImpact();
    // Hide keyboard smoothly
    FocusScope.of(context).unfocus();
    _fadeCtrl.reset();
    _slideCtrl.reset();
    setState(() => _step = 1);
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  void _goBack() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    _fadeCtrl.reset();
    _slideCtrl.reset();
    setState(() => _step = 0);
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  Future<void> _finish() async {
    if (_selectedCountry == null) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your country')),
      );
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() => _isSaving = true);
    await UserPreferencesService().saveOnboarding(
      name: _nameController.text.trim(),
      country: _selectedCountry!.country,
      currencyCode: _selectedCountry!.code,
      currencySymbol: _selectedCountry!.symbol,
    );
    await CurrencyHelper.initialize();
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Smooth keyboard resize
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _step == 0
              ? _buildNameStep(cs, isDark)
              : _buildCountryStep(cs, isDark),
        ),
      ),
    );
  }

  // ─── Step 1: Name ───
  Widget _buildNameStep(ColorScheme cs, bool isDark) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Logo / Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 40,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to',
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DhanPath',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your personal finance companion.\nLet\'s set things up in seconds.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'What should we call you?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // Smooth animated text field
              Hero(
                tag: 'name_field',
                child: Material(
                  color: Colors.transparent,
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      letterSpacing: 0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(
                        color: cs.onSurface.withOpacity(0.35),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : cs.primary.withOpacity(0.05),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: cs.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.person_rounded,
                          color: cs.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      // Subtle haptic on typing
                      if (value.isNotEmpty && value.length == 1) {
                        HapticFeedback.selectionClick();
                      }
                    },
                    onSubmitted: (_) => _goToCountryStep(),
                  ),
                ),
              ),
              const Spacer(),
              // Smooth animated continue button
              ValueListenableBuilder<double>(
                valueListenable: _buttonScaleNotifier,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _goToCountryStep,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          elevation: 2,
                          shadowColor: cs.primary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onHover: (isHovered) {
                          _buttonScaleNotifier.value = isHovered ? 1.02 : 1.0;
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(value * 4, 0),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step 2: Country / Currency ───
  Widget _buildCountryStep(ColorScheme cs, bool isDark) {
    final filtered = _searchQuery.isEmpty
        ? CountryCurrency.all
        : CountryCurrency.all
              .where(
                (c) =>
                    c.country.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    c.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    c.symbol.contains(_searchQuery),
              )
              .toList();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _goBack,
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Hi ${_nameController.text.trim()}! 👋',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select your country to set your currency',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(fontSize: 15, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search country or currency...',
                      hintStyle: TextStyle(
                        color: cs.onSurface.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : cs.primary.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: cs.onSurface.withOpacity(0.4),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: cs.onSurface.withOpacity(0.4),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Country list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final c = filtered[index];
                  final isSelected = _selectedCountry?.country == c.country;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCountry = c);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary.withOpacity(isDark ? 0.15 : 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(color: cs.primary.withOpacity(0.4))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(c.flag, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.country,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? cs.primary
                                        : cs.onSurface,
                                  ),
                                ),
                                Text(
                                  '${c.code} (${c.symbol})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: cs.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isSaving ? null : _finish,
                  style: FilledButton.styleFrom(
                    backgroundColor: _selectedCountry != null
                        ? cs.primary
                        : cs.outline,
                    foregroundColor: _selectedCountry != null
                        ? cs.onPrimary
                        : cs.onSurface.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: cs.onPrimary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selectedCountry != null
                                  ? 'Get Started with ${_selectedCountry!.symbol}'
                                  : 'Select a country',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_selectedCountry != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.rocket_launch_rounded, size: 20),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
