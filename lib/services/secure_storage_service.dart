import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

/// Service for securely storing and managing sensitive data like PIN
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Storage keys
  static const String _pinKey = 'user_pin_hash';
  static const String _pinSaltKey = 'user_pin_salt';
  static const String _appLockEnabledKey = 'app_lock_enabled';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _autoLockTimeoutKey = 'auto_lock_timeout';

  /// Generate a random 16-byte salt
  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Hash PIN with salt for secure storage
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(salt + pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Legacy hash without salt (for backward compatibility)
  String _hashPinLegacy(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Set user PIN (hashed with salt)
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hashedPin = _hashPin(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinKey, value: hashedPin);
  }

  /// Verify PIN (supports both salted and legacy unsalted hashes)
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;

    final salt = await _storage.read(key: _pinSaltKey);
    if (salt != null) {
      // New salted verification
      return storedHash == _hashPin(pin, salt);
    }

    // Backward compatibility: verify with legacy unsalted hash
    // If it matches, migrate to salted hash
    if (storedHash == _hashPinLegacy(pin)) {
      await setPin(pin); // Re-hash with salt
      return true;
    }
    return false;
  }

  /// Check if PIN is set
  Future<bool> isPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null;
  }

  /// Delete PIN
  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
  }

  /// App lock settings
  Future<void> setAppLockEnabled(bool enabled) async {
    await _storage.write(key: _appLockEnabledKey, value: enabled.toString());
  }

  Future<bool> isAppLockEnabled() async {
    final value = await _storage.read(key: _appLockEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  /// Auto-lock timeout in seconds (0 = immediate, -1 = never)
  Future<void> setAutoLockTimeout(int seconds) async {
    await _storage.write(key: _autoLockTimeoutKey, value: seconds.toString());
  }

  Future<int> getAutoLockTimeout() async {
    final value = await _storage.read(key: _autoLockTimeoutKey);
    return int.tryParse(value ?? '0') ?? 0; // Default: immediate
  }

  /// Clear all secure data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
