import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:convert';

import 'nieuw_item_scherm.dart';
import 'item_detail_scherm.dart';
import '../models/item.dart';
import 'new_message_screen.dart';
import '../env.dart';
import '../utils/api_helper.dart';

/// Feature 6: Dialoog voor schademelding bij teruggeven
class _DamageDialog extends StatefulWidget {
  final String itemName;
  final void Function(bool hasDamage, String? note) onConfirm;

  const _DamageDialog({required this.itemName, required this.onConfirm});

  @override
  State<_DamageDialog> createState() => _DamageDialogState();
}

class _DamageDialogState extends State<_DamageDialog> {
  bool _hasDamage = false;
  final _noteCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Teruggeven: "${widget.itemName}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: const Text('Er is schade'),
            value: _hasDamage,
            onChanged: (v) => setState(() => _hasDamage = v ?? false),
            contentPadding: EdgeInsets.zero,
          ),
          if (_hasDamage) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Beschrijving schade',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_hasDamage, _noteCtrl.text.trim());
            Navigator.pop(context, true);
          },
          child: const Text('Bevestigen'),
        ),
      ],
    );
  }
}

class MijnSpullenScherm extends StatefulWidget {
  const MijnSpullenScherm({Key? key}) : super(key: key);

  @override
  State<MijnSpullenScherm> createState() => _MijnSpullenSchermState();
}

class _MijnSpullenSchermState extends State<MijnSpullenScherm> {
  static String get _baseUrl => Env.apiBase;
  List<Item> _mijnSpullen = [];
  List<Item> _geleendeSpullen = [];
  int? _userId;
  bool _loading = true;

  // 0 = alle, 1 = uitgeleend door mij, 2 = geleend door mij
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _laadGebruikerEnAlleSpullen();
  }

  Future<void> _meldTeruggegeven(Item item) async {
    // Feature 6: vraag of er schade is
    bool hasDamage = false;
    String? damageNote;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DamageDialog(
        itemName: item.name,
        onConfirm: (damage, note) {
          hasDamage = damage;
          damageNote = note;
        },
      ),
    );
    if (confirmed != true) return;

    final body = <String, dynamic>{
      'has_damage': hasDamage,
      if (damageNote != null && damageNote!.isNotEmpty) 'damage_note': damageNote,
    };

    final resp = await ApiHelper.post('/items/${item.id}/mark_returned', body);

    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teruggeven gemeld voor "${item.name}".')),
      );
      await _laadGebruikerEnAlleSpullen();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Melden mislukt: ${resp.statusCode}')),
      );
    }
  }

  Future<void> _laadGebruikerEnAlleSpullen() async {
    final meResp = await ApiHelper.get('/gebruikers/mij');
    if (meResp.statusCode == 200) {
      final data = json.decode(meResp.body);
      _userId = data['id'] as int;
      await Future.wait([_laadEigenSpullen(), _laadGeleendeSpullen()]);
    }
    setState(() => _loading = false);
  }

  Future<void> _laadEigenSpullen() async {
    final resp = await ApiHelper.get('/items/user/$_userId');
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List<dynamic>;
      _mijnSpullen = list.map((j) => Item.fromJson(j)).toList();
    }
  }

  Future<void> _laadGeleendeSpullen() async {
    final resp = await ApiHelper.get('/items/');
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List<dynamic>;
      _geleendeSpullen = list
          .map((j) => Item.fromJson(j))
          .where((i) => i.lenderId == _userId)
          .toList();
    }
  }

  Future<void> _verwijderItem(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Verwijder "${item.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nee')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ja')),
        ],
      ),
    );
    if (ok != true) return;

    final resp = await ApiHelper.delete('/items/${item.id}');
    if (resp.statusCode == 200) {
      await _laadGebruikerEnAlleSpullen();
    }
  }

  Future<void> _markerenAlsGegeven(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Item weggegeven?'),
        content: Text(
            'Bevestig dat "${item.name}" is opgehaald. Het item wordt verwijderd uit de app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nee')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ja, weggegeven')),
        ],
      ),
    );
    if (ok != true) return;

    final resp = await ApiHelper.post('/items/${item.id}/mark_given', {});
    if (resp.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${item.name}" is gemarkeerd als weggegeven.')),
      );
      await _laadGebruikerEnAlleSpullen();
    } else {
      String msg = 'Mislukt (${resp.statusCode})';
      try {
        final body = jsonDecode(resp.body);
        msg = body['detail'] ?? msg;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _annuleerReservering(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reservering annuleren?'),
        content: Text('Weet je zeker dat je je reservering van "${item.name}" wil annuleren?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nee')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ja, annuleer')),
        ],
      ),
    );
    if (ok != true) return;

    final resp = await ApiHelper.delete('/items/${item.id}/reserve');
    if (resp.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reservering van "${item.name}" geannuleerd.')),
      );
      await _laadGebruikerEnAlleSpullen();
    } else {
      String msg = 'Annuleren mislukt (${resp.statusCode})';
      try {
        final body = jsonDecode(resp.body);
        msg = body['detail'] ?? msg;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _vraagTerug(Item item) async {
    final resp = await ApiHelper.post('/items/${item.id}/request_return', null);

    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terugvragen verzonden voor "${item.name}".')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terugvragen mislukt: ${resp.statusCode}')),
      );
    }
  }

  Widget _buildLeading(Item item) {
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      if (ApiHelper.isNetworkImage(item.imagePath!)) {
        return Image.network(ApiHelper.resolveImageUrl(item.imagePath!),
            width: 50, height: 50, fit: BoxFit.cover);
      }
      // Lokale bestanden zijn niet beschikbaar op web
      if (!kIsWeb) {
        return Image.file(File(item.imagePath!),
            width: 50, height: 50, fit: BoxFit.cover);
      }
    }
    return const Icon(Icons.inventory);
  }

  Widget _buildItemTile(Item item) {
    String? line2, line3;
    if (_selectedTab == 1 || _selectedTab == 2) {
      line2 = _selectedTab == 1
          ? 'Uitgeleend aan ${item.lenderName ?? 'gebruiker #${item.lenderId}'}'
          : 'Geleend van ${item.ownerName ?? 'gebruiker #${item.ownerId}'}';
      if (item.reservedAt != null) {
        final days = DateTime.now().difference(item.reservedAt!).inDays;
        line3 = '$days dagen geleend';
      }
    }

    // Expiry countdown badge for free items (≤14 days left)
    Widget? expiryBadge;
    if (_selectedTab == 0 && item.isGratis && item.isVrij) {
      final remaining = item.daysUntilExpiry;
      if (remaining != null && remaining <= 14) {
        expiryBadge = Chip(
          label: Text('${remaining}d',
              style: const TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: remaining <= 5 ? Colors.red : Colors.orange,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildLeading(item),
      title: Row(
        children: [
          Expanded(child: Text(item.name)),
          if (expiryBadge != null) ...[
            const SizedBox(width: 6),
            expiryBadge,
          ],
        ],
      ),
      subtitle: (_selectedTab == 1 || _selectedTab == 2)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line2 != null) Text(line2),
                if (line3 != null) Text(line3),
              ],
            )
          : Text(item.info ?? ''),
      onTap: () => _openDetail(item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedTab == 0) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _openEditItem(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _verwijderItem(item),
            ),
          ] else if (_selectedTab == 1) ...[
            if (item.isGratis && item.status == 'reserved')
              TextButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                label: const Text('Gegeven',
                    style: TextStyle(color: Colors.green)),
                onPressed: () => _markerenAlsGegeven(item),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.undo),
                label: const Text('Terugvragen'),
                onPressed: () => _vraagTerug(item),
              ),
          ] else ...[
            // Annuleer-knop voor gereserveerde gratis items
            if (item.isGratis && item.status == 'reserved')
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                tooltip: 'Reservering annuleren',
                onPressed: () => _annuleerReservering(item),
              ),
            Padding(
              padding: EdgeInsets.only(
                  right: MediaQuery.of(context).size.width * 0.07),
              child: IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewMessageScreen(
                        prefillRecipientId: item.ownerId,
                        prefillBody: 'Hoi! Over "${item.name}"...',
                      ),
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

  void _openEditItem(Item item) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NieuwItemScherm(
            bestaandItem: item,
            onItemToegevoegd: (_) => _laadGebruikerEnAlleSpullen(),
          ),
        ),
      );

  void _openNieuwItem() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NieuwItemScherm(
            onItemToegevoegd: (_) => _laadGebruikerEnAlleSpullen(),
          ),
        ),
      );

  void _openDetail(Item item) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ItemDetailScherm(item: item)),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mijn Spullen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Verlopen gratis items apart — altijd zichtbaar in tab 0
    final verlopenItems = _mijnSpullen.where((i) => i.isVerlopen).toList();

    List<Item> displayList;
    if (_selectedTab == 0) {
      // Alle spullen excl. verlopen (die staan in de apart sectie hieronder)
      displayList = _mijnSpullen.where((i) => !i.isVerlopen).toList();
    } else if (_selectedTab == 1) {
      // Uitgeleend = loaned items + gereserveerde gratis items
      displayList = _mijnSpullen
          .where((i) => i.status == 'loaned' ||
              (i.isGratis && i.status == 'reserved'))
          .toList();
    } else {
      displayList = _geleendeSpullen;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mijn Spullen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ToggleButtons(
              isSelected: [
                _selectedTab == 0,
                _selectedTab == 1,
                _selectedTab == 2,
              ],
              onPressed: (idx) => setState(() => _selectedTab = idx),
              borderRadius: BorderRadius.circular(8),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Alle spullen'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Uitgeleend'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Geleend'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // ── Verlopen gratis items (tab 0 only) ──────────────────────
                if (_selectedTab == 0 && verlopenItems.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(children: [
                      const Icon(Icons.timer_off_outlined,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 6),
                      Text('Verlopen gratis items',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800)),
                    ]),
                  ),
                  for (final item in verlopenItems)
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      color: Colors.orange.shade50,
                      child: ListTile(
                        leading: _buildLeading(item),
                        title: Text(item.name),
                        subtitle: const Text(
                          'Na 60 dagen niet opgehaald — verwijder het of zet het opnieuw in',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Verwijderen',
                              onPressed: () => _verwijderItem(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: 24),
                ],

                // ── Normale lijst ────────────────────────────────────────────
                for (int i = 0; i < displayList.length; i++)
                  _buildItemTile(displayList[i]),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              onPressed: _openNieuwItem, child: const Icon(Icons.add))
          : null,
    );
  }
}
