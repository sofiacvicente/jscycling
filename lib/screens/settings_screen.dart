import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _passLoading = false;
  String _passError = '';
  bool _passSuccess = false;
  bool _verificationSent = false;
  bool _showPassForm = false;

  static const String _adminEmail = 'svicente005@gmail.com';

  User? get _user => FirebaseAuth.instance.currentUser;
  bool get _isAdmin => _user?.email == _adminEmail;

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    super.dispose();
  }

  Future<void> _sendVerification() async {
    try {
      await _user?.sendEmailVerification();
      setState(() => _verificationSent = true);
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) setState(() => _verificationSent = false);
    } catch (_) {
      _showSnack('Could not send verification email.');
    }
  }

  Future<void> _changePassword() async {
    if (_currentPassController.text.isEmpty || _newPassController.text.isEmpty) {
      setState(() { _passError = 'Please fill in both fields.'; _passSuccess = false; });
      return;
    }
    if (_newPassController.text.length < 6) {
      setState(() { _passError = 'New password must be at least 6 characters.'; _passSuccess = false; });
      return;
    }
    setState(() { _passLoading = true; _passError = ''; _passSuccess = false; });
    try {
      final credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: _currentPassController.text,
      );
      await _user!.reauthenticateWithCredential(credential);
      await _user!.updatePassword(_newPassController.text);
      _currentPassController.clear();
      _newPassController.clear();
      setState(() => _passSuccess = true);
    } on FirebaseAuthException {
      setState(() => _passError = 'Current password is incorrect.');
    } finally {
      if (mounted) setState(() => _passLoading = false);
    }
  }

  Future<void> _resetChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checklist');
    await prefs.remove('checklist_date');
    if (mounted) _showSnack('Checklist reset!');
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF2A52A0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.panelBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.panelBorder),
                      ),
                      child: Icon(Icons.arrow_back_ios_new, color: c.textMuted, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      Text('Account and app preferences.', style: TextStyle(fontSize: 13, color: c.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Account
              _glassPanel(c, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(c, 'Account'),
                  _infoRow(c, 'Email', _user?.email ?? '—'),
                  _divider(c),
                  _infoRow(c,
                    'Email verified',
                    _user?.emailVerified == true ? 'Yes' : 'No',
                    valueColor: _user?.emailVerified == true ? const Color(0xFF7AA8F0) : Colors.red,
                  ),
                  _divider(c),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Verify email', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                      TextButton(
                        onPressed: _verificationSent ? null : _sendVerification,
                        child: Text(
                          _verificationSent ? 'Email sent!' : 'Send email',
                          style: TextStyle(fontSize: 13, color: _verificationSent ? Colors.white38 : const Color(0xFF7AA8F0)),
                        ),
                      ),
                    ],
                  ),
                  if (_isAdmin) ...[
                    _divider(c),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Admin panel', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
                          child: Text('Open →', style: TextStyle(fontSize: 13, color: Color(0xFF7AA8F0))),
                        ),
                      ],
                    ),
                  ],
                ],
              )),
              const SizedBox(height: 12),

              // Change password
              _glassPanel(c, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle(c, 'Change password'),
                      TextButton(
                        onPressed: () => setState(() {
                          _showPassForm = !_showPassForm;
                          if (!_showPassForm) {
                            _currentPassController.clear();
                            _newPassController.clear();
                            _passError = '';
                            _passSuccess = false;
                          }
                        }),
                        child: Text(
                          _showPassForm ? 'Cancel' : 'Change',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF7AA8F0)),
                        ),
                      ),
                    ],
                  ),
                  if (_passSuccess)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A52A0).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3)),
                      ),
                      child: const Text('Password updated successfully.', style: TextStyle(fontSize: 13, color: Color(0xFF7AA8F0))),
                    ),
                  if (_showPassForm) ...[
                    if (_passError.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(_passError, style: const TextStyle(fontSize: 13, color: Colors.red)),
                      ),
                    _passField(c, 'Current password', _currentPassController, _showCurrent, () => setState(() => _showCurrent = !_showCurrent)),
                    const SizedBox(height: 12),
                    _passField(c, 'New password', _newPassController, _showNew, () => setState(() => _showNew = !_showNew)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _passLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A52A0),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _passLoading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Update password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              )),
              const SizedBox(height: 12),

              // App info
              _glassPanel(c, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(c, 'App'),
                  _infoRow(c, 'Version', '1.0.0'),
                  _divider(c),
                  _infoRow(c, 'Data storage', 'Firebase Firestore'),
                  _divider(c),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(
                          AppTheme.of(context).isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          size: 16,
                          color: const Color(0xFF7AA8F0),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppTheme.of(context).isDark ? 'Dark mode' : 'Light mode',
                          style: TextStyle(fontSize: 13, color: c.textSecondary),
                        ),
                      ]),
                      Switch(
                        value: !AppTheme.of(context).isDark,
                        onChanged: (_) => AppTheme.of(context).toggle(),
                        activeThumbColor: const Color(0xFF7AA8F0),
                        activeTrackColor: const Color(0xFF2A52A0).withValues(alpha: 0.5),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFF94A3B8).withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  _divider(c),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reset checklist', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                      TextButton(
                        onPressed: _resetChecklist,
                        child: const Text('Reset now', style: TextStyle(fontSize: 13, color: Color(0xFF7AA8F0))),
                      ),
                    ],
                  ),
                ],
              )),
              const SizedBox(height: 12),

              // Session
              _glassPanel(c, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(c, 'Session'),
                  _infoRow(c, 'Signed in as', _user?.email ?? '—'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sign out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passField(AppColors c, String label, TextEditingController controller, bool show, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted, letterSpacing: 0.6)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !show,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: c.textMuted),
            filled: true,
            fillColor: c.inputBg,
            suffixIcon: IconButton(
              icon: Icon(show ? Icons.visibility_off : Icons.visibility, color: Colors.white30, size: 20),
              onPressed: toggle,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7AA8F0))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(AppColors c, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted, letterSpacing: 0.8)),
    );
  }

  Widget _glassPanel(AppColors c, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.panelBorder),
      ),
      child: child,
    );
  }

  Widget _infoRow(AppColors c, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: c.textMuted)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor ?? c.textPrimary)),
        ],
      ),
    );
  }

  Widget _divider(AppColors c) => Divider(color: c.divider, height: 1);
}