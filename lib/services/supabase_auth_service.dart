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

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!_configured) {
      throw StateError('Supabase is not configured.');
    }

    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    if (response.user == null) {
      throw StateError('Sign-in failed. Please check your credentials.');
    }

    await _upsertUserProfile(
      userId: response.user!.id,
      email: response.user!.email ?? email,
    );
    return response;
  }

  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    if (!_configured) {
      throw StateError('Supabase is not configured.');
    }

    final response = await Supabase.instance.client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final user = response.user;
    if (user != null && user.email != null) {
      await _upsertUserProfile(userId: user.id, email: user.email!);
    }

    return response;
  }

  Future<AuthResponse> authenticateWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      return await signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      final shouldCreate =
          message.contains('invalid login credentials') ||
          message.contains('email not confirmed') ||
          message.contains('user not found') ||
          message.contains('invalid email or password');

      if (!shouldCreate) {
        rethrow;
      }
    }

    final signUp = await signUpWithPassword(
      email: normalizedEmail,
      password: password,
    );

    // If email confirmation is required, session may be null.
    if (signUp.session == null) {
      throw StateError(
        'Account created. Please verify your email, then sign in again.',
      );
    }

    return signUp;
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

  Future<void> _upsertUserProfile({
    required String userId,
    required String email,
  }) async {
    await Supabase.instance.client.from('users').upsert({
      'id': userId,
      'email': email.trim().toLowerCase(),
      'name': email.split('@').first,
    });
  }

  Future<void> signOut() async {
    if (!_configured) return;
    await Supabase.instance.client.auth.signOut();
  }

  String? get currentUserEmail {
    return currentUser?.email?.trim().toLowerCase();
  }
}
