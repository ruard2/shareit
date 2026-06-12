import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final _onOpenController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onOpen => _onOpenController.stream;

  Future<void> init() async {
    // Request permissions (iOS)
    await _fcm.requestPermission();

    // Get the token and send to backend
    final token = await _fcm.getToken();
    if (token != null) {
      await _postDeviceToken(token);
    }

    // When app launched from terminated via notification
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) _onOpenController.add(msg);
    });

    // When app in background & opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenController.add);

    // Optional: handle foreground messages here if you like
    FirebaseMessaging.onMessage.listen((msg) {
      // e.g. show in-app banner
    });
  }

  Future<void> _postDeviceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    // ApiHelper.post handles setting the Cookie header for you
    await ApiHelper.post(
      '/me/device-token',
      {'device_token': token},
    );
  }

  void dispose() {
    _onOpenController.close();
  }
}
