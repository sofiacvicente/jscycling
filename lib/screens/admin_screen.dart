import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _rides = [];
  List<String> _unlockedIds = [];
  bool _loading = true;

  static const String _adminEmail = 'svicente005@gmail.com';

  final List<Map<String, dynamic>> _trophies = [
    {
      'id': 'first_ride',
      'name': 'First Ride',
      'icon': '🚴',
      'desc': 'Log your first ride.',
      'reward': 'Escolhes o jantar esta semana 🍕',
    },
    {
      'id': 'ten_rides',
      'name': '10 Rides',
      'icon': '🔟',
      'desc': 'Log 10 rides.',
      'reward': 'Cinema + snacks à escolha 🎬',
    },
    {
      'id': 'hundred_km',
      'name': '100 km',
      'icon': '💯',
      'desc': 'Accumulate 100 km.',
      'reward': 'Pequeno-almoço na cama ☕',
    },
    {
      'id': 'five_hundred_km',
      'name': '500 km',
      'icon': '🏅',
      'desc': 'Accumulate 500 km.',
      'reward': 'Jantar no restaurante favorito 🥂',
    },
    {
      'id': 'thousand_km',
      'name': '1000 km',
      'icon': '🏆',
      'desc': 'Accumulate 1000 km.',
      'reward': 'Viagem surpresa 🌍',
    },
    {
      'id': 'century',
      'name': 'Century',
      'icon': '⚡',
      'desc': 'Complete a 100 km ride.',
      'reward': 'Dia inteiro sem planos 🎯',
    },
    {
      'id': 'climber',
      'name': 'Climber',
      'icon': '⛰️',
      'desc': 'Accumulate 1000 m elevation.',
      'reward': 'Massagem nas costas 💆',
    },
    {
      'id': 'on_fire',
      'name': 'On Fire',
      'icon': '🔥',
      'desc': '7 day streak.',
      'reward': 'Fim de semana a escolher 🗓️',
    },
  ];

  final List<Map<String, dynamic>> _challenges = [
    {
      'name': '5 Rides This Month',
      'icon': '📅',
      'reward': 'Gelado gigante 🍦',
      'target': 5,
      'type': 'rides_month',
    },
    {
      'name': '200 km This Month',
      'icon': '🗺️',
      'reward': 'Noite de filmes 🎥',
      'target': 200,
      'type': 'distance_month',
    },
    {
      'name': '3 Rides This Week',
      'icon': '⚡',
      'reward': 'Eu trato de tudo 👑',
      'target': 3,
      'type': 'rides_week',
    },
  ];

  late List<Map<String, dynamic>> _editableTrophies;

  @override
  void initState() {
    super.initState();

    _editableTrophies = _trophies
        .map((t) => <String, dynamic>{...t})
        .toList();

    final email = FirebaseAuth.instance.currentUser?.email;

    if (email != _adminEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
      return;
    }

    _loadAll();
  }

  Future<void> _loadAll() async {
    final ridesSnap =
        await FirebaseFirestore.instance.collection('rides').get();

    _rides = ridesSnap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();

    try {
      final rewardsDoc =
          await FirebaseFirestore.instance.doc('config/rewards').get();

      if (rewardsDoc.exists) {
        final data = rewardsDoc.data()!;

        _editableTrophies = _editableTrophies.map((t) {
          return <String, dynamic>{
            ...t,
            'reward': data[t['id']] ?? t['reward'],
          };
        }).toList();
      }
    } catch (_) {}

    try {
      final unlockedDoc =
          await FirebaseFirestore.instance.doc('config/unlocked').get();

      if (unlockedDoc.exists) {
        _unlockedIds =
            List<String>.from(unlockedDoc.data()?['ids'] ?? <String>[]);
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveRewards() async {
    final data = <String, dynamic>{};

    for (final trophy in _editableTrophies) {
      data[trophy['id'].toString()] = trophy['reward'];
    }

    await FirebaseFirestore.instance.doc('config/rewards').set(data);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rewards saved!'),
        backgroundColor: Color(0xFF2A52A0),
      ),
    );
  }

  int _challengeProgress(Map<String, dynamic> challenge) {
    final now = DateTime.now();

    switch (challenge['type']) {
      case 'rides_month':
        return _rides.where((ride) {
          final date =
              DateTime.tryParse(ride['date']?.toString() ?? '') ??
                  DateTime(2000);
          return date.month == now.month && date.year == now.year;
        }).length;

      case 'distance_month':
        return _rides.where((ride) {
          final date =
              DateTime.tryParse(ride['date']?.toString() ?? '') ??
                  DateTime(2000);
          return date.month == now.month && date.year == now.year;
        }).fold<double>(
          0.0,
          (total, ride) =>
              total + ((ride['distance'] as num?)?.toDouble() ?? 0.0),
        ).round();

      case 'rides_week':
        final startOfWeek =
            now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );

        return _rides.where((ride) {
          final date =
              DateTime.tryParse(ride['date']?.toString() ?? '') ??
                  DateTime(2000);
          return !date.isBefore(start);
        }).length;

      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(AppTheme.of(context).isDark);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7AA8F0),
                ),
              )
            : SingleChildScrollView(
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
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white54,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Panel',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              Text(
                                'Manage trophies and challenges.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _glassPanel(
                      c,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(c, 'Trophies & Rewards'),
                          ..._trophies.map((trophy) {
                            final unlocked =
                                _unlockedIds.contains(trophy['id']);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Text(
                                    trophy['icon'].toString(),
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trophy['name'].toString(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          trophy['desc'].toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    unlocked ? '✓ Unlocked' : 'Locked',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: unlocked
                                          ? const Color(0xFF7AA8F0)
                                          : Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _glassPanel(
                      c,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(c, 'Edit Rewards'),
                          ..._editableTrophies.asMap().entries.map((entry) {
                            final index = entry.key;
                            final trophy = entry.value;
                            final reward =
                                trophy['reward']?.toString() ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${trophy['icon']} ${trophy['name']}'
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: c.textMuted,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    initialValue: reward,
                                    onChanged: (value) {
                                      _editableTrophies[index]['reward'] =
                                          value;
                                    },
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: c.inputBg,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: c.inputBorder,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: c.inputBorder,
                                        ),
                                      ),
                                      focusedBorder:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF7AA8F0),
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveRewards,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF2A52A0),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Save rewards',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _glassPanel(
                      c,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(c, 'Active Challenges'),
                          ..._challenges.map((challenge) {
                            final progress =
                                _challengeProgress(challenge);
                            final target =
                                (challenge['target'] as num).toInt();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Text(
                                    challenge['icon'].toString(),
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          challenge['name'].toString(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          challenge['reward'].toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$progress / $target',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _glassPanel(
                      c,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(c, 'Unlocked by him'),
                          if (_unlockedIds.isEmpty)
                            Text(
                              'Nothing unlocked yet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: c.textSecondary,
                              ),
                            )
                          else
                            ..._unlockedIds.map((id) {
                              final trophy = _trophies.firstWhere(
                                (trophy) => trophy['id'] == id,
                                orElse: () => <String, dynamic>{},
                              );

                              if (trophy.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      trophy['icon'].toString(),
                                      style:
                                          const TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            trophy['name'].toString(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: c.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            trophy['reward'].toString(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: c.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Text(
                                      '✓',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF7AA8F0),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c.textMuted,
          letterSpacing: 0.8,
        ),
      ),
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
}
