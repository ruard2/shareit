// lib/screens/conversation_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/api_helper.dart';

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
  String _signature = '';
  Timer? _poll;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConversation();
    // Near-real-time: ververs stilletjes elke 4 seconden.
    _poll = Timer.periodic(
        const Duration(seconds: 4), (_) => _loadConversation(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _sigOf(List<dynamic> msgs) {
    if (msgs.isEmpty) return '0';
    final last = msgs.last as Map<String, dynamic>;
    return '${msgs.length}:${last['id']}:${last['read_at']}';
  }

  Future<void> _loadConversation({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final resp =
          await ApiHelper.get('/messages/conversation/${widget.withUserId}');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        final sig = _sigOf(data);
        // Alleen herbouwen als er echt iets veranderd is (geen flikkering).
        if (sig != _signature) {
          _signature = sig;
          if (mounted) setState(() => _messages = data);
        }
      } else if (!silent) {
        _showSnack('Kon gesprek niet laden (${resp.statusCode})');
      }
    } catch (_) {
      if (!silent) _showSnack('Netwerkfout bij laden');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final resp = await ApiHelper.post(
          '/messages/send', {'recipient_id': widget.withUserId, 'content': text});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _controller.clear();
        await _loadConversation(silent: true);
      } else {
        _showSnack('Kon bericht niet versturen');
      }
    } catch (_) {
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
              child: const Text('Annuleren')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Verwijderen')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final resp =
          await ApiHelper.delete('/messages/conversation/${widget.withUserId}');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (mounted) {
          setState(() {
            _messages = [];
            _signature = '0';
          });
          _showSnack('Chat verwijderd');
        }
      } else {
        _showSnack('Verwijderen mislukt (${resp.statusCode})');
      }
    } catch (_) {
      _showSnack('Netwerkfout bij verwijderen');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// "14:32" of "ma 14:32" / "12-04 14:32" afhankelijk van hoe oud.
  String _formatTime(dynamic iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final hhmm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) return hhmm;
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')} $hhmm';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final msgs = _messages.reversed
        .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.withUserName),
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
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text('Nog geen berichten',
                                    style: tt.bodyMedium
                                        ?.copyWith(color: cs.onSurfaceVariant)),
                              ),
                            ],
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            itemCount: msgs.length,
                            itemBuilder: (ctx, index) {
                              final msg = msgs[index];
                              final isMe =
                                  msg['sender_id'] != widget.withUserId;
                              return _bubble(cs, tt, msg, isMe);
                            },
                          ),
                  ),
          ),
          const Divider(height: 0.5, thickness: 0.5),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Typ een bericht…',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Versturen',
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
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

  Widget _bubble(
      ColorScheme cs, TextTheme tt, Map<String, dynamic> msg, bool isMe) {
    final time = _formatTime(msg['created_at']);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isMe ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                (msg['content'] ?? '') as String,
                style: tt.bodyMedium?.copyWith(
                    color: isMe ? Colors.white : cs.onSurface),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  time,
                  style: tt.labelSmall?.copyWith(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
