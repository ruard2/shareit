import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import 'dart:convert';
import 'beheer_groepsleden_scherm.dart';

class GroepBeherenScherm extends StatefulWidget {
  const GroepBeherenScherm({super.key});

  @override
  State<GroepBeherenScherm> createState() => _GroepBeherenSchermState();
}

class _GroepBeherenSchermState extends State<GroepBeherenScherm> {
  List<dynamic> gebruikers = [];
  List<dynamic> gefilterdeGebruikers = [];
  List<dynamic> mijnGroepen = [];
  int? geselecteerdeGroepId;
  String? geselecteerdeGroepNaam;
  String? gebruikerRol;
  bool isAdminInDezeGroep = false;

  final zoekController = TextEditingController();
  final groepsnaamController = TextEditingController();
  final extraInfoController = TextEditingController();

  // --------- Eén uniforme knopstijl ----------
  static const _kBtnColor = Color(0xFFCFE4C6); // lichtgroen

  ButtonStyle _actionStyle() {
    return ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(64), // hoger
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: _kBtnColor,
      foregroundColor: Colors.black87,
      elevation: 0,
    );
  }
  // -------------------------------------------

  @override
  void initState() {
    super.initState();
    _laadGebruikerEnGroepen();
  }

  Future<void> _laadGebruikerEnGroepen() async {
    try {
      final resp = await ApiHelper.get('/gebruikers/mij');
      final gebruiker = json.decode(resp.body) as Map<String, dynamic>;
      final groups = (gebruiker['memberships'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      setState(() {
        gebruikerRol = gebruiker['role'] as String?;
        mijnGroepen = groups;
      });

      if (gebruikerRol == 'superuser') {
        await _laadAlleGebruikers();
      }

      if (groups.length > 1) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _toonGroepKiezerDialog(groups));
      } else if (groups.length == 1) {
        final g = groups[0];
        _laadGroepContext(
          g['group_id'] as int,
          g['name'] as String? ?? 'Naamloos',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Fout bij ophalen gegevens: $e');
    }
  }

  Future<void> _laadAlleGebruikers() async {
    try {
      final lijstResponse = await ApiHelper.get('/gebruikers/alle');
      final lijst = json.decode(lijstResponse.body) as List<dynamic>;
      setState(() {
        gebruikers = lijst;
        gefilterdeGebruikers = lijst;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Fout bij ophalen alle gebruikers: $e');
    }
  }

  void _toonGroepKiezerDialog(List<dynamic> groepen) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Kies een groep om te beheren'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: groepen.length,
            itemBuilder: (context, index) {
              final groep = groepen[index];
              return ListTile(
                title: Text(groep['name'] ?? 'Naamloos'),
                subtitle: Text(groep['info'] ?? ''),
                onTap: () {
                  Navigator.pop(context);
                  _laadGroepContext(
                    groep['group_id'] as int,
                    groep['name'] as String? ?? 'Naamloos',
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _laadGroepContext(int groepId, String groepNaam) async {
    try {
      setState(() {
        geselecteerdeGroepId = groepId;
        geselecteerdeGroepNaam = groepNaam;
        isAdminInDezeGroep = mijnGroepen.any((m) =>
            m['group_id'] == groepId &&
            (m['role'] == 'admin' || m['role'] == 'superuser'));
      });
    } catch (e) {
      // ignore: avoid_print
      print('Fout bij instellen groepscontext: $e');
    }
  }

  void _filterGebruikers(String zoekterm) {
    setState(() {
      gefilterdeGebruikers = gebruikers.where((gebruiker) {
        final naam = (gebruiker['name'] ?? '').toString().toLowerCase();
        final email = (gebruiker['email'] ?? '').toString().toLowerCase();
        final q = zoekterm.toLowerCase();
        return naam.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Future<void> _verwijderGebruiker(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bevestigen'),
        content:
            const Text('Weet je zeker dat je deze gebruiker wilt verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await ApiHelper.delete('/gebruikers/$id');
      if (response.statusCode == 200) {
        if (gebruikerRol == 'superuser') {
          await _laadAlleGebruikers();
        } else {
          await _laadGebruikerEnGroepen();
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verwijderen mislukt')),
        );
      }
    }
  }

  void _toonGroepAanmakenDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nieuwe groep aanmaken'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: groepsnaamController,
              decoration: const InputDecoration(labelText: 'Groepsnaam'),
            ),
            TextField(
              controller: extraInfoController,
              decoration: const InputDecoration(
                labelText: 'Extra informatie (optioneel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              if (isAdminInDezeGroep || gebruikerRol == 'superuser') {
                _verzendGroepDirect();
              } else {
                Navigator.pop(context);
                _toonBeheerderAanvraagPopup();
              }
            },
            child: const Text('Aanmaken'),
          ),
        ],
      ),
    );
  }

  Future<void> _verzendGroepDirect() async {
    await ApiHelper.post('/groepen/nieuw', {
      'name': groepsnaamController.text,
      'info': extraInfoController.text,
    });

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Groep succesvol aangemaakt')),
    );

    await _laadGebruikerEnGroepen();
  }

  void _toonBeheerderAanvraagPopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Geen beheerdersrechten'),
        content: const Text(
          'Je moet beheerdersrechten hebben om een groep aan te maken. '
          'Wil je die aanvragen bij je groepsbeheerder?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('❌ Nee, annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _verzendGroepAanvraag();
            },
            child: const Text('✅ Ja, ik wil aanvragen'),
          ),
        ],
      ),
    );
  }

  Future<void> _verzendGroepAanvraag() async {
    // No backend endpoint for group creation requests by regular users.
    // Inform the user to contact their group administrator.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Neem contact op met je groepsbeheerder om een nieuwe groep aan te maken.',
        ),
      ),
    );
  }

  // ✅ Verlaat-groep popup
  Future<void> _toonVerlaatGroepDialog() async {
    if (geselecteerdeGroepId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen groep geselecteerd')),
      );
      return;
    }

    final reasonCtrl = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verlaat deze groep'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Weet je zeker dat je "${geselecteerdeGroepNaam ?? 'deze groep'}" wilt verlaten?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reden (optioneel)',
                hintText: 'Waarom verlaat je de groep?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bevestigen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final resp = await ApiHelper.post(
        '/groups/$geselecteerdeGroepId/leave',
        null,
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Je hebt de groep verlaten')),
        );
        Navigator.of(context).pop(); // terug naar vorig scherm
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kon de groep niet verlaten')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: $e')),
      );
    }
  }

  // ✅ Sluit aan bij groep popup
  Future<void> _toonSluitAanBijGroepDialog() async {
    try {
      final resp = await ApiHelper.get('/groups/all');
      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kon groepen niet ophalen')),
        );
        return;
      }
      final alleGroepen =
          (json.decode(resp.body) as List).cast<Map<String, dynamic>>();

      final membershipIds = mijnGroepen.map((m) => m['group_id']).toSet();
      final nietLidGroepen =
          alleGroepen.where((g) => !membershipIds.contains(g['id'])).toList();

      if (nietLidGroepen.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Je bent al lid van alle beschikbare groepen'),
          ),
        );
        return;
      }

      final gekozen = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Kies een groep'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: nietLidGroepen.length,
              itemBuilder: (ctx, i) {
                final g = nietLidGroepen[i];
                return ListTile(
                  title: Text(g['name'] ?? 'Naamloos'),
                  subtitle: Text(g['info'] ?? ''),
                  onTap: () => Navigator.pop(ctx, g),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuleren'),
            ),
          ],
        ),
      );

      if (gekozen == null) return;

      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Bevestigen'),
          content: Text(
            'Wil je een verzoek sturen om lid te worden van "${gekozen['name']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nee'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ja'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final req =
          await ApiHelper.post('/groups/${gekozen['id']}/join-request', {});

      if (req.statusCode >= 200 && req.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verzoek verzonden. Wacht op goedkeuring.'),
          ),
        );
        await _laadGebruikerEnGroepen();
      } else {
        if (!mounted) return;
        final body = json.decode(req.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['detail'] ?? 'Verzoek verzenden mislukt'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionStyle = _actionStyle();

    return Scaffold(
      appBar: AppBar(title: Text(geselecteerdeGroepNaam ?? 'Groep beheren')),
      body: gebruikerRol == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        style: actionStyle,
                        onPressed: _toonVerlaatGroepDialog,
                        icon: const Icon(Icons.logout),
                        label: const Text('Verlaat deze groep'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: actionStyle,
                        onPressed: _toonSluitAanBijGroepDialog,
                        icon: const Icon(Icons.group_add),
                        label: const Text('Sluit bij een groep aan'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: actionStyle,
                        onPressed: () =>
                            Navigator.pushNamed(context, '/nodig_uit'),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Nodig iemand uit'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: actionStyle,
                        onPressed: _toonGroepAanmakenDialog,
                        icon: const Icon(Icons.create_new_folder),
                        label: const Text('Maak een nieuwe groep'),
                      ),
                      if (isAdminInDezeGroep ||
                          gebruikerRol == 'superuser') ...[
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: actionStyle,
                          onPressed: () {
                            if (geselecteerdeGroepId == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BeheerGroepsledenScherm(
                                  groupId: geselecteerdeGroepId!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Beheer groep'),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 24),
                if (gebruikerRol == 'superuser') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: zoekController,
                      onChanged: _filterGebruikers,
                      decoration: const InputDecoration(
                        labelText: 'Zoek gebruiker...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: gefilterdeGebruikers.isEmpty
                        ? const Center(child: Text('Geen gebruikers gevonden'))
                        : ListView.builder(
                            itemCount: gefilterdeGebruikers.length,
                            itemBuilder: (_, index) {
                              final gebruiker = gefilterdeGebruikers[index];
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(gebruiker['name'] ?? 'Onbekend'),
                                subtitle: Text(gebruiker['email'] ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Bericht (nog niet actief)',
                                      icon:
                                          const Icon(Icons.chat_bubble_outline),
                                      onPressed: () =>
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                        content: Text(
                                            'Contact nog niet geïmplementeerd'),
                                      )),
                                    ),
                                    IconButton(
                                      tooltip: 'Rol bewerken (nog niet actief)',
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                        content: Text(
                                            'Rol bewerken nog niet geïmplementeerd'),
                                      )),
                                    ),
                                    IconButton(
                                      tooltip: 'Verwijderen',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          _verwijderGebruiker(gebruiker['id']),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
    );
  }
}
