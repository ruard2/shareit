import 'package:flutter/material.dart';
import 'settings_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._service);

  final SettingsService _service;

  bool notifMessages = true;
  bool notifBorrow = true;
  bool notifJoinRequests = true;

  bool privEmail = false;
  bool privPhone = false;

  String themeMode = 'system'; // system | light | dark
  String language = 'nl'; // nl | en

  Future<void> load() async {
    notifMessages = await _service.getNotifMessages();
    notifBorrow = await _service.getNotifBorrow();
    notifJoinRequests = await _service.getNotifJoinRequests();

    privEmail = await _service.getPrivEmail();
    privPhone = await _service.getPrivPhone();

    themeMode = await _service.getThemeMode();
    language = await _service.getLanguage();
    notifyListeners();
  }

  ThemeMode get materialThemeMode {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Locale get appLocale => Locale(language);

  Future<void> setNotifMessages(bool v) async {
    notifMessages = v;
    await _service.setNotifMessages(v);
    notifyListeners();
  }

  Future<void> setNotifBorrow(bool v) async {
    notifBorrow = v;
    await _service.setNotifBorrow(v);
    notifyListeners();
  }

  Future<void> setNotifJoinRequests(bool v) async {
    notifJoinRequests = v;
    await _service.setNotifJoinRequests(v);
    notifyListeners();
  }

  Future<void> setPrivEmail(bool v) async {
    privEmail = v;
    await _service.setPrivEmail(v);
    notifyListeners();
  }

  Future<void> setPrivPhone(bool v) async {
    privPhone = v;
    await _service.setPrivPhone(v);
    notifyListeners();
  }

  Future<void> setTheme(String mode) async {
    themeMode = mode;
    await _service.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    await _service.setLanguage(lang);
    notifyListeners();
  }
}

/// Eenvoudige provider zonder extra packages
class SettingsScope extends InheritedWidget {
  const SettingsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SettingsController controller;

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope not found in context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(SettingsScope oldWidget) =>
      controller != oldWidget.controller;
}
