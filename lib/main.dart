// lib/main.dart

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// THEME + SCREENS
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_scherm.dart';
import 'screens/registratie_scherm.dart';
import 'screens/zoek_spullen_scherm.dart';
import 'screens/mijn_spullen_scherm.dart';
import 'screens/info_scherm.dart';
import 'screens/instellingen_scherm.dart';
import 'screens/groep_beheren_scherm.dart';
import 'screens/start_scherm.dart';
import 'screens/groepverlatenscherm.dart';
import 'screens/sluitaanbijgroepscherm.dart';
import 'screens/nodiguitscherm.dart';
import 'screens/pending_actions_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/mijn_verzoeken_scherm.dart';
import 'screens/vergeten_pin_scherm.dart';

// SETTINGS
import 'settings/settings_controller.dart';
import 'settings/settings_service.dart';

// API helper (for posting the FCM token)
import 'utils/api_helper.dart';

// PUSH: Firebase + local (foreground) notifications
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import './env.dart';

final _fln = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage msg) async {
  // Background message handler; extend if you need data-only handling.
}

Future<void> initPush() async {
  // Firebase push notifications are only supported on Android/iOS, not web.
  if (kIsWeb) return;

  await Firebase.initializeApp();

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  // Request permission (Android 13+ and iOS)
  await FirebaseMessaging.instance.requestPermission();

  // Local notifications (for foreground display)
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: DarwinInitializationSettings(),
  );
  await _fln.initialize(initSettings);

  // Foreground notifications → show via local notifications
  FirebaseMessaging.onMessage.listen((m) async {
    final n = m.notification;
    if (n != null) {
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
        n.hashCode,
        n.title,
        n.body,
        details,
        payload: jsonEncode(m.data),
      );
    }
  });

  // Taps on notifications that open the app
  FirebaseMessaging.onMessageOpenedApp.listen((m) {
    // Example:
    // if ((m.data['type'] ?? '') == 'message') {
    //   navigatorKey.currentState?.pushNamed('/messages');
    // }
  });
}

/// Registers (and keeps fresh) the device token on your backend.
/// Only runs on mobile (Android/iOS) — not on web.
Future<void> registerFcmTokenWithBackend() async {
  if (kIsWeb) return;
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    try {
      // Matches the backend route you created earlier
      await ApiHelper.post(
          '/push/token', {"token": token, "platform": "android"});
    } catch (_) {
      // best-effort; ignore for now
    }
  }

  // Keep backend updated on token refresh (reinstalls, etc.)
  FirebaseMessaging.instance.onTokenRefresh.listen((tok) async {
    try {
      await ApiHelper.post(
          '/push/token', {"token": tok, "platform": "android"});
    } catch (_) {}
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // We don't await initPush() here; it's fine to initialize in the background.
  initPush();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget? _startScherm;

  late final SettingsController _settings;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();

    // Settings init
    _settings = SettingsController(SettingsService());
    _settings.load().then((_) {
      if (mounted) setState(() => _settingsLoaded = true);
    });

    _bepaalStartScherm();
  }

  Future<void> _bepaalStartScherm() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) {
      setState(() => _startScherm = const StartScherm());
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Env.apiBase}/gebruikers/mij'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionId',
          'cookie': 'session_id=$sessionId',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isApproved = data['is_approved'] == true;

        // Session is valid → register/update this device token on backend.
        // If you prefer to only register when "Berichten" is ON, you can
        // gate this call with your stored flag.
        await registerFcmTokenWithBackend();

        setState(() => _startScherm =
            isApproved ? const HomeScreen() : const StartScherm());
      } else {
        setState(() => _startScherm = const StartScherm());
      }
    } catch (_) {
      setState(() => _startScherm = const StartScherm());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return SettingsScope(
          controller: _settings,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Spullen Delen',

            // Thema
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _settings.materialThemeMode,

            // Locale/delegates are intentionally disabled for now (to avoid extra deps)
            // locale: _settings.appLocale,
            // supportedLocales: const [Locale('nl'), Locale('en')],
            // localizationsDelegates: const [
            //   GlobalMaterialLocalizations.delegate,
            //   GlobalWidgetsLocalizations.delegate,
            //   GlobalCupertinoLocalizations.delegate,
            // ],

            routes: {
              '/home': (c) => const HomeScreen(),
              '/login': (c) => const LoginScherm(),
              '/registratie': (c) => const RegistratieScherm(),
              '/zoek': (c) => const ZoekScherm(),
              '/mijnspullen': (c) => const MijnSpullenScherm(),
              '/info': (c) => const InfoScherm(),
              '/instellingen': (c) => const InstellingenScherm(),
              '/beheer': (c) => const GroepBeherenScherm(),
              '/groep_verlaten': (c) => const GroepVerlatenScherm(),
              '/sluit_aan_bij_groep': (c) => const SluitAanBijGroepScherm(),
              '/nodig_uit': (c) => const NodigUitScherm(),
              '/pending_actions': (c) => const PendingActionsScreen(),
              '/messages': (c) => const MessagesScreen(),
              '/mijn_verzoeken': (c) => const MijnVerzoekenScherm(),
              '/vergeten_pin': (c) => const VergetenPinScherm(),
            },

            home: (_startScherm == null || !_settingsLoaded)
                ? const Center(child: CircularProgressIndicator())
                : _startScherm!,
          ),
        );
      },
    );
  }
}
