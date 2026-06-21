import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/add_ride_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final themeNotifier = await ThemeNotifier.load();
  runApp(JSCyclingApp(themeNotifier: themeNotifier));
}

class JSCyclingApp extends StatefulWidget {
  final ThemeNotifier themeNotifier;
  const JSCyclingApp({super.key, required this.themeNotifier});

  @override
  State<JSCyclingApp> createState() => _JSCyclingAppState();
}

class _JSCyclingAppState extends State<JSCyclingApp> {
  @override
  void initState() {
    super.initState();
    widget.themeNotifier.addListener(() => setState(() {}));
  }

  ThemeData _buildTheme(bool isDark) {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0E0E0E) : const Color(0xFFF2F4F8),
      colorScheme: isDark
          ? const ColorScheme.dark(primary: Color(0xFF2A52A0), secondary: Color(0xFF7AA8F0), surface: Color(0xFF1A1A1A))
          : const ColorScheme.light(primary: Color(0xFF2A52A0), secondary: Color(0xFF7AA8F0), surface: Colors.white),
      fontFamily: 'DMSans',
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeNotifier.isDark;
    return AppTheme(
      notifier: widget.themeNotifier,
      child: MaterialApp(
        title: 'JSCycling',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(isDark),
        routes: {
          '/register': (context) => const RegisterScreen(),
        },
        home: const SplashGate(),
      ),
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
    _slideAnim = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
    _controller.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const AuthGate();
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Center(
          child: Opacity(
            opacity: _fadeAnim.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A52A0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.directions_bike, size: 52, color: Color(0xFF7AA8F0)),
                  ),
                  const SizedBox(height: 28),
                  const Text('JSCycling', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('With love, S.', style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.38), fontWeight: FontWeight.w300)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Color(0xFF0E0E0E));
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          final isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');
          if (!isGoogleUser && !user.emailVerified) return const VerifyEmailScreen();
          return const MainShell();
        }
        return const LoginScreen();
      },
    );
  }
}

// ── Main Shell with floating pill nav ────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const HistoryScreen(),
    const AddRideScreen(),
    const StatsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: c.bgGradient,
            width: double.infinity,
            height: double.infinity,
          ),
          // Screens using IndexedStack so state is preserved
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Floating pill nav bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + bottomPad,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: c.isDark
                    ? const Color(0xFF1C1C1E).withValues(alpha: 0.97)
                    : Colors.white.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: c.navBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: c.isDark ? 0.45 : 0.14),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: Row(
                  children: [
                    _navItem(context, 0, Icons.grid_view_rounded, 'Home'),
                    _navItem(context, 1, Icons.show_chart_rounded, 'History'),
                    _navItemAdd(c),
                    _navItem(context, 3, Icons.bar_chart_rounded, 'Stats'),
                    _navItem(context, 4, Icons.person_outline_rounded, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, String label) {
    final active = _currentIndex == index;
    final c = AppColors(AppTheme.of(context).isDark);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF2A52A0).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: active ? const Color(0xFF7AA8F0) : c.navInactive),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? const Color(0xFF7AA8F0) : c.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItemAdd(AppColors c) {
    final active = _currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = 2),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF7AA8F0) : const Color(0xFF2A52A0),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2A52A0).withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}