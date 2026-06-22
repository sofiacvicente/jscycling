import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'rides_notifier.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;
  String _name = '';
  double _monthlyGoal = 0;
  double _weeklyGoal = 0;
  Map<String, dynamic>? _weather;
  List<Map<String, dynamic>> _checklist = _defaultChecklist();
  late AnimationController _pulseCtrl;

  static List<Map<String, dynamic>> _defaultChecklist() => [
        {'id': 1, 'label': 'Tyre pressure', 'done': false},
        {'id': 2, 'label': 'Chain lube', 'done': false},
        {'id': 3, 'label': 'Helmet', 'done': false},
        {'id': 4, 'label': 'Lights', 'done': false},
        {'id': 5, 'label': 'Water', 'done': false},
        {'id': 6, 'label': 'GPS', 'done': false},
      ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _loadAll();
    ridesVersion.addListener(_onRidesChanged);
  }

  void _onRidesChanged() => _loadAll();

  @override
  void dispose() {
    ridesVersion.removeListener(_onRidesChanged);
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadRides(), _loadProfile(), _loadChecklist()]);
    _fetchWeather();
  }

  Future<void> _loadRides() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) { setState(() => _loading = false); return; }
      final snap = await FirebaseFirestore.instance
          .collection('rides')
          .where('uid', isEqualTo: uid)
          .orderBy('date', descending: true)
          .get();
      setState(() {
        _rides = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
      final data = doc.data() ?? {};
      setState(() {
        _name = data['name'] ?? '';
        _monthlyGoal = double.tryParse(data['monthlyGoal'] ?? '') ?? 0;
        _weeklyGoal = double.tryParse(data['weeklyGoal'] ?? '') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString('checklist_date') == today) {
      final saved = prefs.getString('checklist');
      if (saved != null) {
        setState(() => _checklist = List<Map<String, dynamic>>.from(jsonDecode(saved)));
        return;
      }
    }
    _resetChecklist();
  }

  Future<void> _saveChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('checklist', jsonEncode(_checklist));
    await prefs.setString('checklist_date', DateTime.now().toIso8601String().substring(0, 10));
  }

  void _resetChecklist() {
    setState(() => _checklist = _defaultChecklist());
    _saveChecklist();
  }

  Future<void> _fetchWeather() async {
    try {
      final res = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=38.6&longitude=-9.1&current_weather=true'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final code = data['current_weather']['weathercode'] as int;
        final temp = (data['current_weather']['temperature'] as num).round();
        final icons = {0:'☀️',1:'🌤️',2:'⛅',3:'☁️',45:'🌫️',51:'🌦️',61:'🌧️',71:'❄️',80:'🌦️',95:'⛈️'};
        setState(() => _weather = {'temp': temp, 'icon': icons[code] ?? '🌡️'});
      }
    } catch (_) {}
  }

  String _greeting() {
    final h = DateTime.now().hour;
    final n = _name.isNotEmpty ? ', $_name' : '';
    if (h >= 5 && h < 12) return 'Good Morning$n 👋';
    if (h >= 12 && h < 20) return 'Good Afternoon$n 👋';
    return 'Good Evening$n 👋';
  }

  // ── level / XP ──────────────────────────────────────────────────────────────
  static const _levels = [
    {'xp':    0, 'name': 'Rookie',   'icon': '🚲'},
    {'xp':   50, 'name': 'Rider',    'icon': '🚴'},
    {'xp':  150, 'name': 'Pacer',    'icon': '💨'},
    {'xp':  300, 'name': 'Climber',  'icon': '⛰️'},
    {'xp':  600, 'name': 'Racer',    'icon': '🏁'},
    {'xp': 1000, 'name': 'Expert',   'icon': '🎯'},
    {'xp': 1500, 'name': 'Pro',      'icon': '🏆'},
    {'xp': 2500, 'name': 'Elite',    'icon': '⚡'},
    {'xp': 4000, 'name': 'Champion', 'icon': '🥇'},
    {'xp': 6000, 'name': 'Legend',   'icon': '👑'},
  ];
  Map<String, dynamic> get _currentLevel {
    final xp = _totalDist;
    for (int i = _levels.length - 1; i >= 0; i--) {
      if (xp >= (_levels[i]['xp'] as int)) return {..._levels[i], 'index': i};
    }
    return {..._levels[0], 'index': 0};
  }
  Map<String, dynamic>? get _nextLevel {
    final idx = _currentLevel['index'] as int;
    return idx < _levels.length - 1 ? {..._levels[idx + 1], 'index': idx + 1} : null;
  }

  // ── computed stats ──────────────────────────────────────────────────────────
  double get _totalDist => _rides.fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble());
  int get _totalRides => _rides.length;
  int get _totalDuration => _rides.fold(0, (a, r) => a + ((r['duration'] ?? 0) as int));
  double get _longestRide => _rides.fold(0.0, (b, r) => math.max(b, (r['distance'] ?? 0).toDouble()));
  double get _monthDist {
    final now = DateTime.now();
    return _rides.where((r) {
      final d = DateTime.tryParse(r['date'] ?? '') ?? DateTime(2000);
      return d.month == now.month && d.year == now.year;
    }).fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble());
  }
  double get _weekDist {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return _rides.where((r) {
      final d = DateTime.tryParse(r['date'] ?? '') ?? DateTime(2000);
      return !d.isBefore(start);
    }).fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble());
  }
  int get _streak {
    if (_rides.isEmpty) return 0;
    final dates = _rides.map((r) => r['date'] as String).toSet().toList()..sort((a, b) => b.compareTo(a));
    int count = 0;
    var cur = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (final date in dates) {
      final d = DateTime.parse(date);
      final diff = cur.difference(d).inDays;
      if (diff == 0 || diff == 1) { count++; cur = d; } else { break; }
    }
    return count;
  }

  String _fmtDuration(int secs) {
    final h = secs ~/ 3600, m = (secs % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final d = DateTime.parse(raw);
      return '${d.day} ${mo[d.month-1]}';
    } catch (_) { return raw; }
  }

  String _avgSpeed(Map<String, dynamic> r) {
    final d = (r['distance'] ?? 0).toDouble();
    final t = (r['duration'] ?? 0) as int;
    if (t == 0 || d == 0) return '—';
    return '${(d / (t / 3600)).toStringAsFixed(1)} km/h';
  }

  String _terrainIcon(String? t) {
    switch (t) {
      case 'road': return '🛣️';
      case 'mountain': return '⛰️';
      case 'city': return '🏙️';
      case 'gravel': return '🪨';
      default: return '🚴';
    }
  }

  Map<String, dynamic>? get _nextTrophy {
    if (_totalRides < 1) return {'name':'First Ride','icon':'🚴','p':0.0,'desc':'Log your first ride'};
    if (_totalRides < 10) return {'name':'10 Rides','icon':'🔟','p':_totalRides/10.0,'desc':'$_totalRides / 10 rides'};
    if (_totalDist < 100) return {'name':'100 km','icon':'💯','p':_totalDist/100,'desc':'${_totalDist.toStringAsFixed(0)} / 100 km'};
    if (_totalDist < 500) return {'name':'500 km','icon':'🏅','p':_totalDist/500,'desc':'${_totalDist.toStringAsFixed(0)} / 500 km'};
    if (_longestRide < 100) return {'name':'Century','icon':'⚡','p':_longestRide/100,'desc':'${_longestRide.toStringAsFixed(0)} / 100 km ride'};
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    if (_loading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF7AA8F0))),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: const Color(0xFF7AA8F0),
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, topPad, 0, botPad + 108),
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greeting(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
                      Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                          style: TextStyle(fontSize: 13, color: c.textMuted)),
                    ]),
                  ),
                  if (_weather != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.panelBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.panelBorder),
                      ),
                      child: Row(children: [
                        Text(_weather!['icon'], style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text('${_weather!['temp']}°C',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Level pill ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildLevelPill(c),
            ),
            const SizedBox(height: 14),

            // ── Performance Snapshot ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildPerformanceSnapshot(c),
            ),
            const SizedBox(height: 16),

            // ── Goals ────────────────────────────────────────────────────────
            if (_monthlyGoal > 0 || _weeklyGoal > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildGoals(c),
              ),
              const SizedBox(height: 16),
            ],

            // ── Next trophy ──────────────────────────────────────────────────
            if (_nextTrophy != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildNextTrophy(c),
              ),
              const SizedBox(height: 20),
            ],

            // ── Recent Activity header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text('See All',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF7AA8F0), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Recent ride cards (horizontal scroll) ────────────────────────
            if (_rides.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.panelBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.panelBorder),
                  ),
                  child: Column(children: [
                    const Icon(Icons.directions_bike_rounded, size: 40, color: Color(0xFF7AA8F0)),
                    const SizedBox(height: 12),
                    Text('No rides yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Tap + to log your first ride.', style: TextStyle(fontSize: 13, color: c.textMuted)),
                  ]),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  itemCount: math.min(_rides.length, 10),
                  itemBuilder: (_, i) => _recentRideCard(c, _rides[i]),
                ),
              ),

            const SizedBox(height: 20),

            // ── Pre-ride checklist ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildChecklist(c),
            ),
          ],
        ),
      ),
    );
  }

  // ── Performance Snapshot ────────────────────────────────────────────────────
  Widget _buildPerformanceSnapshot(AppColors c) {
    final streak = _streak;
    final isOnFire = streak >= 7;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [const Color(0xFF1A3A6B), const Color(0xFF0A1628)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Performance Snapshot',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.2)),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final glow = isOnFire ? 0.1 + _pulseCtrl.value * 0.15 : 0.0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOnFire
                      ? const Color(0xFFFF6B35).withValues(alpha: 0.15 + glow)
                      : const Color(0xFF2A52A0).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isOnFire
                        ? const Color(0xFFFF6B35).withValues(alpha: 0.5)
                        : const Color(0xFF7AA8F0).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('$streak day streak',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: isOnFire ? const Color(0xFFFF6B35) : const Color(0xFF7AA8F0),
                      )),
                ]),
              );
            },
          ),
        ]),
        const SizedBox(height: 18),

        // Big 3 stats
        Row(children: [
          _snapshotStat('${_totalDist.toStringAsFixed(0)} km', 'Total distance', Icons.route_rounded),
          _snapDivider(),
          _snapshotStat(_fmtDuration(_totalDuration), 'Time on trails', Icons.timer_rounded),
          _snapDivider(),
          _snapshotStat('$_totalRides', 'Sections done', Icons.check_circle_outline_rounded),
        ]),

        const SizedBox(height: 16),
        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 14),

        // Secondary row
        Row(children: [
          _snapshotSecondary('${_longestRide.toStringAsFixed(1)} km', 'Longest'),
          _snapshotSecondary('${_monthDist.toStringAsFixed(0)} km', 'This month'),
          _snapshotSecondary('${_weekDist.toStringAsFixed(0)} km', 'This week'),
        ]),
      ]),
    );
  }

  Widget _snapshotStat(String value, String label, IconData icon) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
    ]),
  );

  Widget _snapshotSecondary(String value, String label) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
    ]),
  );

  Widget _snapDivider() => Container(
    width: 1, height: 48,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.white.withValues(alpha: 0.08),
  );

  // ── Recent ride card (horizontal) ───────────────────────────────────────────
  Widget _recentRideCard(AppColors c, Map<String, dynamic> ride) {
    final hasRoute = ride['route'] != null && (ride['route'] as List).isNotEmpty;
    final hasPhoto = ride['photoUrl'] != null;
    final terrain  = ride['terrain'] as String?;
    final dist     = (ride['distance'] ?? 0).toDouble();
    final dur      = (ride['duration'] ?? 0) as int;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: c.panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.panelBorder),
        boxShadow: c.panelShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Map / photo / terrain preview
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: 100,
            width: double.infinity,
            child: hasPhoto
                ? Image.network(ride['photoUrl'], fit: BoxFit.cover)
                : hasRoute
                    ? _routePreview(ride, c)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF2A52A0).withValues(alpha: 0.35), const Color(0xFF0A1628).withValues(alpha: 0.6)],
                          ),
                        ),
                        child: Center(child: Text(_terrainIcon(terrain), style: const TextStyle(fontSize: 32))),
                      ),
          ),
        ),

        // Info
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fmtDate(ride['date'] as String?),
                style: TextStyle(fontSize: 11, color: c.textMuted)),
            const SizedBox(height: 4),
            Text('${dist.toStringAsFixed(1)} km',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.timer_outlined, size: 12, color: c.textMuted),
              const SizedBox(width: 4),
              Text(_fmtDuration(dur), style: TextStyle(fontSize: 12, color: c.textSecondary)),
              const SizedBox(width: 10),
              Icon(Icons.speed_rounded, size: 12, color: c.textMuted),
              const SizedBox(width: 4),
              Text(_avgSpeed(ride), style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _routePreview(Map<String, dynamic> ride, AppColors c) {
    final raw = ride['route'] as List? ?? [];
    final pts = raw.map((p) {
      if (p is Map) return Offset((p['lng'] ?? 0.0).toDouble(), (p['lat'] ?? 0.0).toDouble());
      return Offset.zero;
    }).where((o) => o != Offset.zero).toList();

    return Container(
      color: const Color(0xFF0A1628),
      child: pts.length >= 2
          ? CustomPaint(painter: _RoutePainter(pts))
          : Center(child: Text(_terrainIcon(ride['terrain']), style: const TextStyle(fontSize: 32))),
    );
  }

  // ── Goals ───────────────────────────────────────────────────────────────────
  Widget _buildGoals(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.panelBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_rounded, size: 14, color: Color(0xFF7AA8F0)),
          const SizedBox(width: 6),
          Text('Goals', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
        ]),
        const SizedBox(height: 14),
        if (_weeklyGoal > 0) _goalRow(c, 'This week', _weekDist, _weeklyGoal),
        if (_weeklyGoal > 0 && _monthlyGoal > 0) const SizedBox(height: 12),
        if (_monthlyGoal > 0) _goalRow(c, 'This month', _monthDist, _monthlyGoal),
      ]),
    );
  }

  Widget _goalRow(AppColors c, String label, double cur, double goal) {
    final pct = (cur / goal).clamp(0.0, 1.0);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
        Text('${cur.toStringAsFixed(1)} / ${goal.toStringAsFixed(0)} km',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: pct >= 1 ? const Color(0xFF7AA8F0) : c.textPrimary)),
      ]),
      const SizedBox(height: 6),
      Stack(children: [
        Container(height: 7, decoration: BoxDecoration(color: c.progressBg, borderRadius: BorderRadius.circular(4))),
        FractionallySizedBox(
          widthFactor: pct,
          child: Container(height: 7, decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2A52A0), Color(0xFF7AA8F0)]),
            borderRadius: BorderRadius.circular(4),
          )),
        ),
      ]),
    ]);
  }

  // ── Level pill ───────────────────────────────────────────────────────────────
  Widget _buildLevelPill(AppColors c) {
    final xp   = _totalDist;
    final cur  = _currentLevel;
    final next = _nextLevel;
    final curXP  = cur['xp'] as int;
    final nextXP = next != null ? next['xp'] as int : curXP;
    final pct    = next != null ? ((xp - curXP) / (nextXP - curXP)).clamp(0.0, 1.0) : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [Color(0xFF1A3A6B), Color(0xFF0D1E3A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Text(cur['icon'] as String, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Level ${(cur['index'] as int) + 1} · ${cur['name']}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            Text('${xp.toStringAsFixed(0)} km',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
          ]),
          const SizedBox(height: 6),
          Stack(children: [
            Container(height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3))),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(height: 5, decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2A52A0), Color(0xFF7AA8F0)]),
                borderRadius: BorderRadius.circular(3),
              )),
            ),
          ]),
          if (next != null) ...[
            const SizedBox(height: 4),
            Text('${next['icon']} ${next['name']} at $nextXP km',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
          ],
        ])),
      ]),
    );
  }

  // ── Next Trophy ─────────────────────────────────────────────────────────────
  Widget _buildNextTrophy(AppColors c) {
    final t = _nextTrophy!;
    final pct = (t['p'] as double).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.panelBorder),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF2A52A0).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3)),
          ),
          child: Center(child: Text(t['icon'], style: const TextStyle(fontSize: 26))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Next trophy', style: TextStyle(fontSize: 10, color: Color(0xFF7AA8F0), fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(t['name'], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
          Text(t['desc'], style: TextStyle(fontSize: 11, color: c.textMuted)),
          const SizedBox(height: 8),
          Stack(children: [
            Container(height: 5, decoration: BoxDecoration(color: c.progressBg, borderRadius: BorderRadius.circular(3))),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(height: 5, decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2A52A0), Color(0xFF7AA8F0)]),
                borderRadius: BorderRadius.circular(3),
              )),
            ),
          ]),
        ])),
      ]),
    );
  }

  // ── Checklist ────────────────────────────────────────────────────────────────
  Widget _buildChecklist(AppColors c) {
    final done = _checklist.where((i) => i['done'] == true).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Pre-ride checklist',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        GestureDetector(
          onTap: _resetChecklist,
          child: Text('Reset', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ),
      ]),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3.4,
        children: _checklist.map((item) {
          final isDone = item['done'] as bool;
          return GestureDetector(
            onTap: () { setState(() => item['done'] = !isDone); _saveChecklist(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF2A52A0).withValues(alpha: 0.2) : c.panelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDone ? const Color(0xFF7AA8F0).withValues(alpha: 0.5) : c.panelBorder),
              ),
              child: Row(children: [
                Icon(
                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isDone ? const Color(0xFF7AA8F0) : c.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  item['label'],
                  style: TextStyle(
                    fontSize: 12,
                    color: isDone ? c.textMuted : c.textPrimary,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
            ),
          );
        }).toList(),
      ),
      if (done == _checklist.length && done > 0) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A52A0).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('🎉', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text('All done! Ready to ride.', style: TextStyle(fontSize: 13, color: Color(0xFF7AA8F0), fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    ]);
  }
}

// ── Route painter (reused from history) ─────────────────────────────────────
class _RoutePainter extends CustomPainter {
  final List<Offset> pts;
  _RoutePainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final minLng = pts.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final maxLng = pts.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final minLat = pts.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxLat = pts.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    final rangeX = maxLng - minLng;
    final rangeY = maxLat - minLat;
    if (rangeX == 0 || rangeY == 0) return;
    const pad = 12.0;
    Offset toCanvas(Offset p) => Offset(
      pad + (p.dx - minLng) / rangeX * (size.width - pad * 2),
      size.height - pad - (p.dy - minLat) / rangeY * (size.height - pad * 2),
    );
    final bgPaint = Paint()..color = const Color(0xFF0A1628);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    final paint = Paint()
      ..color = const Color(0xFF7AA8F0)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(toCanvas(pts[0]).dx, toCanvas(pts[0]).dy);
    for (int i = 1; i < pts.length; i++) {
      final p = toCanvas(pts[i]);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(toCanvas(pts.first), 5, Paint()..color = Colors.greenAccent);
    canvas.drawCircle(toCanvas(pts.last), 5, Paint()..color = const Color(0xFFFF6B35));
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.pts != pts;
}