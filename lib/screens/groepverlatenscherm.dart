import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import 'dart:convert';

class GroepVerlatenScherm extends StatefulWidget {
  const GroepVerlatenScherm({super.key});

  @override
  State<GroepVerlatenScherm> createState() => _GroepVerlatenSchermState();
}

class _GroepVerlatenSchermState extends State<GroepVerlatenScherm> {
  List<dynamic> mijnGroepen = [];
  bool _loading = true;
  String? _foutmelding;

  @override
  void initState() {
    super.initState();
    _laadGroepen();
  }

  Future<void> _laadGroepen() async {
    try {
      final resp = await ApiHelper.get('/gebruikers/mij');
      if (resp.statusCode == 200) {
        final gebruiker = json.decode(resp.body) as Map<String, dynamic>;
        final memberships = (gebruiker['memberships'] as List<dynamic>? ?? []);
        setState(() {
          mijnGroepen = memberships;
          _loading = false;
        });
      } else {
        setState(() {
          _foutmelding = 'Kon groepen niet laden (${resp.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _foutmelding = 'Fout: $e';
        _loading = false;
      });
    }
  }

  Future<void> _verlaatGroep(int groupId, String groupNaam) async {
    final bevestiging = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Groep verlaten'),
        content:
            Text('Weet je zeker dat je "$groupNaam" wilt verlaten?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verlaat groep'),
          ),
        ],
      ),
    );

    if (bevestiging != true) return;

    final res = await ApiHelper.post('/groups/$groupId/leave', null);
    if (!mounted) return;

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je hebt de groep verlaten.')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verlaten mislukt (${res.statusCode}).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Groep verlaten')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_foutmelding != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Groep verlaten')),
        body: Center(child: Text(_foutmelding!)),
      );
    }
    if (mijnGroepen.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Groep verlaten')),
        body: const Center(child: Text('Je bent geen lid van een groep.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Groep verlaten')),
      body: ListView.builder(
        itemCount: mijnGroepen.length,
        itemBuilder: (ctx, i) {
          final groep = mijnGroepen[i];
          final naam = (groep['name'] as String?) ?? 'Naamloos';
          final groupId = groep['group_id'] as int;
          return ListTile(
            leading: const Icon(Icons.group),
            title: Text(naam),
            subtitle: groep['info'] != null ? Text(groep['info']) : null,
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Verlaten'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _verlaatGroep(groupId, naam),
            ),
          );
        },
      ),
    );
  }
}
