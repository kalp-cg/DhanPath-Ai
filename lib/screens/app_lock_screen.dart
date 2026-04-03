import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_auth_service.dart';

class AppLockScreen extends StatefulWidget {
  final bool isSettingUp; // true = setting up PIN, false = verifying PIN
  final VoidCallback? onSuccess;

  const AppLockScreen({super.key, this.isSettingUp = false, this.onSuccess});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final SecureStorageService _secureStorage = SecureStorageService();
  final BiometricAuthService _biometricAuth = BiometricAuthService();

  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _showError = false;
  String _errorMessage = '';
  bool _biometricAvailable = false;

  // Brute-force protection
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  static const int _maxAttempts = 5;

  bool get _isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  int get _lockoutSecondsLeft =>
      _isLockedOut ? _lockoutUntil!.difference(DateTime.now()).inSeconds : 0;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final available = await _biometricAuth.isBiometricAvailable();
    final enabled = await _secureStorage.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available && enabled;
      });
      // Auto-trigger biometric after we know it's available
      if (!widget.isSettingUp && _biometricAvailable) {
        _tryBiometricAuth();
      }
    }
  }

  Future<void> _tryBiometricAuth() async {
    if (!_biometricAvailable) return;

    final authenticated = await _biometricAuth.authenticate(
      localizedReason: 'Unlock DhanPath',
    );

    if (authenticated && mounted) {
      widget.onSuccess?.call();
      // Only pop if we can (i.e., this screen was navigated to, not rendered directly)
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _onNumberPressed(String number) {
    if (widget.isSettingUp) {
      _handleSetupPin(number);
    } else {
      _handleVerifyPin(number);
    }
  }

  void _handleSetupPin(String number) {
    setState(() {
      _showError = false;
      if (_isConfirming) {
        if (_confirmPin.length < 6) {
          _confirmPin += number;
          if (_confirmPin.length == 6) {
            _verifyAndSavePin();
          }
        }
      } else {
        if (_pin.length < 6) {
          _pin += number;
          if (_pin.length == 6) {
            _isConfirming = true;
          }
        }
      }
    });
  }

  void _handleVerifyPin(String number) {
    setState(() {
      _showError = false;
      if (_pin.length < 6) {
        _pin += number;
        if (_pin.length == 6) {
          _checkPin();
        }
      }
    });
  }

  Future<void> _verifyAndSavePin() async {
    if (_pin == _confirmPin) {
      await _secureStorage.setPin(_pin);
      await _secureStorage.setAppLockEnabled(true);
      if (mounted) {
        widget.onSuccess?.call();
        // Only pop if we can (i.e., this screen was navigated to)
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } else {
      setState(() {
        _showError = true;
        _errorMessage = 'PINs do not match. Try again.';
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  Future<void> _checkPin() async {
    // Check lockout first
    if (_isLockedOut) {
      setState(() {
        _showError = true;
        _errorMessage = 'Too many attempts. Wait $_lockoutSecondsLeft seconds.';
        _pin = '';
      });
      return;
    }

    final isCorrect = await _secureStorage.verifyPin(_pin);
    if (isCorrect) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      if (mounted) {
        widget.onSuccess?.call();
        // Only pop if we can (i.e., this screen was navigated to)
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } else {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        // Exponential backoff: 30s, 60s, 120s...
        final lockSeconds = 30 * (1 << (_failedAttempts ~/ _maxAttempts - 1));
        _lockoutUntil = DateTime.now().add(
          Duration(seconds: lockSeconds.clamp(30, 300)),
        );
        setState(() {
          _showError = true;
          _errorMessage =
              'Too many attempts. Locked for ${lockSeconds.clamp(30, 300)} seconds.';
          _pin = '';
        });
        // Auto-clear lockout message after timer
        Future.delayed(Duration(seconds: lockSeconds.clamp(30, 300)), () {
          if (mounted) {
            setState(() {
              _showError = false;
              _lockoutUntil = null;
            });
          }
        });
      } else {
        final remaining = _maxAttempts - _failedAttempts;
        setState(() {
          _showError = true;
          _errorMessage =
              'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} left.';
          _pin = '';
        });
      }
    }
  }

  void _onBackspace() {
    setState(() {
      _showError = false;
      if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
        _isConfirming = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // App Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock, size: 48, color: Colors.white),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              widget.isSettingUp
                  ? (_isConfirming ? 'Confirm PIN' : 'Set up PIN')
                  : 'Enter PIN',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              widget.isSettingUp
                  ? (_isConfirming
                        ? 'Re-enter your 6-digit PIN'
                        : 'Create a 6-digit PIN')
                  : 'Enter your PIN to unlock',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),

            const SizedBox(height: 40),

            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? const Color(0xFF4CAF50)
                        : Colors.transparent,
                    border: Border.all(
                      color: isFilled
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[600]!,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // Error Message
            if (_showError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            const Spacer(),

            // Number Pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildNumberRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildNumberRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildNumberRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  _buildNumberRow([
                    _biometricAvailable && !widget.isSettingUp ? 'bio' : '',
                    '0',
                    'back',
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) {
        if (number == 'bio') {
          return _buildBiometricButton();
        } else if (number == 'back') {
          return _buildBackspaceButton();
        } else if (number.isEmpty) {
          return const SizedBox(width: 72, height: 72);
        } else {
          return _buildNumberButton(number);
        }
      }).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[800],
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return InkWell(
      onTap: _tryBiometricAuth,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[800],
        ),
        child: const Center(
          child: Icon(Icons.fingerprint, size: 32, color: Color(0xFF4CAF50)),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[800],
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}
