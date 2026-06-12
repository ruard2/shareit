import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  Future<bool> getNotifMessages() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('pref_notif_messages') ?? true;
  }

  Future<bool> getNotifBorrow() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('pref_notif_borrow') ?? true;
  }

  Future<bool> getNotifJoinRequests() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('pref_notif_joinrequests') ?? true;
  }

  Future<bool> getPrivEmail() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('pref_priv_email') ?? false;
  }

  Future<bool> getPrivPhone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('pref_priv_phone') ?? false;
  }

  Future<String> getThemeMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('pref_theme') ?? 'system'; // system | light | dark
  }

  Future<String> getLanguage() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('pref_language') ?? 'nl'; // nl | en
  }

  Future<void> setNotifMessages(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_notif_messages', v);
  }

  Future<void> setNotifBorrow(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_notif_borrow', v);
  }

  Future<void> setNotifJoinRequests(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_notif_joinrequests', v);
  }

  Future<void> setPrivEmail(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_priv_email', v);
  }

  Future<void> setPrivPhone(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_priv_phone', v);
  }

  Future<void> setThemeMode(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pref_theme', mode);
  }

  Future<void> setLanguage(String lang) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pref_language', lang);
  }
}
