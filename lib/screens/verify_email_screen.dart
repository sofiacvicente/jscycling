import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import '../main.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sent = false;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendVerification();
    // Poll every 3 seconds to check if email was verified
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (verified && mounted) {
        _timer?.cancel();
        // Navigate directly to MainShell instead of waiting for stream
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerification() async {
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() => _sent = true);
    } catch (_) {}
    setState(() => _sending = false);
  }

  Future<void> _signOut() async {
    _timer?.cancel();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A52A0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.email_outlined, size: 40, color: Color(0xFF7AA8F0)),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your email',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to\n$email',
                style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_sent)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A52A0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF7AA8F0), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Verification email sent! Check your inbox.',
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A52A0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _sending
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.textPrimary))
                      : Text('Resend email', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Sign out', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}