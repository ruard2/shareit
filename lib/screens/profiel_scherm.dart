import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../utils/api_helper.dart';
import '../widgets/design_system.dart';

import 'mijn_verzoeken_scherm.dart';
import 'nodiguitscherm.dart';
import 'groep_beheren_scherm.dart';
import 'beheer_groepsleden_scherm.dart';
import 'info_scherm.dart';
import 'instellingen_scherm.dart';

/// "Profiel"-tab: profielkop + hub naar verzoeken, groep, info,
/// instellingen en uitloggen.
class ProfielScherm extends StatefulWidget {
  const ProfielScherm({super.key});

  @override
  State<ProfielScherm> createState() => _ProfielSchermState();
}

class _ProfielSchermState extends State<ProfielScherm> {
  String _naam = '';
  String _email = '';
  bool _isBeheerder = false;
  List<dynamic> _memberships = [];

  @override
  void initState() {
    super.initState();
    _laad();
  }

  Future<void> _laad() async {
    try {
      final resp = await ApiHelper.get('/gebruikers/mij');
      if (resp.statusCode == 200) {
        final me = json.decode(resp.body) as Map<String, dynamic>;
        final role = (me['role'] as String? ?? 'user').toLowerCase();
        final adminOf = (me['admin_of_groups'] as List?) ?? const [];
        if (!mounted) return;
        setState(() {
          _naam = me['name'] as String? ?? '';
          _email = me['email'] as String? ?? '';
          _isBeheerder = adminOf.isNotEmpty || role == 'superuser';
        });
      }
      final g = await ApiHelper.get('/groepen/mijn');
      if (g.statusCode == 200) {
        final data = json.decode(g.body);
        if (data is List && mounted) setState(() => _memberships = data);
      }
    } catch (_) {}
  }

  void _openMijnGroep() {
    if (_memberships.length <= 1) {
      final gid = _memberships.isEmpty
          ? 0
          : (_memberships.first['group_id'] as int? ?? 0);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => BeheerGroepsledenScherm(groupId: gid)));
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Kies een groep'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _memberships.length,
              itemBuilder: (ctx, i) {
                final grp = _memberships[i] as Map<String, dynamic>;
                return ListTile(
                  title: Text(grp['name'] as String? ?? 'Onbekend'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BeheerGroepsledenScherm(
                            groupId: grp['group_id'] as int? ?? 0),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    }
  }

  Future<void> _uitloggen() async {
    final bevestig = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uitloggen'),
        content: const Text('Weet je zeker dat je wilt uitloggen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuleren')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Uitloggen')),
        ],
      ),
    );
    if (bevestig != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_id');
    await prefs.remove('token');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initiaal = _naam.isNotEmpty ? _naam[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profiel'),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Profielkop
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: cs.primary,
                  child: Text(initiaal,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_naam.isEmpty ? 'Mijn profiel' : _naam,
                          style: tt.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (_email.isNotEmpty)
                        Text(_email,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            IosSection(
              header: 'Activiteit',
              margin: EdgeInsets.zero,
              children: [
                IosListTile(
                  leading: const IosIconContainer(
                      icon: Icons.assignment_outlined,
                      color: AppleColors.systemOrange),
                  title: const Text('Mijn verzoeken'),
                  subtitle: const Text('Status van je leenverzoeken'),
                  showChevron: true,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MijnVerzoekenScherm())),
                ),
                IosListTile(
                  leading: const IosIconContainer(
                      icon: Icons.group_add_outlined,
                      color: AppleColors.systemGreen),
                  title: const Text('Nodig iemand uit'),
                  subtitle: const Text('Deel een uitnodigingslink'),
                  showChevron: true,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NodigUitScherm())),
                ),
                if (_isBeheerder)
                  IosListTile(
                    leading: const IosIconContainer(
                        icon: Icons.admin_panel_settings_outlined,
                        color: AppleColors.systemRed),
                    title: const Text('Groep beheren'),
                    subtitle: const Text('Leden, verzoeken & instellingen'),
                    showChevron: true,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const GroepBeherenScherm())),
                  )
                else
                  IosListTile(
                    leading: const IosIconContainer(
                        icon: Icons.group_outlined,
                        color: AppleColors.systemGray),
                    title: const Text('Mijn groep'),
                    subtitle: const Text('Bekijk groepsleden'),
                    showChevron: true,
                    onTap: _openMijnGroep,
                  ),
              ],
            ),
            const SizedBox(height: 18),

            IosSection(
              header: 'App',
              margin: EdgeInsets.zero,
              children: [
                IosListTile(
                  leading: const IosIconContainer(
                      icon: Icons.settings_outlined,
                      color: AppleColors.systemGray),
                  title: const Text('Instellingen'),
                  subtitle: const Text('Profiel, meldingen & privacy'),
                  showChevron: true,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const InstellingenScherm())),
                ),
                IosListTile(
                  leading: const IosIconContainer(
                      icon: Icons.info_outline_rounded,
                      color: AppleColors.systemBlue),
                  title: const Text('Over ShareIt'),
                  subtitle: const Text('Hoe de app werkt'),
                  showChevron: true,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const InfoScherm())),
                ),
              ],
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _uitloggen,
              icon: const Icon(Icons.logout_rounded, color: AppleColors.systemRed),
              label: const Text('Uitloggen',
                  style: TextStyle(color: AppleColors.systemRed)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppleColors.systemRed, width: 1.2),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
