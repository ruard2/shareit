import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_helper.dart';
import 'dart:convert';
import 'conversation_screen.dart';

class BeheerGroepsledenScherm extends StatefulWidget {
  final int groupId;
  const BeheerGroepsledenScherm({required this.groupId, super.key});

  @override
  State<BeheerGroepsledenScherm> createState() =>
      _BeheerGroepsledenSchermState();
}

class _BeheerGroepsledenSchermState extends State<BeheerGroepsledenScherm> {
  List<dynamic> groepsleden = [];
  List<dynamic> pendingUsers = [];
  String? gebruikerRol;
  bool isAdminInDezeGroep = false;

  @override
  void initState() {
    super.initState();
    _laadGegevens();
  }

  Future<void> _laadGegevens() async {
    try {
      final gebruikerResp = await ApiHelper.get('/gebruikers/mij');
      final gebruiker = json.decode(gebruikerResp.body) as Map<String, dynamic>;
      final adminOf = (gebruiker['admin_of_groups'] as List<dynamic>? ?? []);
      setState(() {
        gebruikerRol = gebruiker['role'];
        isAdminInDezeGroep = adminOf.contains(widget.groupId);
      });

      // Leden van geselecteerde groep
      final ledenResp = await ApiHelper.get('/users/group/${widget.groupId}');
      if (ledenResp.statusCode == 200) {
        final alleGebruikers = json.decode(ledenResp.body) as List<dynamic>;
        setState(() {
          groepsleden =
              alleGebruikers.where((u) => u['is_approved'] == true).toList();
        });
      }

      // Pending aanmeldingen
      final pendResp = await ApiHelper.get('/groups/${widget.groupId}/pending');
      if (pendResp.statusCode == 200) {
        setState(
            () => pendingUsers = json.decode(pendResp.body) as List<dynamic>);
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Fout bij laden: $e');
    }
  }

  Future<void> _approveUser(int gebruikerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gebruiker goedkeuren'),
        content:
            const Text('Weet je zeker dat je deze gebruiker wilt goedkeuren?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Goedkeuren')),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await ApiHelper.post('/users/approve/$gebruikerId', null);
    if (response.statusCode == 200) {
      await _laadGegevens();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gebruiker goedgekeurd')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goedkeuren mislukt')));
    }
  }

  Future<void> _toggleBeheerder(int gebruikerId, String huidigeRol) async {
    final isAdmin = (huidigeRol == 'admin');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isAdmin ? 'Beheerder verwijderen' : 'Beheerder maken'),
        content: Text(isAdmin
            ? 'Weet je zeker dat je deze gebruiker geen beheerder meer wilt maken?'
            : 'Weet je zeker dat je deze gebruiker beheerder wilt maken?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bevestigen')),
        ],
      ),
    );
    if (confirmed != true) return;

    final url = '/groups/${widget.groupId}/admins/$gebruikerId';
    late final http.Response response;

    if (isAdmin) {
      response = await ApiHelper.delete(url);
    } else {
      response = await ApiHelper.post(url, null);
    }

    if (response.statusCode == 200) {
      await _laadGegevens();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAdmin
              ? 'Admin-rechten verwijderd'
              : 'Admin-rechten toegekend')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Actie mislukt')));
    }
  }

  /// Dialoog + verwijderen met optionele reden
  Future<void> _toonVerwijderDialog(Map<String, dynamic> gebruiker) async {
    final TextEditingController redenController = TextEditingController();

    final result = await showDialog<_VerwijderResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lid verwijderen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Weet je zeker dat je deze gebruiker wilt verwijderen?'),
            const SizedBox(height: 12),
            TextField(
              controller: redenController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reden (optioneel)',
                hintText: 'Bijv. inactief, overtreden regels…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _VerwijderResult(cancelled: true)),
            child: const Text('Nee'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                _VerwijderResult(
                  cancelled: false,
                  reason: redenController.text.trim(),
                ),
              );
            },
            child: const Text('Ja, verwijderen'),
          ),
        ],
      ),
    );

    if (result == null || result.cancelled) return;

    await _verwijderLidUitGroep(
      gebruikerId: gebruiker['id'] as int,
      reason: result.reason,
      gebruikerNaam: (gebruiker['name'] as String?) ?? 'Onbekend',
    );
  }

  /// Verwijdert lid via backend, stuurt optioneel bericht, ververst lijst direct.
  Future<void> _verwijderLidUitGroep({
    required int gebruikerId,
    String? reason,
    String? gebruikerNaam,
  }) async {
    try {
      // Optimistisch uit UI verwijderen (met rollback-backup)
      final oldGroepsleden = List<dynamic>.from(groepsleden);
      final oldPending = List<dynamic>.from(pendingUsers);
      setState(() {
        groepsleden.removeWhere((u) => u['id'] == gebruikerId);
        pendingUsers.removeWhere((u) => u['id'] == gebruikerId);
      });

      bool messageSent = false;

      // 1) Optioneel: reden als chatbericht sturen (eerst!)
      if (reason != null && reason.isNotEmpty) {
        final msgResp = await ApiHelper.post('/messages', {
          'recipient_id': gebruikerId,
          'content': 'Je bent verwijderd uit de groep: $reason',
        });
        messageSent = msgResp.statusCode == 200 || msgResp.statusCode == 201;
      }

      // 2) Verwijderen uit groep
      // suppress_notify=1 ALS bericht is verstuurd; anders laat backend bel-notificatie maken
      final deletePath = messageSent
          ? '/groups/${widget.groupId}/members/$gebruikerId?suppress_notify=1'
          : '/groups/${widget.groupId}/members/$gebruikerId';

      final resp = await ApiHelper.delete(deletePath);

      // Als message faalde maar delete wel suppress was: fallback -> alsnog bel maken?
      if ((reason != null && reason.isNotEmpty) &&
          !messageSent &&
          resp.statusCode == 200) {
        // Fallback: backend alsnog notificatie laten maken
        await ApiHelper.delete(
            '/groups/${widget.groupId}/members/$gebruikerId');
      }

      if (resp.statusCode != 200) {
        // rollback
        setState(() {
          groepsleden = oldGroepsleden;
          pendingUsers = oldPending;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verwijderen mislukt')),
        );
        return;
      }

      // 3) Lijst opnieuw ophalen voor zekerheid
      await _laadGegevens();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('\'${gebruikerNaam ?? 'Gebruiker'}\' verwijderd')),
      );
    } catch (e) {
      // ignore: avoid_print
      print('❌ Fout bij verwijderen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Er ging iets mis bij verwijderen')),
      );
    }
  }

  Widget _buildUserTile(Map<String, dynamic> gebruiker,
      {bool isPending = false}) {
    final isBeheerder = (gebruiker['role'] == 'admin');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(gebruiker['name'] ?? 'Onbekend'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: ${gebruiker['email'] ?? ''}"),
            if (!isPending) Text("Rol: ${gebruiker['role'] ?? ''}"),
          ],
        ),
        trailing: isPending
            // pending: approve / deny
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _approveUser(gebruiker['id'] as int),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _toonVerwijderDialog(gebruiker),
                  ),
                ],
              )
            // approved members: chat + delete (alleen admin/superuser)
            : (isAdminInDezeGroep || gebruikerRol == 'superuser')
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.mail_outline),
                        tooltip: 'Chat starten',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(
                                withUserId: gebruiker['id'] as int,
                                withUserName:
                                    gebruiker['name'] as String? ?? 'Onbekend',
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Verwijderen',
                        onPressed: () => _toonVerwijderDialog(gebruiker),
                      ),
                    ],
                  )
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beheer groepsleden')),
      body: gebruikerRol == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (isAdminInDezeGroep || gebruikerRol == 'superuser') ...[
                  if (pendingUsers.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("Nieuwe aanmeldingen",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...pendingUsers
                        .map((u) => _buildUserTile(u, isPending: true))
                        .toList(),
                    const Divider(thickness: 2),
                  ],
                ],
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("Huidige groepsleden",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...groepsleden.map((u) => _buildUserTile(u)).toList(),
              ],
            ),
    );
  }
}

class _VerwijderResult {
  final bool cancelled;
  final String? reason;
  _VerwijderResult({required this.cancelled, this.reason});
}
