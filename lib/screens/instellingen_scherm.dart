// lib/screens/instellingen_scherm.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import '../settings/settings_controller.dart';
import '../widgets/design_system.dart';
import '../theme.dart';

class InstellingenScherm extends StatefulWidget {
  const InstellingenScherm({super.key});

  @override
  State<InstellingenScherm> createState() => _InstellingenSchermState();
}

class _InstellingenSchermState extends State<InstellingenScherm> {
  final _naamCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl   = TextEditingController();

  bool _loading  = true;
  bool _saving   = false;
  bool _didInit  = false;

  bool? _notifMessages;
  bool? _notifBorrow;
  bool? _notifJoinRequests;
  bool? _privEmail;
  bool? _privPhone;
  String? _themeLocal;
  String? _langLocal;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _loadPrefsIntoLocalState();
  }

  // ---- data ----------------------------------------------------------------

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiHelper.get('/gebruikers/mij');
      if (resp.statusCode == 200) {
        final me = jsonDecode(resp.body) as Map<String, dynamic>;
        _naamCtrl.text  = (me['name'] as String?) ?? '';
        _emailCtrl.text = (me['email'] as String?) ?? '';
        _telCtrl.text   = (me['phone'] as String?) ?? (me['phone_number'] as String? ?? '');
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPrefsIntoLocalState() async {
    try {
      final resp = await ApiHelper.get('/users/me/preferences');
      if (resp.statusCode == 200) {
        final data  = jsonDecode(resp.body) as Map<String, dynamic>;
        final notif = (data['notifications'] as Map?) ?? {};
        final priv  = (data['privacy'] as Map?) ?? {};
        final ui    = (data['ui'] as Map?) ?? {};
        final prof  = (data['profile'] as Map?) ?? {};

        setState(() {
          _notifMessages    = (notif['messages'] as bool?)      ?? _notifMessages;
          _notifBorrow      = (notif['borrow'] as bool?)        ?? _notifBorrow;
          _notifJoinRequests = (notif['join_requests'] as bool?) ?? _notifJoinRequests;
          _privEmail        = (priv['show_email'] as bool?)     ?? _privEmail;
          _privPhone        = (priv['show_phone'] as bool?)     ?? _privPhone;
          _themeLocal       = (ui['theme'] as String?)          ?? _themeLocal;
          _langLocal        = (ui['language'] as String?)       ?? _langLocal;
          if ((prof['name'] as String?)?.isNotEmpty == true) _naamCtrl.text  = prof['name'];
          if ((prof['email'] as String?)?.isNotEmpty == true) _emailCtrl.text = prof['email'];
          if ((prof['phone'] as String?)?.isNotEmpty == true) _telCtrl.text   = prof['phone'];
        });
      }
    } catch (_) {}
  }

  Map<String, dynamic> _payloadFromLocal(SettingsController s) => {
    'notifications': {
      'messages':      _notifMessages    ?? s.notifMessages,
      'borrow':        _notifBorrow      ?? s.notifBorrow,
      'join_requests': _notifJoinRequests ?? s.notifJoinRequests,
    },
    'privacy': {
      'show_email': _privEmail ?? s.privEmail,
      'show_phone': _privPhone ?? s.privPhone,
    },
    'ui': {
      'theme':    _themeLocal ?? s.themeMode,
      'language': _langLocal  ?? s.language,
    },
    'profile': {
      'name':  _naamCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _telCtrl.text.trim(),
    },
  };

  Future<void> _saveAll(SettingsController s) async {
    setState(() => _saving = true);
    try {
      final resp = await ApiHelper.post('/users/me/preferences', _payloadFromLocal(s));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Status ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opslaan mislukt: $e')),
        );
      }
      return;
    }

    await s.setTheme(_themeLocal ?? s.themeMode);
    await s.setLanguage(_langLocal ?? s.language);
    s.setNotifMessages(_notifMessages ?? s.notifMessages);
    s.setNotifBorrow(_notifBorrow ?? s.notifBorrow);
    s.setNotifJoinRequests(_notifJoinRequests ?? s.notifJoinRequests);
    s.setPrivEmail(_privEmail ?? s.privEmail);
    s.setPrivPhone(_privPhone ?? s.privPhone);

    await _loadPrefsIntoLocalState();
    await _loadProfile();

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instellingen opgeslagen')),
    );
  }

  Future<void> _changePin() async {
    final oldCtrl     = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pincode wijzigen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              controller: oldCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Huidige pincode'),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              controller: newCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nieuwe pincode'),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              controller: confirmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bevestig nieuw'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Opslaan')),
        ],
      ),
    );

    if (ok != true) return;
    if (newCtrl.text != confirmCtrl.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nieuw en bevestiging komen niet overeen')),
      );
      return;
    }
    try {
      final resp = await ApiHelper.post(
          '/users/change_pin', {'old': oldCtrl.text, 'new': newCtrl.text});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.statusCode >= 200 && resp.statusCode < 300
            ? 'Pincode gewijzigd'
            : 'Wijzigen mislukt (${resp.statusCode})'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fout: $e')));
    }
  }

  Future<void> _logout() async {
    try { await ApiHelper.post('/auth/logout', null); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _deleteAccount() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Account verwijderen'),
        content:
            const Text('Weet je zeker dat je je account permanent wilt verwijderen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppleColors.systemRed),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      final resp = await ApiHelper.delete('/users/me');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.statusCode >= 200 && resp.statusCode < 300
            ? 'Account verwijderd'
            : 'Verwijderen mislukt (${resp.statusCode})'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fout: $e')));
    }
  }

  String _themeLabel(String mode) {
    switch (mode) {
      case 'light':  return 'Licht';
      case 'dark':   return 'Donker';
      default:       return 'Systeem';
    }
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final cs       = Theme.of(context).colorScheme;
    final isTablet = Breakpoints.isTablet(context);

    final theme = _themeLocal ?? settings.themeMode;
    final lang  = _langLocal  ?? settings.language;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Instellingen'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _saveAll(settings),
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.primary),
                  )
                : Text(
                    'Opslaan',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: isTablet ? 600 : double.infinity),
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 0,
                      vertical: 12,
                    ),
                    children: [
                      // ---- Profiel ----
                      IosSection(
                        header: 'Profiel',
                        children: [
                          _textFieldTile(_naamCtrl, 'Naam',
                              Icons.person_outline_rounded,
                              type: TextInputType.name),
                          _textFieldTile(_emailCtrl, 'E-mailadres',
                              Icons.mail_outline_rounded,
                              type: TextInputType.emailAddress),
                          _textFieldTile(_telCtrl, 'Telefoonnummer',
                              Icons.phone_outlined,
                              type: TextInputType.phone, last: true),
                        ],
                      ),

                      // ---- Meldingen ----
                      IosSection(
                        header: 'Meldingen',
                        children: [
                          _switchTile(
                            icon: Icons.chat_bubble_outline_rounded,
                            iconColor: AppleColors.systemBlue,
                            title: 'Berichten',
                            subtitle: 'Nieuwe chats',
                            value: _notifMessages ?? settings.notifMessages,
                            onChanged: (v) => setState(() => _notifMessages = v),
                          ),
                          _switchTile(
                            icon: Icons.swap_horiz_rounded,
                            iconColor: AppleColors.systemGreen,
                            title: 'Leenverzoeken',
                            subtitle: 'Als iemand jouw item wil lenen of retourneren',
                            value: _notifBorrow ?? settings.notifBorrow,
                            onChanged: (v) => setState(() => _notifBorrow = v),
                          ),
                          _switchTile(
                            icon: Icons.group_add_outlined,
                            iconColor: AppleColors.systemOrange,
                            title: 'Groepsverzoeken',
                            subtitle: 'Als iemand jouw groep wil joinen',
                            value: _notifJoinRequests ?? settings.notifJoinRequests,
                            onChanged: (v) => setState(() => _notifJoinRequests = v),
                          ),
                        ],
                      ),

                      // ---- Privacy ----
                      IosSection(
                        header: 'Privacy',
                        children: [
                          _switchTile(
                            icon: Icons.mail_outline_rounded,
                            iconColor: AppleColors.systemGray,
                            title: 'Toon e-mail aan groepsleden',
                            value: _privEmail ?? settings.privEmail,
                            onChanged: (v) => setState(() => _privEmail = v),
                          ),
                          _switchTile(
                            icon: Icons.phone_outlined,
                            iconColor: AppleColors.systemGray,
                            title: 'Toon telefoon aan groepsleden',
                            value: _privPhone ?? settings.privPhone,
                            onChanged: (v) => setState(() => _privPhone = v),
                          ),
                        ],
                      ),

                      // ---- Weergave ----
                      IosSection(
                        header: 'Weergave & taal',
                        children: [
                          IosListTile(
                            leading: IosIconContainer(
                                icon: Icons.brightness_6_outlined,
                                color: AppleColors.systemGray),
                            title: const Text('Thema'),
                            subtitle: Text(_themeLabel(theme)),
                            showChevron: true,
                            onTap: () async {
                              final choice = await showDialog<String>(
                                context: context,
                                builder: (_) => SimpleDialog(
                                  title: const Text('Kies thema'),
                                  children: [
                                    SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(context, 'system'),
                                        child: const Text('Systeem')),
                                    SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(context, 'light'),
                                        child: const Text('Licht')),
                                    SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(context, 'dark'),
                                        child: const Text('Donker')),
                                  ],
                                ),
                              );
                              if (choice != null) setState(() => _themeLocal = choice);
                            },
                          ),
                          IosListTile(
                            leading: IosIconContainer(
                                icon: Icons.language_rounded,
                                color: AppleColors.systemBlue),
                            title: const Text('Taal'),
                            subtitle: Text(lang == 'nl' ? 'Nederlands' : 'English'),
                            showChevron: true,
                            onTap: () async {
                              final choice = await showDialog<String>(
                                context: context,
                                builder: (_) => SimpleDialog(
                                  title: const Text('Kies taal'),
                                  children: [
                                    SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(context, 'nl'),
                                        child: const Text('Nederlands')),
                                    SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(context, 'en'),
                                        child: const Text('English')),
                                  ],
                                ),
                              );
                              if (choice != null) setState(() => _langLocal = choice);
                            },
                          ),
                        ],
                      ),

                      // ---- Account ----
                      IosSection(
                        header: 'Account',
                        children: [
                          IosListTile(
                            leading: IosIconContainer(
                                icon: Icons.vpn_key_outlined,
                                color: AppleColors.systemGray),
                            title: const Text('Pincode wijzigen'),
                            showChevron: true,
                            onTap: _changePin,
                          ),
                          IosListTile(
                            leading: IosIconContainer(
                                icon: Icons.logout_rounded,
                                color: AppleColors.systemOrange),
                            title: const Text('Uitloggen'),
                            onTap: _logout,
                          ),
                          IosListTile(
                            leading: IosIconContainer(
                                icon: Icons.delete_outline_rounded,
                                color: AppleColors.systemRed),
                            title: Text(
                              'Account verwijderen',
                              style: TextStyle(color: AppleColors.systemRed),
                            ),
                            onTap: _deleteAccount,
                          ),
                        ],
                      ),

                      // ---- Over ----
                      IosSection(
                        header: 'Over',
                        footer: 'Spullen Delen — gratis items delen met je groep.',
                        children: [
                          IosListTile(
                            leading: IosIconContainer(
                                icon: Icons.info_outline_rounded,
                                color: AppleColors.systemBlue),
                            title: const Text('Versie'),
                            trailing: Text(
                              '1.0.0',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ---- Row helpers ---------------------------------------------------------

  Widget _textFieldTile(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool last = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IosIconContainer(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
