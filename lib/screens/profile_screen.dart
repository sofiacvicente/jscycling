import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'app_theme.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  // Data
  String _name = '';
  String _location = '';
  String _bikeModel = '';
  String _bikeType = '';
  String _bikeSize = '';
  String _bikeWeight = '';
  String _bikeYear = '';
  String _bikeGroupset = '';
  String _bikeWheels = '';
  String _monthlyGoal = '';
  String _weeklyGoal = '';
  String? _photoUrl;
  String? _coverUrl;
  File? _photoFile;
  File? _coverFile;
  List<Map<String, dynamic>> _rides = [];
  List<String> _unlockedTrophies = [];
  bool _loading = true;
  bool _editing = false;

  // Tab controller
  late TabController _tabCtrl;

  // Edit controllers
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bikeModelCtrl = TextEditingController();
  final _bikeTypeCtrl = TextEditingController();
  final _bikeSizeCtrl = TextEditingController();
  final _bikeWeightCtrl = TextEditingController();
  final _bikeYearCtrl = TextEditingController();
  final _bikeGroupsetCtrl = TextEditingController();
  final _bikeWheelsCtrl = TextEditingController();
  final _monthlyGoalCtrl = TextEditingController();
  final _weeklyGoalCtrl = TextEditingController();

  final _picker = ImagePicker();

  final List<Map<String, dynamic>> _trophies = [
    {'id': 'first_ride',     'name': 'First Ride',  'icon': '🚴', 'desc': 'Log your first ride.',      'reward': 'Escolhes o jantar esta semana 🍕'},
    {'id': 'ten_rides',      'name': '10 Rides',    'icon': '🔟', 'desc': 'Log 10 rides.',             'reward': 'Cinema + snacks à escolha 🎬'},
    {'id': 'hundred_km',     'name': '100 km',      'icon': '💯', 'desc': 'Accumulate 100 km.',        'reward': 'Pequeno-almoço na cama ☕'},
    {'id': 'five_hundred_km','name': '500 km',      'icon': '🏅', 'desc': 'Accumulate 500 km.',        'reward': 'Jantar no restaurante favorito 🥂'},
    {'id': 'thousand_km',    'name': '1000 km',     'icon': '🏆', 'desc': 'Accumulate 1000 km.',       'reward': 'Viagem surpresa 🌍'},
    {'id': 'century',        'name': 'Century',     'icon': '⚡', 'desc': 'Complete a 100 km ride.',   'reward': 'Dia inteiro sem planos 🎯'},
    {'id': 'climber',        'name': 'Climber',     'icon': '⛰️', 'desc': '1000 m elevation.',         'reward': 'Massagem nas costas 💆'},
    {'id': 'on_fire',        'name': 'On Fire',     'icon': '🔥', 'desc': '7 day streak.',             'reward': 'Fim de semana a escolher 🗓️'},
  ];

  final List<Map<String, dynamic>> _challenges = [
    {'name': '5 Rides This Month', 'icon': '📅', 'reward': 'Gelado gigante 🍦', 'target': 5,   'type': 'rides_month'},
    {'name': '200 km This Month',  'icon': '🗺️', 'reward': 'Noite de filmes 🎥', 'target': 200, 'type': 'distance_month'},
    {'name': '3 Rides This Week',  'icon': '⚡', 'reward': 'Eu trato de tudo 👑', 'target': 3,  'type': 'rides_week'},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose(); _locationCtrl.dispose();
    _bikeModelCtrl.dispose(); _bikeTypeCtrl.dispose();
    _bikeSizeCtrl.dispose(); _bikeWeightCtrl.dispose();
    _bikeYearCtrl.dispose(); _bikeGroupsetCtrl.dispose();
    _bikeWheelsCtrl.dispose(); _monthlyGoalCtrl.dispose();
    _weeklyGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadProfile();
    await _loadRides();
    _checkTrophies();
    setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
      final data = doc.data() ?? {};
      setState(() {
        _name         = data['name'] ?? '';
        _location     = data['location'] ?? '';
        _bikeModel    = data['bike'] ?? '';
        _bikeType     = data['bikeType'] ?? '';
        _bikeSize     = data['bikeSize'] ?? '';
        _bikeWeight   = data['bikeWeight'] ?? '';
        _bikeYear     = data['bikeYear'] ?? '';
        _bikeGroupset = data['bikeGroupset'] ?? '';
        _bikeWheels   = data['bikeWheels'] ?? '';
        _monthlyGoal  = data['monthlyGoal'] ?? '';
        _weeklyGoal   = data['weeklyGoal'] ?? '';
        _photoUrl     = data['photoUrl'];
        _coverUrl     = data['coverUrl'];
        _nameCtrl.text = _name; _locationCtrl.text = _location;
        _bikeModelCtrl.text = _bikeModel; _bikeTypeCtrl.text = _bikeType;
        _bikeSizeCtrl.text = _bikeSize; _bikeWeightCtrl.text = _bikeWeight;
        _bikeYearCtrl.text = _bikeYear; _bikeGroupsetCtrl.text = _bikeGroupset;
        _bikeWheelsCtrl.text = _bikeWheels;
        _monthlyGoalCtrl.text = _monthlyGoal; _weeklyGoalCtrl.text = _weeklyGoal;
      });
    } catch (_) {}
  }

  Future<void> _loadRides() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rides')
          .where('uid', isEqualTo: uid)
          .orderBy('date', descending: true)
          .get();
      setState(() => _rides = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
    } catch (_) {}
  }

  void _checkTrophies() {
    final total    = _rides.length;
    final totalDist = _rides.fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble());
    final totalElev = _rides.fold(0.0, (a, r) => a + (r['elevation'] ?? 0).toDouble());
    final longest  = _rides.fold(0.0, (b, r) => (r['distance'] ?? 0).toDouble() > b ? (r['distance'] ?? 0).toDouble() : b);
    final unlocked = <String>[];
    if (total >= 1)       unlocked.add('first_ride');
    if (total >= 10)      unlocked.add('ten_rides');
    if (totalDist >= 100) unlocked.add('hundred_km');
    if (totalDist >= 500) unlocked.add('five_hundred_km');
    if (totalDist >= 1000)unlocked.add('thousand_km');
    if (longest >= 100)   unlocked.add('century');
    if (totalElev >= 1000)unlocked.add('climber');
    if (_calcStreak() >= 7) unlocked.add('on_fire');
    setState(() => _unlockedTrophies = unlocked);
  }

  int _calcStreak() {
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

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.doc('users/$uid').set({
      'name': _nameCtrl.text, 'location': _locationCtrl.text,
      'bike': _bikeModelCtrl.text, 'bikeType': _bikeTypeCtrl.text,
      'bikeSize': _bikeSizeCtrl.text, 'bikeWeight': _bikeWeightCtrl.text,
      'bikeYear': _bikeYearCtrl.text, 'bikeGroupset': _bikeGroupsetCtrl.text,
      'bikeWheels': _bikeWheelsCtrl.text,
      'monthlyGoal': _monthlyGoalCtrl.text, 'weeklyGoal': _weeklyGoalCtrl.text,
    }, SetOptions(merge: true));
    setState(() {
      _name = _nameCtrl.text; _location = _locationCtrl.text;
      _bikeModel = _bikeModelCtrl.text; _editing = false;
    });
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 400);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _photoFile = file);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      setState(() => _photoUrl = url);
      await FirebaseFirestore.instance.doc('users/$uid').set({'photoUrl': url}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _pickCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _coverFile = file);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final ref = FirebaseStorage.instance.ref().child('covers/$uid.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      setState(() => _coverUrl = url);
      await FirebaseFirestore.instance.doc('users/$uid').set({'coverUrl': url}, SetOptions(merge: true));
    } catch (_) {}
  }

  String get _initials {
    if (_name.isEmpty) return 'R';
    final parts = _name.split(' ');
    return parts.map((n) => n[0]).join().toUpperCase().substring(0, parts.length > 1 ? 2 : 1);
  }

  int _challengeProgress(Map<String, dynamic> ch) {
    final now = DateTime.now();
    switch (ch['type']) {
      case 'rides_month':
        return _rides.where((r) { final d = DateTime.tryParse(r['date'] ?? '') ?? DateTime(2000); return d.month == now.month && d.year == now.year; }).length;
      case 'distance_month':
        return _rides.where((r) { final d = DateTime.tryParse(r['date'] ?? '') ?? DateTime(2000); return d.month == now.month && d.year == now.year; }).fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble()).round();
      case 'rides_week':
        final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        return _rides.where((r) { final d = DateTime.tryParse(r['date'] ?? '') ?? DateTime(2000); return !d.isBefore(start); }).length;
      default: return 0;
    }
  }

  void _showReward(Map<String, dynamic> trophy) {
    final c = AppColors(AppTheme.of(context).isDark);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(trophy['icon'], style: const TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        Text(trophy['name'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 4),
        Text('Trophy unlocked!', style: TextStyle(fontSize: 14, color: c.textSecondary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF2A52A0).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3))),
          child: Text('🎁 ${trophy['reward']}', style: const TextStyle(fontSize: 15, color: Color(0xFF7AA8F0), fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A52A0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Close', style: TextStyle(color: Colors.white)),
        )),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF7AA8F0)));

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: _buildHeader(c)),
      ],
      body: Column(children: [
        // Sliding pill tab selector
        Container(
          color: c.isDark ? const Color(0xFF080E1A) : const Color(0xFFF2F4F8),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: _SlidingTabBar(
            controller: _tabCtrl,
            tabs: const ['Activity', 'Badges', 'Goals', 'Bike'],
            c: c,
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildActivityTab(c),
              _buildBadgesTab(c),
              _buildChallengesTab(c),
              _buildBikeTab(c),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(AppColors c) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover photo
        GestureDetector(
          onTap: _pickCover,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [const Color(0xFF2A52A0).withValues(alpha: 0.6), const Color(0xFF080E1A)],
              ),
            ),
            child: _coverFile != null
                ? Image.file(_coverFile!, fit: BoxFit.cover)
                : _coverUrl != null
                    ? Image.network(_coverUrl!, fit: BoxFit.cover)
                    : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 32, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 6),
                        Text('Add cover photo', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
                      ])),
          ),
        ),



        // Avatar + info below cover
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 140, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with camera icon
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(children: [
                  Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A52A0),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.isDark ? const Color(0xFF080E1A) : const Color(0xFFF2F4F8), width: 4),
                    ),
                    child: _photoFile != null
                        ? ClipOval(child: Image.file(_photoFile!, fit: BoxFit.cover))
                        : _photoUrl != null
                            ? ClipOval(child: Image.network(_photoUrl!, fit: BoxFit.cover))
                            : Center(child: Text(_initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                  Positioned(bottom: 0, right: 0, child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: const Color(0xFF2A52A0), shape: BoxShape.circle, border: Border.all(color: c.isDark ? const Color(0xFF080E1A) : Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                  )),
                ]),
              ),
              const SizedBox(height: 12),

              if (!_editing) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_name.isEmpty ? 'Rider' : _name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
                    Row(children: [
                      GestureDetector(
                        onTap: () => setState(() => _editing = !_editing),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: c.panelBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.panelBorder),
                          ),
                          child: Text('Edit', style: TextStyle(fontSize: 13, color: c.textPrimary, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: c.panelBg, shape: BoxShape.circle, border: Border.all(color: c.panelBorder)),
                          child: Icon(Icons.settings_outlined, color: c.textSecondary, size: 18),
                        ),
                      ),
                    ]),
                  ],
                ),
                if (_location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 14, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text(_location, style: TextStyle(fontSize: 13, color: c.textMuted)),
                  ]),
                ],
                if (_bikeModel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.directions_bike_outlined, size: 14, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text(_bikeModel, style: TextStyle(fontSize: 13, color: c.textMuted)),
                  ]),
                ],
                const SizedBox(height: 16),
                // Stats row
                Row(children: [
                  _statChip(c, '${_rides.length}', 'Rides'),
                  const SizedBox(width: 24),
                  _statChip(c, '${_rides.fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble()).toStringAsFixed(0)} km', 'Total'),
                  const SizedBox(width: 24),
                  _statChip(c, '${_unlockedTrophies.length}', 'Trophies'),
                ]),
                const SizedBox(height: 16),
              ] else ...[
                // Inline edit form
                _editField(c, 'Name', _nameCtrl, 'Your name'),
                const SizedBox(height: 10),
                _editField(c, 'Location', _locationCtrl, 'City, Country'),
                const SizedBox(height: 10),
                _editField(c, 'Monthly goal (km)', _monthlyGoalCtrl, 'e.g. 300'),
                const SizedBox(height: 10),
                _editField(c, 'Weekly goal (km)', _weeklyGoalCtrl, 'e.g. 80'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A52A0), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _statChip(AppColors c, String value, String label) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary)),
    Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
  ]);

  Widget _editField(AppColors c, String label, TextEditingController ctrl, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textMuted, letterSpacing: 0.6)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        style: TextStyle(color: c.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: c.textMuted),
          filled: true, fillColor: c.inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.inputBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.inputBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7AA8F0))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]);
  }

  // ── TABS ──────────────────────────────────────────────────────────────────

  Widget _buildActivityTab(AppColors c) {
    if (_rides.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.directions_bike_outlined, size: 48, color: Color(0xFF7AA8F0)),
        const SizedBox(height: 12),
        Text('No rides yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
        Text('Start riding to see your activity.', style: TextStyle(fontSize: 13, color: c.textMuted)),
      ]));
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 108),
      itemCount: _rides.length,
      itemBuilder: (_, i) {
        final ride = _rides[i];
        final dist = (ride['distance'] ?? 0).toDouble();
        final dur = (ride['duration'] ?? 0) as int;
        const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        String dl = '—';
        try { final d = DateTime.parse(ride['date']); dl = '${d.day} ${mo[d.month-1]} ${d.year}'; } catch (_) {}
        final spd = dur > 0 ? dist / (dur / 3600) : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.panelBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.panelBorder), boxShadow: c.panelShadow),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF2A52A0).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.2))),
              child: Center(child: Icon(Icons.directions_bike_rounded, color: const Color(0xFF7AA8F0), size: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dl, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Text('${dist.toStringAsFixed(1)} km', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text('  ·  ${spd.toStringAsFixed(1)} km/h', style: TextStyle(fontSize: 13, color: c.textSecondary)),
              ]),
            ])),
            if (ride['terrain'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2A52A0).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                child: Text(ride['terrain'], style: const TextStyle(fontSize: 11, color: Color(0xFF7AA8F0))),
              ),
          ]),
        );
      },
    );
  }

  Widget _buildBadgesTab(AppColors c) {
    final xp      = _totalXP;
    final cur     = _currentLevel;
    final next    = _nextLevel;
    final curXP   = cur['xp'] as int;
    final nextXP  = next != null ? next['xp'] as int : curXP;
    final pct     = next != null ? ((xp - curXP) / (nextXP - curXP)).clamp(0.0, 1.0) : 1.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 108),
      children: [
        // ── XP / Level card ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1A3A6B), Color(0xFF0A1628)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(cur['icon'] as String, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LEVEL ${(cur['index'] as int) + 1}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7AA8F0), letterSpacing: 1.2)),
                Text(cur['name'] as String,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${xp.toStringAsFixed(0)} XP',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('total km', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
              ]),
            ]),
            const SizedBox(height: 18),
            // Progress bar
            Stack(children: [
              Container(height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(height: 8, decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2A52A0), Color(0xFF7AA8F0)]),
                  borderRadius: BorderRadius.circular(4),
                )),
              ),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(pct * 100).toStringAsFixed(0)}% to next level',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
              if (next != null)
                Text('${next['icon']} ${next['name']} at $nextXP km',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)))
              else
                Text('MAX LEVEL 👑', style: TextStyle(fontSize: 11, color: const Color(0xFF7AA8F0).withValues(alpha: 0.8))),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        Text('Badges', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
        const SizedBox(height: 12),
        // ── Badge grid ─────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: _trophies.length,
          itemBuilder: (_, i) {
            final trophy = _trophies[i];
            final unlocked = _unlockedTrophies.contains(trophy['id']);
            return GestureDetector(
              onTap: unlocked ? () => _showReward(trophy) : null,
              child: Opacity(
            opacity: unlocked ? 1.0 : 0.35,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: unlocked ? const Color(0xFF2A52A0).withValues(alpha: 0.15) : c.panelBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: unlocked ? const Color(0xFF7AA8F0).withValues(alpha: 0.4) : c.panelBorder),
                boxShadow: unlocked ? [BoxShadow(color: const Color(0xFF7AA8F0).withValues(alpha: 0.1), blurRadius: 12)] : [],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Text(trophy['icon'], style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(trophy['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(trophy['desc'], style: TextStyle(fontSize: 10, color: c.textMuted), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (unlocked) ...[
                  const SizedBox(height: 6),
                  const Text('🎁 reward', style: TextStyle(fontSize: 10, color: Color(0xFF7AA8F0))),
                ],
              ]),
            ),
          ),
        );
      },
    ),
  ],
    );
  }

  Widget _buildChallengesTab(AppColors c) {
    final monthGoal = double.tryParse(_monthlyGoal) ?? 0;
    final weekGoal  = double.tryParse(_weeklyGoal) ?? 0;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 108),
      children: [
        // Goals progress
        if (monthGoal > 0 || weekGoal > 0) ...[
          Text('Goals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
          const SizedBox(height: 12),
          if (weekGoal > 0) _goalCard(c, 'This week', _weekDist, weekGoal),
          if (weekGoal > 0) const SizedBox(height: 10),
          if (monthGoal > 0) _goalCard(c, 'This month', _monthDist, monthGoal),
          const SizedBox(height: 20),
        ],
        Text('Active challenges', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
        const SizedBox(height: 12),
        ..._challenges.map((ch) {
          final progress = _challengeProgress(ch);
          final target = ch['target'] as int;
          final done = progress >= target;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: done ? const Color(0xFF2A52A0).withValues(alpha: 0.1) : c.panelBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: done ? const Color(0xFF7AA8F0).withValues(alpha: 0.3) : c.panelBorder),
            ),
            child: Column(children: [
              Row(children: [
                Text(ch['icon'], style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ch['name'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  Text(ch['reward'], style: TextStyle(fontSize: 12, color: c.textMuted)),
                ])),
                Text('$progress/$target', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: done ? const Color(0xFF7AA8F0) : c.textSecondary)),
              ]),
              const SizedBox(height: 12),
              Stack(children: [
                Container(height: 6, decoration: BoxDecoration(color: c.progressBg, borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(widthFactor: (progress / target).clamp(0.0, 1.0), child: Container(height: 6, decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2A52A0), Color(0xFF7AA8F0)]),
                  borderRadius: BorderRadius.circular(3),
                ))),
              ]),
            ]),
          );
        }),
      ],
    );
  }

  // ── XP / Level ───────────────────────────────────────────────────────────────
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

  double get _totalXP => _rides.fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble());

  Map<String, dynamic> get _currentLevel {
    final xp = _totalXP;
    for (int i = _levels.length - 1; i >= 0; i--) {
      if (xp >= (_levels[i]['xp'] as int)) return {..._levels[i], 'index': i};
    }
    return {..._levels[0], 'index': 0};
  }

  Map<String, dynamic>? get _nextLevel {
    final idx = _currentLevel['index'] as int;
    return idx < _levels.length - 1 ? {..._levels[idx + 1], 'index': idx + 1} : null;
  }

  double get _weekDist {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return _rides.where((r) { final d = DateTime.tryParse(r['date'] ?? '') ?? DateTime(2000); return !d.isBefore(start); }).fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble());
  }

  double get _monthDist {
    final now = DateTime.now();
    return _rides.where((r) { final d = DateTime.tryParse(r['date'] ?? '') ?? DateTime(2000); return d.month == now.month && d.year == now.year; }).fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble());
  }

  Widget _goalCard(AppColors c, String label, double cur, double goal) {
    final pct = (cur / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.panelBorder)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
          Text('${cur.toStringAsFixed(1)} / ${goal.toStringAsFixed(0)} km', style: TextStyle(fontSize: 13, color: pct >= 1 ? const Color(0xFF7AA8F0) : c.textSecondary)),
        ]),
        const SizedBox(height: 10),
        Stack(children: [
          Container(height: 8, decoration: BoxDecoration(color: c.progressBg, borderRadius: BorderRadius.circular(4))),
          FractionallySizedBox(widthFactor: pct, child: Container(height: 8, decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2A52A0), Color(0xFF7AA8F0)]),
            borderRadius: BorderRadius.circular(4),
          ))),
        ]),
      ]),
    );
  }

  Widget _buildBikeTab(AppColors c) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 108),
      children: [
        if (!_editing) ...[
          _bikeInfoCard(c),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => setState(() => _editing = true),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit bike info'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF7AA8F0), side: const BorderSide(color: Color(0xFF7AA8F0)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ] else ...[
          _editField(c, 'Model', _bikeModelCtrl, 'e.g. Trek Domane SL5'),
          const SizedBox(height: 10),
          _editField(c, 'Type', _bikeTypeCtrl, 'Road, Gravel, MTB...'),
          const SizedBox(height: 10),
          _editField(c, 'Frame size', _bikeSizeCtrl, 'e.g. 54cm / M'),
          const SizedBox(height: 10),
          _editField(c, 'Weight (kg)', _bikeWeightCtrl, 'e.g. 8.2'),
          const SizedBox(height: 10),
          _editField(c, 'Year', _bikeYearCtrl, 'e.g. 2022'),
          const SizedBox(height: 10),
          _editField(c, 'Groupset', _bikeGroupsetCtrl, 'e.g. Shimano 105'),
          const SizedBox(height: 10),
          _editField(c, 'Wheels', _bikeWheelsCtrl, 'e.g. Mavic Aksium'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saveProfile,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A52A0), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          )),
        ],
      ],
    );
  }

  Widget _bikeInfoCard(AppColors c) {
    final rows = [
      ['Model', _bikeModel], ['Type', _bikeType], ['Frame size', _bikeSize],
      ['Weight', _bikeWeight.isEmpty ? '' : '$_bikeWeight kg'],
      ['Year', _bikeYear], ['Groupset', _bikeGroupset], ['Wheels', _bikeWheels],
    ];
    final filled = rows.where((r) => r[1].isNotEmpty).toList();
    if (filled.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: c.panelBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.panelBorder)),
        child: Column(children: [
          Icon(Icons.directions_bike_outlined, size: 40, color: c.textMuted),
          const SizedBox(height: 12),
          Text('No bike info yet', style: TextStyle(fontSize: 15, color: c.textSecondary)),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(color: c.panelBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.panelBorder)),
      child: Column(children: filled.asMap().entries.map((e) {
        final isLast = e.key == filled.length - 1;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(e.value[0], style: TextStyle(fontSize: 13, color: c.textMuted)),
              Text(e.value[1], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ]),
          ),
          if (!isLast) Divider(height: 1, color: c.divider, indent: 16, endIndent: 16),
        ]);
      }).toList()),
    );
  }
}

// ── Sliding pill tab bar ──────────────────────────────────────────────────────
class _SlidingTabBar extends StatefulWidget {
  final TabController controller;
  final List<String> tabs;
  final AppColors c;

  const _SlidingTabBar({required this.controller, required this.tabs, required this.c});

  @override
  State<_SlidingTabBar> createState() => _SlidingTabBarState();
}

class _SlidingTabBarState extends State<_SlidingTabBar> {
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.animation!.addListener(_onAnim);
  }

  @override
  void dispose() {
    widget.controller.animation!.removeListener(_onAnim);
    super.dispose();
  }

  void _onAnim() {
    if (mounted) setState(() => _offset = widget.controller.animation!.value);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final count = widget.tabs.length;

    return LayoutBuilder(builder: (_, constraints) {
      final totalW = constraints.maxWidth;
      final pillW = totalW / count;

      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: c.isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(children: [
          // Sliding pill
          AnimatedBuilder(
            animation: widget.controller.animation!,
            builder: (_, __) => Positioned(
              left: _offset * pillW + 2,
              top: 2,
              bottom: 2,
              width: pillW - 4,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A52A0),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
          // Labels
          Row(
            children: List.generate(count, (i) {
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.controller.animateTo(i),
                  child: AnimatedBuilder(
                    animation: widget.controller.animation!,
                    builder: (_, __) {
                      final selected = (_offset - i).abs() < 0.5;
                      return Center(
                        child: Text(
                          widget.tabs[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? Colors.white : c.textMuted,
                            fontFamily: 'DMSans',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ]),
      );
    });
  }
}