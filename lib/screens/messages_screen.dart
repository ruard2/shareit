// lib/screens/messages_screen.dart

import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import 'dart:convert';
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

  // Houd bij welke gesprekken aan het verwijderen zijn (disable knop en toon spinner)
  final Set<int> _deletingPeerIds = {};

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiHelper.get('/messages/inbox');
      if (resp.statusCode == 200) {
        setState(() => _inbox = jsonDecode(resp.body) as List<dynamic>);
      } else {
        setState(() => _inbox = []);
        _showSnack('Kon inbox niet laden (${resp.statusCode})');
      }
    } catch (e) {
      setState(() => _inbox = []);
      _showSnack('Netwerkfout bij laden');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openConversation(int peerId, String peerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          withUserId: peerId,
          withUserName: peerName,
        ),
      ),
    ).then((_) => _loadInbox());
  }

  Future<void> _confirmDeleteConversation(int peerId, String peerName) async {
    if (_deletingPeerIds.contains(peerId)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chat verwijderen?'),
        content: Text(
          'Het hele gesprek met $peerName wordt verwijderd. '
          'Deze actie kan niet ongedaan worden gemaakt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deletingPeerIds.add(peerId));

    try {
      final resp = await ApiHelper.delete('/messages/conversation/$peerId');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _showSnack('Chat met $peerName verwijderd');
        await _loadInbox();
      } else {
        _showSnack('Verwijderen mislukt (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Netwerkfout bij verwijderen');
    } finally {
      if (mounted) {
        setState(() => _deletingPeerIds.remove(peerId));
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
      appBar: AppBar(title: const Text('Berichten')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _inbox.isEmpty
              ? const Center(child: Text('Geen berichten'))
              : RefreshIndicator(
                  onRefresh: _loadInbox,
                  child: ListView.builder(
                    itemCount: _inbox.length,
                    itemBuilder: (ctx, i) {
                      final msg = _inbox[i] as Map<String, dynamic>;
                      final peerId = msg['peer_id'] as int;
                      final peerName =
                          msg['peer_name'] as String? ?? 'Onbekend';
                      final snippet = msg['latest_message'] as String? ?? '';
                      final unreadCount = msg['unread_count'] as int? ?? 0;

                      // cap snippet length
                      final displaySnippet = snippet.length > 40
                          ? '${snippet.substring(0, 40)}…'
                          : snippet;

                      final deleting = _deletingPeerIds.contains(peerId);

                      Widget? unreadBadge;
                      if (unreadCount > 0) {
                        unreadBadge = Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(peerName.isNotEmpty
                              ? peerName[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(peerName),
                        subtitle: Text(displaySnippet),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (unreadBadge != null) unreadBadge,
                            IconButton(
                              tooltip: 'Chat verwijderen',
                              icon: deleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.delete_outline),
                              onPressed: deleting
                                  ? null
                                  : () => _confirmDeleteConversation(
                                        peerId,
                                        peerName,
                                      ),
                            ),
                          ],
                        ),
                        onTap: () => _openConversation(peerId, peerName),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.create),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewMessageScreen()),
          ).then((_) => _loadInbox());
        },
      ),
    );
  }
}
