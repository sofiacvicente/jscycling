import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'app_theme.dart';

/// A full-screen GPS tracker that records the route during a ride.
/// Returns a List of Map(String, double) with lat/lng points when stopped.
class RideTrackerScreen extends StatefulWidget {
  const RideTrackerScreen({super.key});

  @override
  State<RideTrackerScreen> createState() => _RideTrackerScreenState();
}

class _RideTrackerScreenState extends State<RideTrackerScreen> {
  final List<Map<String, double>> _route = [];
  StreamSubscription<Position>? _posStream;
  bool _tracking = false;
  int _seconds = 0;
  Timer? _timer;
  double _distance = 0;
  Position? _lastPos;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _posStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
  }

  void _start() {
    setState(() => _tracking = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      if (_lastPos != null) {
        _distance += Geolocator.distanceBetween(
          _lastPos!.latitude, _lastPos!.longitude,
          pos.latitude, pos.longitude,
        ) / 1000;
      }
      _lastPos = pos;
      setState(() => _route.add({'lat': pos.latitude, 'lng': pos.longitude}));
    });
  }

  void _stop() {
    _posStream?.cancel();
    _timer?.cancel();
    Navigator.pop(context, {
      'route': _route,
      'distance': _distance,
      'duration': _seconds,
    });
  }

  String _fmtTime(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.panelBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.panelBorder)),
                  child: Icon(Icons.close, color: c.textSecondary, size: 18),
                ),
              ),
              const SizedBox(width: 16),
              Text('Track Ride', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
            ]),
          ),

          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Timer
              Text(_fmtTime(_seconds), style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: c.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 8),
              Text('elapsed', style: TextStyle(fontSize: 14, color: c.textMuted)),
              const SizedBox(height: 40),

              // Stats
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _stat(c, '${_distance.toStringAsFixed(2)} km', 'Distance'),
                Container(width: 1, height: 40, color: c.divider, margin: const EdgeInsets.symmetric(horizontal: 32)),
                _stat(c, '${_route.length}', 'GPS points'),
              ]),

              const SizedBox(height: 60),

              // Start/Stop button
              GestureDetector(
                onTap: _tracking ? _stop : _start,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: _tracking ? Colors.red : const Color(0xFF2A52A0),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: (_tracking ? Colors.red : const Color(0xFF2A52A0)).withValues(alpha: 0.4),
                      blurRadius: 24, spreadRadius: 4,
                    )],
                  ),
                  child: Icon(_tracking ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 16),
              Text(_tracking ? 'Tap to stop and save' : 'Tap to start recording', style: TextStyle(fontSize: 13, color: c.textMuted)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(AppColors c, String value, String label) => Column(children: [
    Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.textPrimary)),
    Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
  ]);
}