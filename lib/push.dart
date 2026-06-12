// lib/push.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'utils/api_helper.dart';

final _fln = FlutterLocalNotificationsPlugin();

Future<void> initPush() async {
  await Firebase.initializeApp();

  // Android local notifications channel
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(
      android: androidInit, iOS: DarwinInitializationSettings());
  await _fln.initialize(initSettings);

  // Foreground messages -> show as local notification
  FirebaseMessaging.onMessage.listen((m) async {
    final notif = m.notification;
    if (notif != null) {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'General',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _fln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notif.title,
        notif.body,
        details,
        payload: jsonEncode(m.data),
      );
    }
  });
}

Future<void> ensurePushRegistered(bool enabled) async {
  final fm = FirebaseMessaging.instance;

  if (!enabled) {
    final token = await fm.getToken();
    if (token != null) {
      await ApiHelper.delete('/push/token', body: {'token': token});
    }
    return;
  }

  // Ask permission (Android 13+ / iOS)
  await fm.requestPermission();

  // Get / refresh token
  final token = await fm.getToken();
  if (token != null) {
    await ApiHelper.post(
        '/push/token', {'token': token, 'platform': 'android'});
  }

  // Keep backend in sync on refresh
  fm.onTokenRefresh.listen((t) async {
    await ApiHelper.post('/push/token', {'token': t, 'platform': 'android'});
  });
}
