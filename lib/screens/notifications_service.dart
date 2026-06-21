import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Must be top-level for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

class NotificationsService {
  static final _messaging = FirebaseMessaging.instance;

  /// Call once on app start (after login)
  static Future<void> init() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Save FCM token to Firestore so you can send targeted pushes
    final token = await _messaging.getToken();
    await _saveToken(token);

    // Refresh token
    _messaging.onTokenRefresh.listen(_saveToken);

    // Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Foreground message: ${message.notification?.title}');
    });
  }

  static Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.doc('users/$uid').set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  /// Schedule a local reminder at 20:00 if no ride today
  static void scheduleRideReminder(List<Map<String, dynamic>> rides) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rodouHoje = rides.any((r) => r['date'] == today);
    if (rodouHoje) return;

    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day, 20, 0);
    final diff = target.difference(now);
    if (diff.isNegative) return;

    Future.delayed(diff, () {
      // FCM local notification via firebase_messaging foreground display
      debugPrint('Reminder: No ride today!');
      // For full local notifications, add flutter_local_notifications package
    });
  }
}