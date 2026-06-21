import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() { _loading = false; _error = 'Not logged in.'; });
        return;
      }
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
      setState(() { _loading = false; _error = 'Error loading stats: $e'; });
    }
  }

  double get _totalDistance  => _rides.fold(0.0, (a, r) => a + (r['distance'] ?? 0).toDouble());
  int    get _totalDuration  => _rides.fold(0, (a, r) => a + ((r['duration'] ?? 0) as int));
  double get _longestRide    => _rides.fold(0.0, (b, r) => (r['distance'] ?? 0).toDouble() > b ? (r['distance'] ?? 0).toDouble() : b);
  double get _avgDistance    => _rides.isEmpty ? 0 : _totalDistance / _rides.length;
  double get _avgElevation   => _rides.isEmpty ? 0 : _rides.fold(0.0, (a, r) => a + (r['elevation'] ?? 0).toDouble()) / _rides.length;
  int    get _avgDuration    => _rides.isEmpty ? 0 : _totalDuration ~/ _rides.length;
  int    get _totalElevation => _rides.fold(0, (a, r) => a + ((r['elevation'] ?? 0) as int));

  String _fmt(int seconds) {
    final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  List<Map<String, dynamic>> get _sortedRides =>
      [..._rides]..sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7AA8F0)))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: c.textSecondary, fontSize: 14), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadRides, child: const Text('Retry')),
                      ]),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRides,
                    color: const Color(0xFF7AA8F0),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 110),
                      children: [
                        Text('Stats', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.textPrimary)),
                        Text('Your numbers at a glance.', style: TextStyle(fontSize: 13, color: c.textMuted)),
                        const SizedBox(height: 20),

                        if (_rides.isEmpty) ...[
                          _panel(c, child: Column(children: [
                            const Icon(Icons.bar_chart_rounded, size: 48, color: Color(0xFF7AA8F0)),
                            const SizedBox(height: 12),
                            Text('No data yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Add rides to start seeing stats.', style: TextStyle(fontSize: 13, color: c.textMuted)),
                          ])),
                        ] else ...[

                          // Hero: big distance
                          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    colors: [const Color(0xFF2A52A0).withValues(alpha: 0.6), const Color(0xFF080E1A).withValues(alpha: 0.8)],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: const Color(0xFF7AA8F0).withValues(alpha: 0.2)),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('TOTAL KM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF7AA8F0).withValues(alpha: 0.8), letterSpacing: 1.2)),
                                  const SizedBox(height: 6),
                                  RichText(text: TextSpan(children: [
                                    TextSpan(text: _totalDistance.toStringAsFixed(0), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                                    const TextSpan(text: ' km', style: TextStyle(fontSize: 16, color: Colors.white54)),
                                  ])),
                                  const SizedBox(height: 6),
                                  Text('across ${_rides.length} rides', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                                ]),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(children: [
                                _miniCard(c, '${_longestRide.toStringAsFixed(1)} km', 'Longest ride', Icons.route_rounded, const Color(0xFF7AA8F0)),
                                const SizedBox(height: 12),
                                _miniCard(c, '${_totalElevation}m', 'Total elevation', Icons.landscape_outlined, const Color(0xFFFF6B35)),
                              ]),
                            ),
                          ])),
                          const SizedBox(height: 12),

                          // Time stats
                          Row(children: [
                            Expanded(child: _miniCard(c, _fmt(_totalDuration), 'Total time', Icons.timer_rounded, const Color(0xFF7AA8F0))),
                            const SizedBox(width: 12),
                            Expanded(child: _miniCard(c, _fmt(_avgDuration), 'Avg duration', Icons.timer_outlined, const Color(0xFF94A3B8))),
                          ]),
                          const SizedBox(height: 12),

                          // Distance averages
                          Row(children: [
                            Expanded(child: _miniCard(c, '${_avgDistance.toStringAsFixed(1)} km', 'Avg distance', Icons.straighten_rounded, const Color(0xFF7AA8F0))),
                            const SizedBox(width: 12),
                            Expanded(child: _miniCard(c, '${_avgElevation.toStringAsFixed(0)} m', 'Avg elevation', Icons.landscape_outlined, const Color(0xFF94A3B8))),
                          ]),
                          const SizedBox(height: 20),

                          // Chart
                          _panel(c, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.show_chart_rounded, size: 16, color: Color(0xFF7AA8F0)),
                              const SizedBox(width: 8),
                              Text('Distance per ride', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                            ]),
                            const SizedBox(height: 4),
                            Text('km chronologically', style: TextStyle(fontSize: 12, color: c.textMuted)),
                            const SizedBox(height: 16),
                            SizedBox(height: 130, child: _buildLineChart(c)),
                          ])),
                          const SizedBox(height: 12),

                          // Heatmap
                          _panel(c, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF7AA8F0)),
                              const SizedBox(width: 8),
                              Text('Activity heatmap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                            ]),
                            const SizedBox(height: 4),
                            Text('Last 12 weeks', style: TextStyle(fontSize: 12, color: c.textMuted)),
                            const SizedBox(height: 14),
                            _buildHeatmap(c),
                          ])),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _miniCard(AppColors c, String value, String label, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.panelBorder),
        boxShadow: c.panelShadow,
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(fontSize: 11, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _panel(AppColors c, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.panelBorder),
        boxShadow: c.panelShadow,
      ),
      child: child,
    );
  }

  Widget _buildLineChart(AppColors c) {
    if (_sortedRides.isEmpty) return const SizedBox();
    final distances = _sortedRides.map((r) => (r['distance'] ?? 0).toDouble()).toList().cast<double>();
    final maxDist = distances.reduce((a, b) => a > b ? a : b);
    if (maxDist == 0) return const SizedBox();
    return CustomPaint(
      painter: _LineChartPainter(distances, maxDist, panelColor: c.panelBg),
      child: const SizedBox(width: double.infinity, height: 130),
    );
  }

  Widget _buildHeatmap(AppColors c) {
    final now = DateTime.now();
    final rideMap = <String, double>{};
    for (final ride in _rides) {
      final key = ride['date'] as String? ?? '';
      rideMap[key] = (rideMap[key] ?? 0) + (ride['distance'] ?? 0).toDouble();
    }
    final start = now.subtract(Duration(days: now.weekday - 1 + 11 * 7));
    final cells = List.generate(84, (i) => start.add(Duration(days: i)));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 12, crossAxisSpacing: 3, mainAxisSpacing: 3, childAspectRatio: 1,
      ),
      itemCount: cells.length,
      itemBuilder: (_, i) {
        final date = cells[i];
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final dist = rideMap[key] ?? 0;
        Color color;
        if (dist == 0) {
          color = c.checklistUnchecked;
        } else if (dist < 20) {
          color = const Color(0xFF2A52A0).withValues(alpha: 0.3);
        } else if (dist < 50) {
          color = const Color(0xFF2A52A0).withValues(alpha: 0.55);
        } else if (dist < 80) {
          color = const Color(0xFF2A52A0).withValues(alpha: 0.8);
        } else {
          color = const Color(0xFF7AA8F0);
        }
        return Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)));
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> distances;
  final double maxDist;
  final Color panelColor;

  _LineChartPainter(this.distances, this.maxDist, {required this.panelColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (distances.isEmpty) return;
    if (distances.length == 1) {
      final y = size.height - (distances.first / maxDist) * size.height * 0.9;
      canvas.drawCircle(Offset(size.width / 2, y), 5, Paint()..color = const Color(0xFF7AA8F0));
      return;
    }
    final linePaint = Paint()
      ..color = const Color(0xFF7AA8F0)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF7AA8F0).withValues(alpha: 0.3), const Color(0xFF7AA8F0).withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fill = Path();
    for (int i = 0; i < distances.length; i++) {
      final x = (i / (distances.length - 1)) * size.width;
      final y = size.height - (distances[i] / maxDist) * size.height * 0.88;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, linePaint);

    final dot = Paint()..color = const Color(0xFF7AA8F0)..style = PaintingStyle.fill;
    final border = Paint()..color = panelColor..style = PaintingStyle.stroke..strokeWidth = 2;
    for (int i = 0; i < distances.length; i++) {
      final x = (i / (distances.length - 1)) * size.width;
      final y = size.height - (distances[i] / maxDist) * size.height * 0.88;
      canvas.drawCircle(Offset(x, y), 4, dot);
      canvas.drawCircle(Offset(x, y), 4, border);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}