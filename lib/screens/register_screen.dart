import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  bool _showConfirm = false;
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _confirmController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await credential.user?.sendEmailVerification();
    } on FirebaseAuthException {
      setState(() => _error = 'Could not create account. Email may already be in use.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  const Icon(Icons.directions_bike, color: Color(0xFF7AA8F0), size: 32),
                  const SizedBox(width: 10),
                  Text('JSCycling', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Create your account', style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const SizedBox(height: 32),

              if (_error.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 14)),
                ),

              _buildLabel(c, 'Email'),
              const SizedBox(height: 8),
              _buildInput(c, controller: _emailController, hint: 'your@email.com', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),

              _buildLabel(c, 'Password'),
              const SizedBox(height: 8),
              _buildInput(c,
                controller: _passwordController,
                hint: '••••••••',
                obscure: !_showPass,
                suffix: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, color: Colors.white30, size: 20),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel(c, 'Confirm password'),
              const SizedBox(height: 8),
              _buildInput(c,
                controller: _confirmController,
                hint: '••••••••',
                obscure: !_showConfirm,
                suffix: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white30, size: 20),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text('Create account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: c.textMuted, fontSize: 14),
                      children: const [
                        TextSpan(text: 'Sign in', style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(AppColors c, String text) {
    return Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted, letterSpacing: 0.8));
  }

  Widget _buildInput(AppColors c, {
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: c.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.inputBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7AA8F0))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}