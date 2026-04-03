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

    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

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
}
