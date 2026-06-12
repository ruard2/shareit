// lib/screens/conversation_screen.dart

import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import 'dart:convert';

class ConversationScreen extends StatefulWidget {
  final int withUserId;
  final String withUserName;

  const ConversationScreen({
    super.key,
    required this.withUserId,
    required this.withUserName,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    setState(() => _loading = true);
    try {
      final resp =
          await ApiHelper.get('/messages/conversation/${widget.withUserId}');
      if (resp.statusCode == 200) {
        _messages = jsonDecode(resp.body) as List<dynamic>;
      } else {
        _messages = [];
        _showSnack('Kon gesprek niet laden (${resp.statusCode})');
      }
    } catch (e) {
      _messages = [];
      _showSnack('Netwerkfout bij laden');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    final body = {
      'recipient_id': widget.withUserId,
      'content': text,
    };

    try {
      final resp = await ApiHelper.post('/messages/send', body);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _controller.clear();
        await _loadConversation();
      } else {
        _showSnack('Kon bericht niet versturen');
      }
    } catch (e) {
      _showSnack('Netwerkfout bij versturen');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDeleteConversation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chat verwijderen?'),
        content: Text(
          'Het hele gesprek met ${widget.withUserName} wordt verwijderd. '
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

    try {
      final resp =
          await ApiHelper.delete('/messages/conversation/${widget.withUserId}');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (mounted) {
          setState(() => _messages = []);
          _showSnack('Chat verwijderd');
        }
      } else {
        _showSnack('Verwijderen mislukt (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Netwerkfout bij verwijderen');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // één keer omkeren (performance-fix)
    final List<Map<String, dynamic>> msgs = _messages.reversed
        .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat met ${widget.withUserName}'),
        actions: [
          IconButton(
            tooltip: 'Chat verwijderen',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDeleteConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadConversation,
                    child: msgs.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Nog geen berichten')),
                            ],
                          )
                        : ListView.builder(
                            reverse:
                                true, // nieuwste onderaan, scrolt naar beneden
                            padding: const EdgeInsets.all(8),
                            itemCount: msgs.length,
                            itemBuilder: (ctx, index) {
                              final msg = msgs[index];
                              // isMe = als de afzender niet de ander is, ben ik het zelf
                              final bool isMe =
                                  msg['sender_id'] != widget.withUserId;

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75,
                                  ),
                                  child: Card(
                                    color: isMe
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : Theme.of(context).cardColor,
                                    elevation: 1,
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Text(
                                        (msg['content'] ?? '') as String,
                                        style: TextStyle(
                                          color: isMe
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        hintText: 'Typ een bericht…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Versturen',
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    onPressed: _sending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
