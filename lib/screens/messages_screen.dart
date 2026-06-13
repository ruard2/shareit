// lib/screens/messages_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import '../widgets/design_system.dart';
import 'conversation_screen.dart';
import 'new_message_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> _inbox = [];
  bool _loading = true;
  Timer? _poll;
  final Set<int> _deletingPeerIds = {};

  @override
  void initState() {
    super.initState();
    _loadInbox();
    _poll = Timer.periodic(
        const Duration(seconds: 6), (_) => _loadInbox(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadInbox({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final resp = await ApiHelper.get('/messages/inbox');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        if (mounted) setState(() => _inbox = data);
      } else if (!silent) {
        _showSnack('Kon inbox niet laden (${resp.statusCode})');
      }
    } catch (_) {
      if (!silent) _showSnack('Netwerkfout bij laden');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _openConversation(int peerId, String peerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ConversationScreen(withUserId: peerId, withUserName: peerName),
      ),
    ).then((_) => _loadInbox(silent: true));
  }

  Future<void> _confirmDeleteConversation(int peerId, String peerName) async {
    if (_deletingPeerIds.contains(peerId)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chat verwijderen?'),
        content: Text('Het hele gesprek met $peerName wordt verwijderd. '
            'Deze actie kan niet ongedaan worden gemaakt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuleren')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Verwijderen')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deletingPeerIds.add(peerId));
    try {
      final resp = await ApiHelper.delete('/messages/conversation/$peerId');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _showSnack('Chat met $peerName verwijderd');
        await _loadInbox(silent: true);
      } else {
        _showSnack('Verwijderen mislukt (${resp.statusCode})');
      }
    } catch (_) {
      _showSnack('Netwerkfout bij verwijderen');
    } finally {
      if (mounted) setState(() => _deletingPeerIds.remove(peerId));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatTime(dynamic iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final hhmm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return hhmm;
    }
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Berichten')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _inbox.isEmpty
              ? _empty(cs, tt)
              : RefreshIndicator(
                  onRefresh: _loadInbox,
                  child: ResponsiveCenter(
                    child: ListView.separated(
                      itemCount: _inbox.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 0.5, thickness: 0.5, indent: 72, color: cs.outline),
                      itemBuilder: (ctx, i) {
                        final msg = _inbox[i] as Map<String, dynamic>;
                        final peerId = msg['peer_id'] as int;
                        final peerName = msg['peer_name'] as String? ?? 'Onbekend';
                        final snippet = msg['latest_message'] as String? ?? '';
                        final unread = msg['unread_count'] as int? ?? 0;
                        final time = _formatTime(msg['latest_at']);
                        final deleting = _deletingPeerIds.contains(peerId);
                        final hasUnread = unread > 0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: cs.primary,
                            child: Text(
                              peerName.isNotEmpty
                                  ? peerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Text(peerName,
                              style: tt.bodyLarge?.copyWith(
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                          subtitle: Text(
                            snippet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                              color: hasUnread
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight:
                                  hasUnread ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(time,
                                  style: tt.labelSmall?.copyWith(
                                      color: hasUnread
                                          ? cs.primary
                                          : cs.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              if (deleting)
                                const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2))
                              else if (hasUnread)
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  constraints: const BoxConstraints(
                                      minWidth: 20, minHeight: 20),
                                  decoration: BoxDecoration(
                                      color: cs.primary,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text('$unread',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                )
                              else
                                const SizedBox(height: 20),
                            ],
                          ),
                          onLongPress: () =>
                              _confirmDeleteConversation(peerId, peerName),
                          onTap: () => _openConversation(peerId, peerName),
                        );
                      },
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nieuw bericht',
        child: const Icon(Icons.edit_rounded),
        onPressed: () {
          Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NewMessageScreen()))
              .then((_) => _loadInbox(silent: true));
        },
      ),
    );
  }

  Widget _empty(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 14),
            Text('Nog geen berichten',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Start een gesprek met de knop rechtsonder.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
