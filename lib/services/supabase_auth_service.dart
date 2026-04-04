import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  static final SupabaseAuthService instance = SupabaseAuthService._();
  SupabaseAuthService._();

  bool _initialized = false;
  bool _configured = false;

  bool get isConfigured => _configured;
  bool get isInitialized => _initialized;

  User? get currentUser {
    if (!_initialized || !_configured) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  Session? get currentSession {
    if (!_initialized || !_configured) return null;
    return Supabase.instance.client.auth.currentSession;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const supabaseUrlPrimary = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKeyPrimary = String.fromEnvironment('SUPABASE_ANON_KEY');
    const supabaseUrlFallback = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL');
    const supabaseAnonKeyFallback = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY');

    final supabaseUrl = supabaseUrlPrimary.isNotEmpty
        ? supabaseUrlPrimary
        : supabaseUrlFallback;
    final supabaseAnonKey = supabaseAnonKeyPrimary.isNotEmpty
        ? supabaseAnonKeyPrimary
        : supabaseAnonKeyFallback;

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      _configured = false;
      _initialized = true;
      return;
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    _configured = true;
    _initialized = true;
  }

  Future<void> sendOtp({required String email}) async {
    if (!_configured) {
      throw StateError('Supabase is not configured.');
    }
    await Supabase.instance.client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: true,
    );
  }

  Future<void> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    if (!_configured) {
      throw StateError('Supabase is not configured.');
    }

    final response = await Supabase.instance.client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim().toLowerCase(),
      token: otpCode.trim(),
    );

    if (response.session == null) {
      throw StateError('Verification failed. Please request a new code.');
    }

    await Supabase.instance.client.from('profiles').upsert({
      'id': response.user?.id,
      'email': response.user?.email,
    });
  }

  Future<void> signOut() async {
    if (!_configured) return;
    await Supabase.instance.client.auth.signOut();
  }

  String? get currentUserEmail {
    return currentUser?.email?.trim().toLowerCase();
  }

  /// User-facing text for sign-in errors (rate limits, etc.).
  static String describeAuthError(Object error) {
    if (error is AuthException) {
      final m = error.message.toLowerCase();
      final code = (error.code ?? '').toLowerCase();
      if (error.statusCode == '429' ||
          m.contains('rate limit') ||
          m.contains('too many') ||
          code.contains('rate') ||
          m.contains('email rate')) {
        return 'Too many sign-in emails for now. Wait about an hour, or use the '
            '6-digit code from an email you already received.\n\n'
            'Tip: In Supabase go to Authentication → add Custom SMTP (e.g. Resend) '
            'for higher limits. Avoid tapping "Send" many times while testing.';
      }
      return error.message;
    }
    final s = error.toString().toLowerCase();
    if (s.contains('rate') || s.contains('429') || s.contains('too many')) {
      return describeAuthError(
        AuthException(error.toString(), statusCode: '429'),
      );
    }
    return error.toString();
  }
}
