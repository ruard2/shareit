import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import 'dart:convert';

class SluitAanBijGroepScherm extends StatefulWidget {
  const SluitAanBijGroepScherm({super.key});

  @override
  State<SluitAanBijGroepScherm> createState() => _SluitAanBijGroepSchermState();
}

class _SluitAanBijGroepSchermState extends State<SluitAanBijGroepScherm> {
  List<dynamic> beschikbareGroepen = [];
  String? foutmelding;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _laadGroepen();
  }

  Future<void> _laadGroepen() async {
    try {
      final response = await ApiHelper.get('/groups/all');
      if (response.statusCode == 200) {
        setState(() {
          beschikbareGroepen = json.decode(response.body);
          _loading = false;
        });
      } else {
        setState(() {
          foutmelding = 'Kan groepen niet laden (status: ${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        foutmelding = 'Fout bij ophalen: $e';
        _loading = false;
      });
    }
  }

  Future<void> _sluitAanBijGroep(int groepId) async {
    try {
      final response =
          await ApiHelper.post('/groups/$groepId/join-request', null);
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Verzoek verzonden. Wacht op goedkeuring.')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fout bij aansluiten: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Netwerkfout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sluit bij een groep aan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : foutmelding != null
              ? Center(child: Text(foutmelding!))
              : beschikbareGroepen.isEmpty
                  ? const Center(child: Text('Geen groepen beschikbaar'))
                  : ListView.builder(
                      itemCount: beschikbareGroepen.length,
                      itemBuilder: (context, index) {
                        final groep = beschikbareGroepen[index];
                        return ListTile(
                          leading: const Icon(Icons.group),
                          title: Text(groep['name'] ?? 'Naamloos'),
                          subtitle: groep['info'] != null
                              ? Text(groep['info'])
                              : null,
                          trailing: ElevatedButton(
                            onPressed: () => _sluitAanBijGroep(groep['id']),
                            child: const Text('Sluit aan'),
                          ),
                        );
                      },
                    ),
    );
  }
}
