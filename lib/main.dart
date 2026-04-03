import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'theme/app_theme.dart';
import 'providers/transaction_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/student_budget_provider.dart';
import 'providers/savings_goals_provider.dart';
import 'providers/recurring_bills_provider.dart';
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/more_screen.dart';
// Original missing imports end here
import 'screens/app_lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/secure_storage_service.dart';
import 'services/notification_service.dart';
import 'services/smart_notification_engine.dart';
import 'services/user_preferences_service.dart';
import 'widgets/bottom_nav_bar.dart';

void main() async {
  // Global error handler — catches all uncaught async + sync errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('\n\u274c FLUTTER ERROR: ${details.exception}');
        debugPrint('${details.stack}');
      };

      // Catch platform errors
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('\n\u274c PLATFORM ERROR: $error');
        debugPrint('$stack');
        return true;
      };

      // Performance: Enable GPU rendering optimizations
      debugProfileBuildsEnabled = false;
      debugProfilePaintsEnabled = false;

      // Initialize timezone data for notifications
      try {
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (e) {
        debugPrint('Timezone init error: $e');
      }

      // Initialize notification service (non-blocking)
      try {
        await NotificationService().initialize();
        final engine = SmartNotificationEngine();
        await engine.scheduleRecurringNotifications();
        engine.runAllChecks(); // fire-and-forget
      } catch (e) {
        debugPrint('Notification init error: $e');
      }

      // Initialize currency preferences
      try {
        await CurrencyHelper.initialize();
      } catch (e) {
        debugPrint('Currency init error: $e');
      }

      // Use edge-to-edge without deprecated bar color APIs (Android 15+).
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // Smooth portrait orientation
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TransactionProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => StudentBudgetProvider()),
            ChangeNotifierProvider(create: (_) => SavingsGoalsProvider()),
            ChangeNotifierProvider(create: (_) => RecurringBillsProvider()),
          ],
          child: const DhanPathApp(),
        ),
      );
    },
    (error, stack) {
      // Zone-level catch-all for async errors not caught elsewhere
      debugPrint('\n\u274c UNCAUGHT ERROR: $error');
      debugPrint('$stack');
    },
  );
}

class DhanPathApp extends StatelessWidget {
  const DhanPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'DhanPath',
      debugShowCheckedModeBanner: false,
      // Buttery smooth scrolling
      scrollBehavior: const _SmoothScrollBehavior(),
      builder: (context, child) {
        // Clamp text scale to a reasonable range for accessibility
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: child!,
        );
      },
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SmoothPageTransitionBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SmoothPageTransitionBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      themeMode: themeProvider.themeMode,
      home: const SplashScreenWrapper(),
    );
  }
}

/// Wrapper that shows splash screen first, then navigates to OnboardingGuard
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _showSplash = true;

  void _onSplashComplete() {
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }
    return const OnboardingGuard();
  }
}

/// Checks if user has completed onboarding, shows it if not
class OnboardingGuard extends StatefulWidget {
  const OnboardingGuard({super.key});

  @override
  State<OnboardingGuard> createState() => _OnboardingGuardState();
}

class _OnboardingGuardState extends State<OnboardingGuard> {
  bool _isLoading = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final done = await UserPreferencesService().isOnboardingComplete();
      if (mounted) {
        setState(() {
          _needsOnboarding = !done;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Onboarding check error: $e');
      if (mounted) {
        setState(() {
          _needsOnboarding = true;
          _isLoading = false;
        });
      }
    }
  }

  void _onOnboardingComplete() {
    setState(() => _needsOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needsOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }
    return const AppLockGuard();
  }
}

/// Widget that checks if app lock is enabled and shows lock screen if needed
class AppLockGuard extends StatefulWidget {
  const AppLockGuard({super.key});

  @override
  State<AppLockGuard> createState() => _AppLockGuardState();
}

class _AppLockGuardState extends State<AppLockGuard>
    with WidgetsBindingObserver {
  final _secureStorage = SecureStorageService();
  bool _isLocked = true;
  bool _isLoading = true;
  DateTime? _lastUnlockTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock app when resuming from background (if lock is enabled)
    // Skip re-lock if we just unlocked (biometric dialog causes pause/resume cycle)
    if (state == AppLifecycleState.resumed) {
      final lastUnlock = _lastUnlockTime;
      if (lastUnlock != null &&
          DateTime.now().difference(lastUnlock).inSeconds < 3) {
        return; // Within grace period after unlock, don't re-lock
      }
      _checkAndLock();
    }
  }

  Future<void> _checkLockStatus() async {
    try {
      final lockEnabled = await _secureStorage.isAppLockEnabled();
      final pinSet = await _secureStorage.isPinSet();
      if (mounted) {
        setState(() {
          _isLocked = lockEnabled && pinSet;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('App lock check error: $e');
      if (mounted) {
        setState(() {
          _isLocked = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAndLock() async {
    final lockEnabled = await _secureStorage.isAppLockEnabled();
    final pinSet = await _secureStorage.isPinSet();

    if (lockEnabled && pinSet && mounted) {
      setState(() => _isLocked = true);
    }
  }

  void _onUnlock() {
    _lastUnlockTime = DateTime.now();
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLocked) {
      return AppLockScreen(isSettingUp: false, onSuccess: _onUnlock);
    }

    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Screens cached in IndexedStack — instant switching
  final List<Widget> _screens = [
    const HomeScreen(),
    const TransactionsScreen(),
    const InsightsScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all screens alive for instant switching
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            HapticFeedback.selectionClick();
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }
}

/// Buttery smooth scroll physics for the entire app
class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // ClampingScrollPhysics + StretchingOverscrollIndicator = Android 12+ standard.
    // BouncingScrollPhysics conflicts with StretchingOverscrollIndicator causing
    // visual jitter where sections appear to change size during scroll.
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Use standard Material glow — StretchingOverscrollIndicator distorts
    // section sizes visually during overscroll, making widgets appear to
    // resize ("jitter"). GlowingOverscrollIndicator adds a subtle glow
    // without distorting content.
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      child: child,
    );
  }
}

/// Smooth custom page transitions — fast and responsive
class _SmoothPageTransitionBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Snappy Material 3 curve — fast start, smooth deceleration
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Subtle slide + fade for perceived speed
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
