import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;
  String _filterTerrain = 'All';
  String _sortBy = 'date'; // date | distance | duration

  final _terrainFilters = ['All', 'Road', 'Mountain', 'City', 'Gravel'];

  @override
  void initState() {
    super.initState();
    _loadRides();
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

  Future<void> _deleteRide(String id) async {
    await FirebaseFirestore.instance.collection('rides').doc(id).delete();
    _loadRides();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _filterTerrain == 'All'
        ? List<Map<String, dynamic>>.from(_rides)
        : _rides.where((r) => r['terrain'] == _filterTerrain).toList();
    switch (_sortBy) {
      case 'distance':
        list.sort((a, b) => (b['distance'] ?? 0).compareTo(a['distance'] ?? 0));
        break;
      case 'duration':
        list.sort((a, b) => (b['duration'] ?? 0).compareTo(a['duration'] ?? 0));
        break;
      default:
        list.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    }
    return list;
  }

  String _fmt(int secs) {
    final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
    if (h == 0 && m == 0) return '${s}s';
    if (h == 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
    if (s == 0) return '${h}h ${m}m';
    return '${h}h ${m}m ${s}s';
  }

  String _avgSpeed(Map<String, dynamic> r) {
    final d = (r['distance'] ?? 0).toDouble();
    final t = (r['duration'] ?? 0) as int;
    if (t == 0 || d == 0) return '—';
    return '${(d / (t / 3600)).toStringAsFixed(1)} km/h';
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final d = DateTime.parse(raw);
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${days[d.weekday-1]}, ${d.day} ${mo[d.month-1]} ${d.year}';
    } catch (_) { return raw; }
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

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    final rides = _filtered;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7AA8F0)))
          : Stack(children: [
              RefreshIndicator(
                onRefresh: _loadRides,
                color: const Color(0xFF7AA8F0),
                child: CustomScrollView(slivers: [
                  // ── Header ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('History', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.textPrimary)),
                            Text('${_rides.length} rides total', style: TextStyle(fontSize: 13, color: c.textMuted)),
                          ]),
                          GestureDetector(
                            onTap: () => _showSortSheet(context, c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: c.panelBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.panelBorder),
                              ),
                              child: Row(children: [
                                Icon(Icons.sort_rounded, size: 16, color: c.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  _sortBy == 'date' ? 'Date' : _sortBy == 'distance' ? 'Distance' : 'Duration',
                                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Terrain filter chips ───────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _terrainFilters.map((f) {
                            final active = _filterTerrain == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _filterTerrain = f),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: active ? const Color(0xFF2A52A0) : c.panelBg,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: active ? const Color(0xFF7AA8F0) : c.panelBorder),
                                  ),
                                  child: Text(
                                    f == 'All' ? 'All' : '${_terrainIcon(f)}  $f',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                      color: active ? Colors.white : c.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ── Ride cards ─────────────────────────────────────────
                  if (rides.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(children: [
                          const Icon(Icons.map_outlined, size: 48, color: Color(0xFF7AA8F0)),
                          const SizedBox(height: 12),
                          Text('No rides found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Try a different filter.', style: TextStyle(fontSize: 13, color: c.textMuted)),
                        ]),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _rideCard(context, rides[i], c),
                          ),
                          childCount: rides.length,
                        ),
                      ),
                    ),

                  // ── Bottom spacer ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: SizedBox(height: botPad + 120),
                  ),
                ]),
              ),

              // ── Floating Map pill ──────────────────────────────────────
              Positioned(
                bottom: botPad + 88,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AllRidesMapScreen(rides: _rides),
                    )),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2C4A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2A52A0).withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.map_rounded, color: Color(0xFF7AA8F0), size: 17),
                        SizedBox(width: 8),
                        Text('Map', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _rideCard(BuildContext context, Map<String, dynamic> ride, AppColors c) {
    final terrain = ride['terrain'] as String?;
    final hasRoute = ride['route'] != null && (ride['route'] as List).isNotEmpty;
    final hasPhoto = ride['photoUrl'] != null;
    final hasNotes = ride['notes'] != null && ride['notes'].toString().isNotEmpty;
    final hasHR    = (ride['heartrate'] ?? 0) != 0;

    return Container(
      decoration: BoxDecoration(
        color: c.panelBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.panelBorder),
        boxShadow: c.panelShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Map / photo preview ──────────────────────────────────────────
        if (hasPhoto || hasRoute)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: hasPhoto
                  ? Image.network(ride['photoUrl'], fit: BoxFit.cover)
                  : _routePreview(ride, c),
            ),
          )
        else
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF2A52A0).withValues(alpha: 0.3), const Color(0xFF0A1628).withValues(alpha: 0.5)],
                ),
              ),
              child: Center(child: Text(_terrainIcon(terrain), style: const TextStyle(fontSize: 36))),
            ),
          ),

        // ── Info ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_formatDate(ride['date'] as String?),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
              if (terrain != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A52A0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3)),
                  ),
                  child: Text('${_terrainIcon(terrain)} $terrain',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF7AA8F0))),
                ),
              ],
            ])),
            IconButton(
              icon: Icon(Icons.edit_outlined, color: const Color(0xFF7AA8F0).withValues(alpha: 0.8), size: 20),
              onPressed: () => _showEditSheet(context, ride, c),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.withValues(alpha: 0.6), size: 20),
              onPressed: () => _confirmDelete(context, ride['id'], c),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ]),
        ),

        // ── 2×2 stats ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            _statCell(c, '${ride['distance'] ?? 0} km', 'Distance', Icons.straighten_rounded),
            _divider(c),
            _statCell(c, _fmt(ride['duration'] ?? 0), 'Duration', Icons.timer_outlined),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Row(children: [
            _statCell(c, '${ride['elevation'] ?? 0} m', 'Elevation', Icons.landscape_outlined),
            _divider(c),
            _statCell(c, _avgSpeed(ride), 'Avg speed', Icons.speed_rounded),
          ]),
        ),

        // ── HR + cadence ─────────────────────────────────────────────────
        if (hasHR)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              Icon(Icons.favorite_rounded, size: 13, color: Colors.red.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text('${ride['heartrate']} bpm', style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(width: 14),
              Icon(Icons.loop_rounded, size: 13, color: c.textMuted),
              const SizedBox(width: 5),
              Text('${ride['cadence'] ?? 0} rpm', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ]),
          ),

        // ── Notes ────────────────────────────────────────────────────────
        if (hasNotes)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(ride['notes'],
                style: TextStyle(fontSize: 13, color: c.textSecondary, fontStyle: FontStyle.italic)),
          ),

        const SizedBox(height: 14),
      ]),
    );
  }

  // Simple route preview using canvas (draws the GPS points if available)
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
          : Center(child: Text(_terrainIcon(ride['terrain']), style: const TextStyle(fontSize: 36))),
    );
  }

  void _showSortSheet(BuildContext context, AppColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
          const SizedBox(height: 16),
          ...[('date', 'Date', Icons.calendar_today_rounded), ('distance', 'Distance', Icons.straighten_rounded), ('duration', 'Duration', Icons.timer_outlined)].map((opt) {
            final active = _sortBy == opt.$1;
            return GestureDetector(
              onTap: () { setState(() => _sortBy = opt.$1); Navigator.pop(context); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF2A52A0).withValues(alpha: 0.15) : c.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: active ? const Color(0xFF7AA8F0).withValues(alpha: 0.4) : c.inputBorder),
                ),
                child: Row(children: [
                  Icon(opt.$3, size: 18, color: active ? const Color(0xFF7AA8F0) : c.textSecondary),
                  const SizedBox(width: 12),
                  Text(opt.$2, style: TextStyle(fontSize: 15, color: active ? const Color(0xFF7AA8F0) : c.textPrimary, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                  const Spacer(),
                  if (active) const Icon(Icons.check_rounded, color: Color(0xFF7AA8F0), size: 18),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }

  void _showEditSheet(BuildContext context, Map<String, dynamic> ride, AppColors c) {
    final distCtrl     = TextEditingController(text: '${ride['distance'] ?? ''}');
    final durHCtrl     = TextEditingController(text: '${((ride['duration'] ?? 0) as int) ~/ 3600}');
    final durMCtrl     = TextEditingController(text: '${(((ride['duration'] ?? 0) as int) % 3600) ~/ 60}');
    final elevCtrl     = TextEditingController(text: '${ride['elevation'] ?? ''}');
    final hrCtrl       = TextEditingController(text: '${ride['heartrate'] ?? ''}');
    final cadCtrl      = TextEditingController(text: '${ride['cadence'] ?? ''}');
    final notesCtrl    = TextEditingController(text: ride['notes'] ?? '');
    String terrain     = ride['terrain'] ?? '';
    String? photoUrl   = ride['photoUrl'] as String?;
    File?  newPhoto;
    bool saving        = false;
    final picker       = ImagePicker();

    Future<String?> uploadPhoto(File f) async {
      final ref = FirebaseStorage.instance.ref().child('ride_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(f);
      return ref.getDownloadURL();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              color: c.isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Edit Ride', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
              Text(_formatDate(ride['date'] as String?), style: TextStyle(fontSize: 13, color: c.textMuted)),
              const SizedBox(height: 20),

              // Distance
              _sheetLabel(c, 'Distance (km)'),
              _sheetInput(c, distCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),

              // Duration
              _sheetLabel(c, 'Duration'),
              Row(children: [
                Expanded(child: _sheetInput(c, durHCtrl, hint: 'h', keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _sheetInput(c, durMCtrl, hint: 'min', keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),

              // Elevation
              _sheetLabel(c, 'Elevation (m)'),
              _sheetInput(c, elevCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 12),

              // Heart rate + cadence
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sheetLabel(c, 'Heart rate (bpm)'),
                  _sheetInput(c, hrCtrl, keyboardType: TextInputType.number),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sheetLabel(c, 'Cadence (rpm)'),
                  _sheetInput(c, cadCtrl, keyboardType: TextInputType.number),
                ])),
              ]),
              const SizedBox(height: 12),

              // Terrain
              _sheetLabel(c, 'Terrain'),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['road', 'mountain', 'city', 'gravel'].map((t) {
                    final icons = {'road':'🛣️','mountain':'⛰️','city':'🏙️','gravel':'🪨'};
                    final active = terrain == t;
                    return GestureDetector(
                      onTap: () => setSheet(() => terrain = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF2A52A0) : c.inputBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: active ? const Color(0xFF7AA8F0) : c.inputBorder),
                        ),
                        child: Text('${icons[t]} $t', style: TextStyle(fontSize: 13, color: active ? Colors.white : c.textSecondary, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Photo
              _sheetLabel(c, 'Photo'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
                  if (picked != null) setSheet(() => newPhoto = File(picked.path));
                },
                child: Container(
                  height: 130,
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.inputBorder),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(fit: StackFit.expand, children: [
                    if (newPhoto != null)
                      Image.file(newPhoto!, fit: BoxFit.cover)
                    else if (photoUrl != null)
                      Image.network(photoUrl!, fit: BoxFit.cover)
                    else
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo_outlined, size: 28, color: c.textMuted),
                        const SizedBox(height: 6),
                        Text('Tap to add photo', style: TextStyle(fontSize: 12, color: c.textMuted)),
                      ]),
                    if (newPhoto != null || photoUrl != null)
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => setSheet(() { newPhoto = null; photoUrl = null; }),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // Notes
              _sheetLabel(c, 'Notes'),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'How did it go?',
                  hintStyle: TextStyle(color: c.textMuted),
                  filled: true,
                  fillColor: c.inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7AA8F0))),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    setSheet(() => saving = true);
                    final h = int.tryParse(durHCtrl.text) ?? 0;
                    final m = int.tryParse(durMCtrl.text) ?? 0;
                    String? finalPhotoUrl = photoUrl;
                    if (newPhoto != null) finalPhotoUrl = await uploadPhoto(newPhoto!);
                    final updateData = <String, dynamic>{
                      'distance':  double.tryParse(distCtrl.text) ?? ride['distance'],
                      'duration':  h * 3600 + m * 60,
                      'elevation': int.tryParse(elevCtrl.text) ?? ride['elevation'] ?? 0,
                      'heartrate': int.tryParse(hrCtrl.text) ?? 0,
                      'cadence':   int.tryParse(cadCtrl.text) ?? 0,
                      'terrain':   terrain.isEmpty ? null : terrain,
                      'notes':     notesCtrl.text.trim(),
                    };
                    if (finalPhotoUrl != null) {
                      updateData['photoUrl'] = finalPhotoUrl;
                    } else if (ride['photoUrl'] != null && photoUrl == null) {
                      updateData['photoUrl'] = FieldValue.delete();
                    }
                    await FirebaseFirestore.instance.collection('rides').doc(ride['id']).update(updateData);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadRides();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A52A0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
    );
  }

  Widget _sheetLabel(AppColors c, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textMuted, letterSpacing: 0.8)),
  );

  Widget _sheetInput(AppColors c, TextEditingController ctrl, {String? hint, TextInputType? keyboardType}) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: TextStyle(color: c.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textMuted),
      filled: true,
      fillColor: c.inputBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7AA8F0))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );

  void _confirmDelete(BuildContext context, String id, AppColors c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete ride?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('This cannot be undone.', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () { Navigator.pop(context); _deleteRide(id); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _statCell(AppColors c, String value, String label, IconData icon) =>
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: const Color(0xFF7AA8F0)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
            Text(label, style: TextStyle(fontSize: 10, color: c.textMuted)),
          ]),
        ]),
      ));

  Widget _divider(AppColors c) =>
      Container(width: 1, height: 40, color: c.divider, margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ── Route preview painter ─────────────────────────────────────────────────────
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

    const pad = 16.0;
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

    // Start/end dots
    final dotPaint = Paint()..color = Colors.greenAccent..style = PaintingStyle.fill;
    final endPaint  = Paint()..color = const Color(0xFFFF6B35)..style = PaintingStyle.fill;
    canvas.drawCircle(toCanvas(pts.first), 5, dotPaint);
    canvas.drawCircle(toCanvas(pts.last), 5, endPaint);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.pts != pts;
}
// ── All Rides Map Screen ──────────────────────────────────────────────────────
class AllRidesMapScreen extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  const AllRidesMapScreen({super.key, required this.rides});

  List<List<Offset>> get _allRoutes {
    final routes = <List<Offset>>[];
    for (final ride in rides) {
      final raw = ride['route'] as List? ?? [];
      final pts = raw.map((p) {
        if (p is Map) return Offset((p['lng'] ?? 0.0).toDouble(), (p['lat'] ?? 0.0).toDouble());
        return Offset.zero;
      }).where((o) => o != Offset.zero).toList();
      if (pts.length >= 2) routes.add(pts);
    }
    return routes;
  }

  @override
  Widget build(BuildContext context) {
    final routes = _allRoutes;
    final ridesWithRoute = rides.where((r) {
      final raw = r['route'] as List? ?? [];
      return raw.length >= 2;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF080E1A),
      body: Stack(
        children: [
          // Full-screen map canvas
          Positioned.fill(
            child: routes.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.map_outlined, size: 56, color: Color(0xFF7AA8F0)),
                      const SizedBox(height: 16),
                      Text('No GPS routes yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
                      const SizedBox(height: 8),
                      Text('Track rides using the GPS tracker\nto see them here.',
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
                          textAlign: TextAlign.center),
                    ]),
                  )
                : CustomPaint(
                    painter: _AllRoutesPainter(routes),
                    child: const SizedBox.expand(),
                  ),
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [const Color(0xFF080E1A), const Color(0xFF080E1A).withValues(alpha: 0)],
                ),
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('All Routes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('${routes.length} route${routes.length == 1 ? "" : "s"} recorded',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                ]),
              ]),
            ),
          ),

          // Bottom ride list (horizontal chips)
          if (ridesWithRoute.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(0, 24, 0, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [const Color(0xFF080E1A), const Color(0xFF080E1A).withValues(alpha: 0)],
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 10),
                    child: Text('Routes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
                  ),
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: ridesWithRoute.length,
                      itemBuilder: (_, i) {
                        final ride = ridesWithRoute[i];
                        final dist = (ride['distance'] ?? 0).toDouble();
                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.3)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${dist.toStringAsFixed(1)} km',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text(ride['date'] ?? '', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
                          ]),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Painter: all routes overlaid ─────────────────────────────────────────────
class _AllRoutesPainter extends CustomPainter {
  final List<List<Offset>> routes;
  _AllRoutesPainter(this.routes);

  @override
  void paint(Canvas canvas, Size size) {
    if (routes.isEmpty) return;

    // Find global bounds across all routes
    double minLng = double.infinity, maxLng = -double.infinity;
    double minLat = double.infinity, maxLat = -double.infinity;
    for (final route in routes) {
      for (final p in route) {
        if (p.dx < minLng) minLng = p.dx;
        if (p.dx > maxLng) maxLng = p.dx;
        if (p.dy < minLat) minLat = p.dy;
        if (p.dy > maxLat) maxLat = p.dy;
      }
    }

    final rangeX = maxLng - minLng;
    final rangeY = maxLat - minLat;
    if (rangeX == 0 || rangeY == 0) return;

    const pad = 60.0;
    Offset toCanvas(Offset p) => Offset(
      pad + (p.dx - minLng) / rangeX * (size.width - pad * 2),
      size.height - pad - (p.dy - minLat) / rangeY * (size.height - pad * 2),
    );

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF080E1A),
    );

    // Subtle grid
    final gridPaint = Paint()
      ..color = const Color(0xFF7AA8F0).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Colors for each route
    final colors = [
      const Color(0xFF7AA8F0),
      const Color(0xFF4FC3F7),
      const Color(0xFF81C784),
      const Color(0xFFFFB74D),
      const Color(0xFFBA68C8),
      const Color(0xFFFF8A65),
      const Color(0xFF4DB6AC),
    ];

    // Draw each route with glow effect
    for (int r = 0; r < routes.length; r++) {
      final route = routes[r];
      final color = colors[r % colors.length];

      // Glow layer
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      // Main line
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(toCanvas(route[0]).dx, toCanvas(route[0]).dy);
      for (int i = 1; i < route.length; i++) {
        final p = toCanvas(route[i]);
        path.lineTo(p.dx, p.dy);
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);

      // Start dot (green) and end dot (orange)
      canvas.drawCircle(toCanvas(route.first), 5, Paint()..color = Colors.greenAccent..style = PaintingStyle.fill);
      canvas.drawCircle(toCanvas(route.first), 5, Paint()..color = Colors.black.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      canvas.drawCircle(toCanvas(route.last), 5, Paint()..color = const Color(0xFFFF6B35)..style = PaintingStyle.fill);
      canvas.drawCircle(toCanvas(route.last), 5, Paint()..color = Colors.black.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_AllRoutesPainter old) => old.routes != routes;
}