import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/api_helper.dart';

class SuperuserBeheerScherm extends StatefulWidget {
  const SuperuserBeheerScherm({super.key});

  @override
  State<SuperuserBeheerScherm> createState() => _SuperuserBeheerSchermState();
}

class _SuperuserBeheerSchermState extends State<SuperuserBeheerScherm> {
  List<dynamic> alleGebruikers = [];
  List<dynamic> gefilterdeGebruikers = [];
  final TextEditingController zoekController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _laadGebruikers();
  }

  Future<void> _laadGebruikers() async {
    try {
      final response = await ApiHelper.get('/gebruikers/alle');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        setState(() {
          alleGebruikers = data;
          gefilterdeGebruikers = data;
        });
      } else {
        _showSnack('Fout bij ophalen gebruikers: ${response.statusCode}');
      }
    } catch (e) {
      _showSnack('Netwerkfout bij laden: $e');
    }
  }

  void _filterGebruikers(String zoekterm) {
    final q = zoekterm.toLowerCase();
    setState(() {
      gefilterdeGebruikers = alleGebruikers.where((gebruiker) {
        final naam = (gebruiker['name'] ?? '').toString().toLowerCase();
        final email = (gebruiker['email'] ?? '').toString().toLowerCase();
        return naam.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Future<void> _verwijderGebruiker(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verwijder gebruiker'),
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
      final response = await ApiHelper.delete('/users/$id');
      if (response.statusCode == 200) {
        await _laadGebruikers();
      } else {
        if (!mounted) return;
        _showSnack('Verwijderen mislukt (${response.statusCode})');
      }
    }
  }

  Future<void> _bewerkRol(int id, String huidigeRol) async {
    final nieuweRol = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Kies een nieuwe rol'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'user'),
            child: const Text('Gewone gebruiker'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'admin'),
            child: const Text('Admin'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'superuser'),
            child: const Text('Superuser'),
          ),
        ],
      ),
    );

    if (nieuweRol != null && nieuweRol != huidigeRol) {
      // new_role is a query parameter on this endpoint
      final response = await ApiHelper.post(
        '/users/role/$id?new_role=${Uri.encodeQueryComponent(nieuweRol)}',
        null,
      );
      if (response.statusCode == 200) {
        await _laadGebruikers();
      } else {
        if (!mounted) return;
        _showSnack('Rol wijzigen mislukt (${response.statusCode})');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Superuser Beheer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: zoekController,
              onChanged: _filterGebruikers,
              decoration: const InputDecoration(
                labelText: 'Zoek gebruiker...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: gefilterdeGebruikers.isEmpty
                ? const Center(child: Text('Geen gebruikers gevonden'))
                : ListView.builder(
                    itemCount: gefilterdeGebruikers.length,
                    itemBuilder: (context, index) {
                      final gebruiker = gefilterdeGebruikers[index];
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(gebruiker['name'] ?? 'Onbekend'),
                        subtitle: Text(
                          '${gebruiker['email'] ?? ''} • Rol: ${gebruiker['role'] ?? ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Rol wijzigen',
                              onPressed: () =>
                                  _bewerkRol(gebruiker['id'], gebruiker['role'] ?? 'user'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Verwijderen',
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
      ),
    );
  }
}
