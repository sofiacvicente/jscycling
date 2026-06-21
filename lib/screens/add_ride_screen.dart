import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'app_theme.dart';
import 'ride_tracker_screen.dart';

class AddRideScreen extends StatefulWidget {
  const AddRideScreen({super.key});

  @override
  State<AddRideScreen> createState() => _AddRideScreenState();
}

class _AddRideScreenState extends State<AddRideScreen> {
  final _distanceController    = TextEditingController();
  final _hoursController       = TextEditingController();
  final _minutesController     = TextEditingController();
  final _secondsController     = TextEditingController();
  final _elevationController   = TextEditingController();
  final _cadenceController     = TextEditingController();
  final _heartrateController   = TextEditingController();
  final _maxHeartrateController= TextEditingController();
  final _notesController       = TextEditingController();

  DateTime _date       = DateTime.now();
  String   _terrain    = '';
  String   _difficulty = '';
  List<String> _skills = [];
  bool     _loading    = false;
  List<Map<String, double>> _route = [];
  File?    _photo;
  bool     _uploadingPhoto = false;

  final _picker = ImagePicker();

  final List<Map<String, String>> _terrains = [
    {'value': 'road',     'label': 'Road',     'icon': '🛣️'},
    {'value': 'mountain', 'label': 'Mountain', 'icon': '⛰️'},
    {'value': 'city',     'label': 'City',     'icon': '🏙️'},
    {'value': 'gravel',   'label': 'Gravel',   'icon': '🪨'},
  ];

  static const _difficulties = <Map<String, Object>>[
    {'value': 'soft',     'label': 'Soft',     'color': 0xFF4CAF50},
    {'value': 'moderate', 'label': 'Moderate', 'color': 0xFFFF9800},
    {'value': 'hard',     'label': 'Hard',     'color': 0xFFF44336},
  ];

  static final _allSkills = <Map<String, dynamic>>[
    {'value': 'hill_climbing',       'label': 'Hill Climbing',       'icon': Icons.landscape_rounded},
    {'value': 'braking_control',     'label': 'Braking Control',     'icon': Icons.speed_rounded},
    {'value': 'obstacle_navigation', 'label': 'Obstacle Navigation', 'icon': Icons.warning_amber_rounded},
    {'value': 'throttle_control',    'label': 'Throttle Control',    'icon': Icons.tune_rounded},
    {'value': 'technical_maneuvers', 'label': 'Technical Maneuvers', 'icon': Icons.sync_rounded},
    {'value': 'endurance',           'label': 'Endurance',           'icon': Icons.timer_rounded},
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  void _showImageSourceSheet(AppColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Add photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
              const SizedBox(height: 16),
              _sheetOption(c, Icons.camera_alt_rounded, 'Take a photo', () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              }),
              const SizedBox(height: 10),
              _sheetOption(c, Icons.photo_library_rounded, 'Choose from gallery', () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              }),
              if (_photo != null) ...[
                const SizedBox(height: 10),
                _sheetOption(c, Icons.delete_outline, 'Remove photo', () {
                  Navigator.pop(context);
                  setState(() => _photo = null);
                }, isDestructive: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption(AppColors c, IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.inputBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDestructive ? Colors.red : const Color(0xFF7AA8F0)),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, color: isDestructive ? Colors.red : c.textPrimary)),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadPhoto() async {
    if (_photo == null) return null;
    setState(() => _uploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('ride_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_photo!);
      final url = await ref.getDownloadURL();
      return url;
    } catch (_) {
      return null;
    } finally {
      setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_distanceController.text.isEmpty) return;
    setState(() => _loading = true);

    final totalSeconds =
        (int.tryParse(_hoursController.text)   ?? 0) * 3600 +
        (int.tryParse(_minutesController.text) ?? 0) * 60  +
        (int.tryParse(_secondsController.text) ?? 0);

    String? photoUrl;
    if (_photo != null) photoUrl = await _uploadPhoto();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final rideData = <String, dynamic>{
      'uid':          uid,
      'date':         _date.toIso8601String().substring(0, 10),
      'distance':     double.tryParse(_distanceController.text) ?? 0,
      'duration':     totalSeconds,
      'elevation':    int.tryParse(_elevationController.text)    ?? 0,
      'cadence':      int.tryParse(_cadenceController.text)      ?? 0,
      'heartrate':    int.tryParse(_heartrateController.text)    ?? 0,
      'maxHeartrate': int.tryParse(_maxHeartrateController.text) ?? 0,
      'terrain':      _terrain.isEmpty ? null : _terrain,
      'difficulty':   _difficulty.isEmpty ? null : _difficulty,
      'skills':       _skills.isEmpty ? null : _skills,
      'notes':        _notesController.text.trim(),
      'riders':       ['him'],
    };
    if (photoUrl != null) rideData['photoUrl'] = photoUrl;
    if (_route.isNotEmpty) rideData['route'] = _route;
    await FirebaseFirestore.instance.collection('rides').add(rideData);

    setState(() => _loading = false);
    _reset();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride saved!'), backgroundColor: Color(0xFF2A52A0)),
      );
    }
  }

  void _reset() {
    _distanceController.clear();
    _hoursController.clear();
    _minutesController.clear();
    _secondsController.clear();
    _elevationController.clear();
    _cadenceController.clear();
    _heartrateController.clear();
    _maxHeartrateController.clear();
    _notesController.clear();
    setState(() { _date = DateTime.now(); _terrain = ''; _difficulty = ''; _skills = []; _photo = null; _route = []; });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Ride', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: c.textPrimary)),
              Text('Log a ride in a few seconds.', style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.panelBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.panelBorder),
                  boxShadow: c.panelShadow,
                ),
                child: Column(
                  children: [
                    // Date
                    GestureDetector(
                      onTap: _pickDate,
                      child: _field(
                        c: c,
                        label: 'Date',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_date.day}/${_date.month}/${_date.year}',
                                style: TextStyle(color: c.textPrimary, fontSize: 15)),
                            Icon(Icons.calendar_today_outlined, color: c.textMuted, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // GPS Track button
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(builder: (_) => const RideTrackerScreen()),
                        );
                        if (result != null) {
                          setState(() {
                            _route = List<Map<String, double>>.from(result['route']);
                            _distanceController.text = (result['distance'] as double).toStringAsFixed(2);
                            final secs = result['duration'] as int;
                            _hoursController.text = (secs ~/ 3600).toString();
                            _minutesController.text = ((secs % 3600) ~/ 60).toString();
                            _secondsController.text = (secs % 60).toString();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _route.isNotEmpty
                              ? const Color(0xFF2A52A0).withValues(alpha: 0.2)
                              : c.inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _route.isNotEmpty
                                ? const Color(0xFF7AA8F0).withValues(alpha: 0.5)
                                : c.inputBorder,
                          ),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.gps_fixed_rounded,
                              size: 18,
                              color: _route.isNotEmpty ? const Color(0xFF7AA8F0) : c.textMuted),
                          const SizedBox(width: 10),
                          Text(
                            _route.isNotEmpty
                                ? '✓ Route recorded (${_route.length} pts)'
                                : 'Track GPS route',
                            style: TextStyle(
                              fontSize: 14,
                              color: _route.isNotEmpty ? const Color(0xFF7AA8F0) : c.textMuted,
                              fontWeight: _route.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _inputField(c: c, label: 'Distance (km)', controller: _distanceController, hint: 'e.g. 32.5', type: TextInputType.number),
                    const SizedBox(height: 14),

                    _labelText(c, 'Duration'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _durationInput(c, _hoursController, 'h')),
                      const SizedBox(width: 8),
                      Expanded(child: _durationInput(c, _minutesController, 'min')),
                      const SizedBox(width: 8),
                      Expanded(child: _durationInput(c, _secondsController, 'sec')),
                    ]),
                    const SizedBox(height: 14),

                    _inputField(c: c, label: 'Elevation (m)', controller: _elevationController, hint: 'e.g. 450', type: TextInputType.number),
                    const SizedBox(height: 14),

                    // Terrain
                    _labelText(c, 'Terrain'),
                    const SizedBox(height: 8),
                    Row(
                      children: _terrains.map((t) {
                        final active = _terrain == t['value'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _terrain = active ? '' : t['value']!),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: active ? const Color(0xFF2A52A0).withValues(alpha: 0.3) : c.inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: active ? const Color(0xFF7AA8F0) : c.inputBorder),
                              ),
                              child: Column(children: [
                                Text(t['icon']!, style: const TextStyle(fontSize: 18)),
                                const SizedBox(height: 4),
                                Text(t['label']!, style: TextStyle(fontSize: 10, color: c.textSecondary)),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Difficulty
                    _labelText(c, 'Difficulty'),
                    const SizedBox(height: 8),
                    Row(
                      children: _difficulties.map((d) {
                        final active = _difficulty == d['value'];
                        final color = Color(d['color'] as int);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _difficulty = active ? '' : d['value'] as String),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: active ? color.withValues(alpha: 0.12) : c.inputBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: active ? color : c.inputBorder,
                                  width: active ? 1.5 : 1,
                                ),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Container(
                                  width: 7, height: 7,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  d['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                    color: active ? color : c.textSecondary,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Skills
                    _labelText(c, 'Skills'),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.8,
                      children: _allSkills.map((s) {
                        final val = s['value'] as String;
                        final active = _skills.contains(val);
                        final icon = s['icon'] as IconData;
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (active) { _skills.remove(val); } else { _skills.add(val); }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF2A52A0).withValues(alpha: 0.15) : c.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active ? const Color(0xFF7AA8F0) : c.inputBorder,
                                width: active ? 1.5 : 1,
                              ),
                            ),
                            child: Center(child: Text(
                              s['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                color: active ? const Color(0xFF7AA8F0) : c.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    Row(children: [
                      Expanded(child: _inputField(c: c, label: 'Cadence (rpm)', controller: _cadenceController, hint: '85', type: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: _inputField(c: c, label: 'Avg HR (bpm)',  controller: _heartrateController, hint: '145', type: TextInputType.number)),
                    ]),
                    const SizedBox(height: 14),

                    _inputField(c: c, label: 'Max HR (bpm)', controller: _maxHeartrateController, hint: '172', type: TextInputType.number),
                    const SizedBox(height: 14),

                    // Notes
                    _labelText(c, 'Notes'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: TextStyle(color: c.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Weather, route, pace...',
                        hintStyle: TextStyle(color: c.textMuted),
                        filled: true,
                        fillColor: c.inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7AA8F0))),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Photo
                    _labelText(c, 'Photo'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showImageSourceSheet(c),
                      child: _photo != null
                          ? Stack(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_photo!, height: 180, width: double.infinity, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8, right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _photo = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ])
                          : Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: c.inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.inputBorder, style: BorderStyle.solid),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 28, color: c.textMuted),
                                  const SizedBox(height: 6),
                                  Text('Camera or gallery', style: TextStyle(fontSize: 13, color: c.textMuted)),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_loading || _uploadingPhoto) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A52A0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: (_loading || _uploadingPhoto)
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save ride', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    side: BorderSide(color: c.inputBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Reset', style: TextStyle(color: c.textSecondary)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labelText(AppColors c, String text) => Text(
    text.toUpperCase(),
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted, letterSpacing: 0.6),
  );

  Widget _field({required AppColors c, required String label, required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _labelText(c, label),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: c.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.inputBorder)),
        child: child,
      ),
    ]);
  }

  Widget _inputField({required AppColors c, required String label, required TextEditingController controller, required String hint, TextInputType? type}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _labelText(c, label),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(color: c.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textMuted),
          filled: true, fillColor: c.inputBg,
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7AA8F0))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    ]);
  }

  Widget _durationInput(AppColors c, TextEditingController controller, String unit) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: '0', hintStyle: TextStyle(color: c.textMuted),
            filled: true, fillColor: c.inputBg,
            border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.inputBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7AA8F0))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(unit, style: TextStyle(color: c.textMuted, fontSize: 13)),
    ]);
  }
}