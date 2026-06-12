// lib/screens/pending_actions_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'conversation_screen.dart';
import '../env.dart';
import '../utils/api_helper.dart';

class PendingActionsScreen extends StatefulWidget {
  const PendingActionsScreen({super.key});

  @override
  State<PendingActionsScreen> createState() => _PendingActionsScreenState();
}

class _PendingActionsScreenState extends State<PendingActionsScreen> {
  List<dynamic> _borrowRequests = [];
  List<dynamic> _userApprovals = [];
  List<dynamic> _itemRequests = [];
  List<dynamic> _returnRequests = [];
  List<_PendingJoinRequest> _joinRequests = [];
  List<Map<String, dynamic>> _unreadNotifications = [];
  List<Map<String, dynamic>> _overdueOwnerNotifs = [];
  List<Map<String, dynamic>> _blockedBorrowers = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    List<dynamic> borrowRequests = [];
    List<dynamic> userApprovals = [];
    List<dynamic> itemRequests = [];
    List<dynamic> returnRequests = [];
    List<_PendingJoinRequest> joinRequests = [];
    List<Map<String, dynamic>> unreadNotifications = [];
    List<Map<String, dynamic>> blockedBorrowers = [];

    try {
      // 1) Borrow requests (admin)
      var resp = await ApiHelper.get('/requests/pending');
      debugPrint('GET /requests/pending -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        borrowRequests = _safeJsonList(resp.body) ?? [];
      }

      // 2) Pending users (admin)
      resp = await ApiHelper.get('/users/pending');
      debugPrint('GET /users/pending -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        userApprovals = _safeJsonList(resp.body) ?? [];
      }

      // 3) Gratis-ophaalverzoeken (owner)
      resp = await ApiHelper.get('/gebruiker/verzoeken/incoming');
      debugPrint('GET /gebruiker/verzoeken/incoming -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        itemRequests = _safeJsonList(resp.body) ?? [];
      }

      // 4) Return-requests (owner + admin)
      resp = await ApiHelper.get('/requests/return/pending');
      debugPrint('GET /requests/return/pending -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        returnRequests = _safeJsonList(resp.body) ?? [];
      }

      // 5) Notifications (join + overige ongelezen)
      resp = await ApiHelper.get('/notifications');
      debugPrint('GET /notifications -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final list = _safeJsonList(resp.body) ?? [];

        // 5a) join‐requests uit notifications — alleen die correct parseerbaar zijn
        joinRequests = list
            .map<_PendingJoinRequest?>(
                (n) => _PendingJoinRequest.tryFromNotif(n))
            .whereType<_PendingJoinRequest>()
            .toList();

        // IDs van succesvol geparseerde join-requests uitsluiten van de generieke lijst
        final parsedJoinNotifIds = joinRequests.map((r) => r.notifId).toSet();

        // 5b) overdue_owner notificaties → eigen sectie met actieknoppen
        final overdueOwnerNotifs = list
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .where((m) {
          final type = (m['type'] ?? '').toString();
          final readAt = m['read_at'];
          final isUnread = readAt == null || readAt.toString().isEmpty;
          return isUnread && type == 'overdue_owner';
        }).toList();

        // 5c) alle overige ongelezen notificaties
        final overdueOwnerIds = overdueOwnerNotifs
            .map((m) => (m['id'] as num?)?.toInt() ?? -1)
            .toSet();
        unreadNotifications = list
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .where((m) {
          final id = (m['id'] as num?)?.toInt() ?? -1;
          final readAt = m['read_at'];
          final isUnread = readAt == null || readAt.toString().isEmpty;
          return isUnread &&
              !parsedJoinNotifIds.contains(id) &&
              !overdueOwnerIds.contains(id);
        }).toList();

        joinRequests = joinRequests;
        setState(() => _overdueOwnerNotifs = overdueOwnerNotifs);
        debugPrint('Notifications: ${list.length} total, ${joinRequests.length} join, '
            '${overdueOwnerNotifs.length} overdue-owner, ${unreadNotifications.length} unread-other');
      }

      // 6) Geblokkeerde leners (alleen relevant voor beheerders; 403 als geen admin)
      try {
        resp = await ApiHelper.get('/admin/blocked-borrowers');
        debugPrint('GET /admin/blocked-borrowers -> ${resp.statusCode}');
        if (resp.statusCode == 200) {
          final list = _safeJsonList(resp.body) ?? [];
          blockedBorrowers = list
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList();
        }
      } catch (_) {
        // niet-admins krijgen 403 — stilletjes negeren
      }
    } catch (e) {
      _error = 'Ophalen mislukt: $e';
    }

    if (!mounted) return;
    setState(() {
      _borrowRequests = borrowRequests;
      _userApprovals = userApprovals;
      _itemRequests = itemRequests;
      _returnRequests = returnRequests;
      _joinRequests = joinRequests;
      _unreadNotifications = unreadNotifications;
      _blockedBorrowers = blockedBorrowers;
      _loading = false;
    });
  }

  List<dynamic>? _safeJsonList(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is List) return parsed;
      if (parsed is Map && parsed['data'] is List) {
        return List<dynamic>.from(parsed['data'] as List);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _decideBorrow(int id, bool approve) async {
    final resp = await ApiHelper.post('/requests/$id/decision', {'approved': approve});
    debugPrint('POST /requests/$id/decision -> ${resp.statusCode}');
    _loadAll();
  }

  Future<void> _decideUser(int id, bool approve) async {
    final path = approve ? '/users/approve/$id' : '/users/deny/$id';
    final resp = await ApiHelper.post(path, null);
    debugPrint('POST $path -> ${resp.statusCode}');
    _loadAll();
  }

  Future<void> _respondItemRequest(int id) async {
    final decision = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Beantwoord aanvraag'),
        children: [
          SimpleDialogOption(
            child: const Text('Accepteer'),
            onPressed: () => Navigator.pop(context, 'accept'),
          ),
          SimpleDialogOption(
            child: const Text('Weiger'),
            onPressed: () => Navigator.pop(context, 'deny'),
          ),
        ],
      ),
    );
    if (decision == null) return;

    final resp = await ApiHelper.post('/gebruiker/verzoeken/$id/respond', {'decision': decision});
    debugPrint('POST /gebruiker/verzoeken/$id/respond -> ${resp.statusCode}');
    _loadAll();
  }

  Future<void> _decideReturn(int id, bool approve) async {
    // `approve` is a single primitive Body parameter on the backend,
    // so the body must be the raw JSON boolean, not a wrapped object.
    // ApiHelper.post wraps in a Map, so we use http directly here with auth headers.
    final headers = await ApiHelper.getHeaders();
    final resp = await http.post(
      Uri.parse('${Env.apiBase}/requests/$id/return/decision'),
      headers: headers,
      body: jsonEncode(approve),
    );
    debugPrint('POST /requests/$id/return/decision -> ${resp.statusCode}');
    _loadAll();
  }

  Future<void> _approveJoin(_PendingJoinRequest r) async {
    var resp = await ApiHelper.post(
      '/groups/${r.groupId}/join-request/decision',
      {'requester_id': r.requesterId, 'approve': true},
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      resp = await ApiHelper.post('/groups/${r.groupId}/members/${r.requesterId}', null);
    }
    _snack(resp.statusCode >= 200 && resp.statusCode < 300
        ? 'Lid toegevoegd'
        : 'Toevoegen mislukt (${resp.statusCode})');
    _loadAll();
  }

  Future<void> _denyJoin(_PendingJoinRequest r) async {
    final resp = await ApiHelper.post(
      '/groups/${r.groupId}/join-request/decision',
      {'requester_id': r.requesterId, 'approve': false},
    );
    _snack(resp.statusCode >= 200 && resp.statusCode < 300
        ? 'Verzoek geweigerd'
        : 'Weigeren mislukt (${resp.statusCode})');
    _loadAll();
  }

  Future<void> _markNotifRead(int notifId) async {
    final resp = await ApiHelper.post('/notifications/$notifId/read', null);
    debugPrint('POST /notifications/$notifId/read -> ${resp.statusCode}');
    _loadAll();
  }

  Future<void> _extendLoan(int requestId, int notifId) async {
    // Vraag aantal extra dagen via dialog
    int? extraDays;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '7');
        return AlertDialog(
          title: const Text('Uitleentermijn verlengen'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Extra dagen'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            FilledButton(
              onPressed: () {
                extraDays = int.tryParse(ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Verlengen'),
            ),
          ],
        );
      },
    );
    if (extraDays == null || extraDays! <= 0) return;

    final resp = await ApiHelper.post('/requests/$requestId/extend', {'extra_days': extraDays});
    if (resp.statusCode == 200) {
      _snack('Termijn verlengd met $extraDays dagen');
      await _markNotifRead(notifId);
      _loadAll();
    } else {
      _snack('Verlengen mislukt (${resp.statusCode})');
    }
  }

  Future<void> _markReturnedFromNotif(int requestId, int notifId) async {
    final resp = await ApiHelper.post('/requests/$requestId/returned', null);
    if (resp.statusCode == 200) {
      _snack('Item als teruggegeven gemarkeerd');
      await _markNotifRead(notifId);
      _loadAll();
    } else {
      _snack('Markeren mislukt (${resp.statusCode})');
    }
  }

  Future<void> _adminOverdueAction(
      int userId, String action, {int? days, int? newLimit}) async {
    final body = <String, dynamic>{'action': action};
    if (days != null) body['days'] = days;
    if (newLimit != null) body['new_limit'] = newLimit;
    final resp =
        await ApiHelper.post('/admin/users/$userId/overdue-action', body);
    if (resp.statusCode == 200) {
      final decoded = json.decode(resp.body) as Map<String, dynamic>;
      _snack(decoded['detail']?.toString() ?? 'Actie uitgevoerd');
      _loadAll();
    } else {
      _snack('Actie mislukt (${resp.statusCode})');
    }
  }

  Future<void> _showExtendBlockedDialog(int userId) async {
    int? days;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '5');
        return AlertDialog(
          title: const Text('Verleng alle verlopen leningen'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Extra dagen'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuleren')),
            FilledButton(
              onPressed: () {
                days = int.tryParse(ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Verlengen'),
            ),
          ],
        );
      },
    );
    if (days != null && days! > 0) {
      await _adminOverdueAction(userId, 'extend', days: days);
    }
  }

  Future<void> _showSetLimitDialog(int userId, int currentLimit) async {
    int? newLimit;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: currentLimit.toString());
        return AlertDialog(
          title: const Text('Pas overdue-limiet aan'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Max. verlopen leningen toegestaan',
              hintText: 'Leeglaten = systeem standaard (5)',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuleren')),
            FilledButton(
              onPressed: () {
                newLimit = int.tryParse(ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Opslaan'),
            ),
          ],
        );
      },
    );
    if (newLimit != null) {
      await _adminOverdueAction(userId, 'set_limit', newLimit: newLimit);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Map<String, dynamic> _parsePayload(Map<String, dynamic> n) {
    dynamic p = n['payload'];
    if (p is String) {
      try {
        final d = jsonDecode(p);
        if (d is Map) return d.cast<String, dynamic>();
      } catch (_) {}
    } else if (p is Map) {
      return p.cast<String, dynamic>();
    }
    return {};
  }

  String _prettyNotifTitle(Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    switch (type) {
      case 'group_removal':
        return 'Uit groep verwijderd';
      case 'group_join_request':
        return 'Groepsverzoek';
      case 'item_request':
        return 'Itemverzoek';
      case 'item_reserved':
        return 'Item gereserveerd';
      case 'item_expired':
        return 'Gratis item verlopen';
      case 'overdue_return':
        return 'Lening te laat';
      case 'loan_extended':
        return 'Lening verlengd';
      case 'overdue_extended':
        return 'Terugbreekdatum verlengd';
      case 'overdue_cleared':
        return 'Terugbrengdatum verwijderd';
      case 'item_given':
        return 'Item opgehaald bevestigd';
      default:
        return type.isEmpty ? 'Notificatie' : type;
    }
  }

  String _prettyNotifBody(Map<String, dynamic> n) {
    // payload kan string of map zijn
    dynamic p = n['payload'];
    Map<String, dynamic> payload = {};
    if (p is String) {
      try {
        final d = jsonDecode(p);
        if (d is Map) payload = d.cast<String, dynamic>();
      } catch (_) {}
    } else if (p is Map) {
      payload = p.cast<String, dynamic>();
    }

    final type = (n['type'] ?? '').toString();
    if (type == 'group_removal') {
      final gname = (payload['group_name'] ?? 'een groep').toString();
      return 'Je bent verwijderd uit $gname.';
    }
    if (type == 'item_reserved') {
      final who = payload['reserver_name'] ?? 'Iemand';
      final what = payload['item_name'] ?? 'je item';
      return '$who wil "$what" ophalen. Spreek een afhaaltijd af.';
    }
    if (type == 'item_expired') {
      final what = payload['item_name'] ?? 'je item';
      return '"$what" is na 60 dagen niet opgehaald en uit de lijst verwijderd. Zet het opnieuw in via "Nieuw item".';
    }
    if (type == 'overdue_return') {
      final item = payload['item_name'] ?? 'een item';
      final days = payload['days_late'] ?? '?';
      return '"$item" is $days dag(en) te laat. Breng het zo snel mogelijk terug.';
    }
    if (type == 'loan_extended') {
      final item = payload['item_name'] ?? 'een item';
      final extra = payload['extra_days'] ?? '?';
      return 'De uitleentermijn van "$item" is verlengd met $extra dag(en).';
    }
    if (type == 'overdue_extended') {
      final admin = payload['admin_name'] ?? 'een beheerder';
      final extra = payload['extra_days'] ?? '?';
      return '$admin heeft je verlopen lening(en) verlengd met $extra dag(en).';
    }
    if (type == 'overdue_cleared') {
      final admin = payload['admin_name'] ?? 'een beheerder';
      return '$admin heeft je terugbrengdatum verwijderd. Je kunt weer lenen.';
    }
    if (type == 'item_given') {
      final what = payload['item_name'] ?? 'het item';
      final who = payload['owner_name'] ?? 'de eigenaar';
      return '$who heeft bevestigd dat je "$what" hebt opgehaald.';
    }
    if (payload.isNotEmpty) {
      return payload.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pending Actions')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allEmpty = _borrowRequests.isEmpty &&
        _userApprovals.isEmpty &&
        _itemRequests.isEmpty &&
        _returnRequests.isEmpty &&
        _joinRequests.isEmpty &&
        _overdueOwnerNotifs.isEmpty &&
        _blockedBorrowers.isEmpty &&
        _unreadNotifications.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Actions')),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

            // 0) Groepsverzoeken (join)
            if (_joinRequests.isNotEmpty) ...[
              _sectionHeader('Groepsverzoeken'),
              for (final r in _joinRequests)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height:
                        (r.message == null || r.message!.isEmpty) ? 130 : 160,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 60, 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r.requesterName ?? 'Onbekend'} wil lid worden van ${r.groupName}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  'Gebruiker-ID: ${r.requesterId} • Groep-ID: ${r.groupId}'),
                              if (r.message != null &&
                                  r.message!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Bericht: ${r.message}'),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: IconButton(
                            icon: const Icon(Icons.mail_outline),
                            tooltip: 'Bericht sturen',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    withUserId: r.requesterId,
                                    withUserName: r.requesterName ?? 'Onbekend',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 32,
                          right: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                iconSize: 28,
                                icon: const Icon(Icons.check),
                                color: Colors.green,
                                onPressed: () => _approveJoin(r),
                              ),
                              IconButton(
                                iconSize: 28,
                                icon: const Icon(Icons.close),
                                color: Colors.red,
                                onPressed: () => _denyJoin(r),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // 1) Leenverzoeken
            if (_borrowRequests.isNotEmpty) ...[
              _sectionHeader('Leenverzoeken'),
              for (var r in _borrowRequests)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 160,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 60, 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Item ${r['item_id']} – verzoek van ${r['requester_name'] ?? r['requester_id']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Bericht: ${r['message'] ?? "-"}'),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 32,
                          child: IconButton(
                            icon: const Icon(Icons.mail_outline),
                            tooltip: 'Bericht sturen',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    withUserId: r['requester_id'] as int,
                                    withUserName:
                                        r['requester_name'] as String? ??
                                            'Onbekend',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 32,
                          right: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                  iconSize: 28,
                                  icon: const Icon(Icons.check),
                                  color: Colors.green,
                                  onPressed: () =>
                                      _decideBorrow(r['id'], true)),
                              IconButton(
                                  iconSize: 28,
                                  icon: const Icon(Icons.close),
                                  color: Colors.red,
                                  onPressed: () =>
                                      _decideBorrow(r['id'], false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // 2) Nieuwe gebruikers
            if (_userApprovals.isNotEmpty) ...[
              _sectionHeader('Nieuwe gebruikers'),
              for (var u in _userApprovals)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 160,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 60, 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['name'],
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(u['email'] ?? ''),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 32,
                          child: IconButton(
                            icon: const Icon(Icons.mail_outline),
                            tooltip: 'Bericht sturen',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    withUserId: u['id'] as int,
                                    withUserName: u['name'] as String,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 32,
                          right: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                  iconSize: 28,
                                  icon: const Icon(Icons.check),
                                  color: Colors.green,
                                  onPressed: () => _decideUser(u['id'], true)),
                              IconButton(
                                  iconSize: 28,
                                  icon: const Icon(Icons.close),
                                  color: Colors.red,
                                  onPressed: () => _decideUser(u['id'], false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // 3) Gratis-ophaalverzoeken
            if (_itemRequests.isNotEmpty) ...[
              _sectionHeader('Gratis-ophaalverzoeken'),
              for (var ir in _itemRequests)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 160,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 60, 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gezocht: ${ir['term']}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Opmerkingen: ${ir['comment'] ?? "-"}'),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: IconButton(
                            icon: const Icon(Icons.mail_outline),
                            tooltip: 'Bericht sturen',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    withUserId: ir['requester_id'] as int,
                                    withUserName:
                                        ir['requester_name'] as String? ??
                                            'Onbekend',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 32,
                          right: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                  iconSize: 28,
                                  icon: const Icon(Icons.check),
                                  color: Colors.green,
                                  onPressed: () =>
                                      _respondItemRequest(ir['id'])),
                              IconButton(
                                  iconSize: 28,
                                  icon: const Icon(Icons.close),
                                  color: Colors.red,
                                  onPressed: () =>
                                      _respondItemRequest(ir['id'])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // 4) Return-verzoeken
            if (_returnRequests.isNotEmpty) ...[
              _sectionHeader('Return-verzoeken'),
              for (var rr in _returnRequests)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 160,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 60, 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Item ${rr['item_id']} terugbrengen',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                  'Aangevraagd door ${rr['requester_name'] ?? rr['requester_id']}'),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 32,
                          child: IconButton(
                            icon: const Icon(Icons.mail_outline),
                            tooltip: 'Bericht sturen',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    withUserId: rr['requester_id'] as int,
                                    withUserName:
                                        rr['requester_name'] as String? ??
                                            'Onbekend',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 32,
                          right: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                  iconSize: 28,
                                  icon: const Icon(Icons.check),
                                  color: Colors.green,
                                  onPressed: () =>
                                      _decideReturn(rr['id'], true)),
                              IconButton(
                                  iconSize: 28,
                                  icon: const Icon(Icons.close),
                                  color: Colors.red,
                                  onPressed: () =>
                                      _decideReturn(rr['id'], false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // 5) Verlopen leningen (eigenaar actie vereist)
            if (_overdueOwnerNotifs.isNotEmpty) ...[
              _sectionHeader('Te laat teruggegeven'),
              for (final n in _overdueOwnerNotifs) ...[
                Builder(builder: (ctx) {
                  final p = _parsePayload(n);
                  final itemName    = (p['item_name'] ?? 'item').toString();
                  final daysLate    = (p['days_late'] as num?)?.toInt() ?? 1;
                  final requestId   = (p['request_id'] as num?)?.toInt() ?? 0;
                  final borrowerName = (p['borrower_name'] ?? 'lener').toString();
                  final notifId     = (n['id'] as num?)?.toInt() ?? 0;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.timer_off_outlined, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              '"$itemName" — $daysLate ${daysLate == 1 ? 'dag' : 'dagen'} te laat',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            )),
                          ]),
                          const SizedBox(height: 4),
                          Text('Geleend door: $borrowerName', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                label: const Text('Verleng'),
                                onPressed: () => _extendLoan(requestId, notifId),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text('Teruggegeven'),
                                onPressed: () => _markReturnedFromNotif(requestId, notifId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],

            // 6) Geblokkeerde leners (admin-only sectie)
            if (_blockedBorrowers.isNotEmpty) ...[
              _sectionHeader('Geblokkeerde leners'),
              for (final b in _blockedBorrowers)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.block, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${b['user_name']} — ${b['overdue_count']} verlopen '
                              '(limiet: ${b['limit']})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        const Text(
                          'Deze persoon kan niet meer lenen totdat items zijn teruggebracht.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 18),
                              label: const Text('Verleng'),
                              onPressed: () => _showExtendBlockedDialog(
                                  (b['user_id'] as num).toInt()),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.all_inclusive, size: 18),
                              label: const Text('Onbeperkt'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange),
                              onPressed: () => _adminOverdueAction(
                                  (b['user_id'] as num).toInt(), 'clear'),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.tune, size: 18),
                              label: const Text('Limiet'),
                              onPressed: () => _showSetLimitDialog(
                                  (b['user_id'] as num).toInt(),
                                  (b['limit'] as num).toInt()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // 7) Overige ongelezen notificaties (tellen mee op het belletje)
            if (_unreadNotifications.isNotEmpty) ...[
              _sectionHeader('Notificaties'),
              for (final n in _unreadNotifications)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                      _prettyNotifTitle(n),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(_prettyNotifBody(n)),
                    trailing: IconButton(
                      icon: const Icon(Icons.done_all),
                      tooltip: 'Markeer als gelezen',
                      onPressed: () => _markNotifRead((n['id'] as num).toInt()),
                    ),
                  ),
                ),
            ],

            if (allEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: Center(
                  child: Text(
                    'Geen verzoeken om te vertonen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
        child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
}

/// Robuuste parser voor join-notificaties.
class _PendingJoinRequest {
  final int notifId;
  final int groupId;
  final String groupName;
  final int requesterId;
  final String? requesterName;
  final String? message;

  _PendingJoinRequest({
    required this.notifId,
    required this.groupId,
    required this.groupName,
    required this.requesterId,
    this.requesterName,
    this.message,
  });

  static _PendingJoinRequest? tryFromNotif(dynamic n) {
    if (n is! Map) return null;
    final map = n.cast<String, dynamic>();

    final type = (map['type'] ?? '').toString();
    if (type != 'group_join_request') return null;

    final rawPayload = map['payload'];
    Map<String, dynamic> p = {};
    if (rawPayload is String) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) p = decoded.cast<String, dynamic>();
      } catch (_) {
        return null;
      }
    } else if (rawPayload is Map) {
      p = rawPayload.cast<String, dynamic>();
    } else {
      return null;
    }

    int? groupId = _asInt(p['group_id'] ?? map['group_id']);
    int? requesterId = _asInt(p['requester_id'] ??
        p['user_id'] ??
        map['requester_id'] ??
        map['user_id']);
    if (groupId == null || requesterId == null) return null;

    final groupName =
        (p['group_name'] ?? map['group_name'] ?? 'Onbekende groep').toString();
    final requesterName = (p['requester_name'] ??
            p['user_name'] ??
            p['name'] ??
            map['requester_name'] ??
            map['user_name'])
        ?.toString();
    final message = (p['message'] ?? map['message'])?.toString();
    final notifId = _asInt(map['id']) ?? 0;

    return _PendingJoinRequest(
      notifId: notifId,
      groupId: groupId,
      groupName: groupName,
      requesterId: requesterId,
      requesterName: requesterName,
      message: message,
    );
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
