import 'package:flutter/material.dart';

import '../services/supabase_auth_service.dart';

class EmailAuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const EmailAuthScreen({super.key, required this.onSuccess});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _otpSent = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _isSending = true;
      _error = null;
      _info = null;
    });
    try {
      await SupabaseAuthService.instance.sendOtp(email: email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _info = 'OTP sent to $email';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final code = _otpController.text.trim();
    if (email.isEmpty || code.isEmpty) return;
    setState(() {
      _isVerifying = true;
      _error = null;
      _info = null;
    });
    try {
      await SupabaseAuthService.instance.verifyOtp(email: email, otpCode: code);
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendOtp,
                  child: Text(_isSending ? 'Sending...' : 'Send OTP'),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      hintText: 'Enter 6-digit code',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    child: Text(_isVerifying ? 'Verifying...' : 'Verify OTP'),
                  ),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 10),
                  Text(_info!, style: TextStyle(color: cs.primary)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: cs.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
