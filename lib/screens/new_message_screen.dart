// lib/screens/new_message_screen.dart

import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import 'dart:convert';

class NewMessageScreen extends StatefulWidget {
  /// If non-null, we’ll auto-select this user in the dropdown.
  final int? prefillRecipientId;

  /// If non-null, we’ll fill the text field with this content.
  final String? prefillBody;

  const NewMessageScreen({
    super.key,
    this.prefillRecipientId,
    this.prefillBody,
  });

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  List<dynamic> _members = [];
  bool _loading = true;
  int? _selectedUserId; // null = broadcast to all
  final TextEditingController _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    _loadMembers().then((_) {
      // Apply the prefillRecipient if provided
      if (widget.prefillRecipientId != null) {
        setState(() {
          _selectedUserId = widget.prefillRecipientId;
        });
      }
    });

    // Apply the prefillBody if provided
    if (widget.prefillBody != null) {
      _bodyCtrl.text = widget.prefillBody!;
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);

    // 1) Fetch current user to get group_id and role
    final meResp = await ApiHelper.get('/gebruikers/mij');
    if (meResp.statusCode != 200) {
      setState(() {
        _members = [];
        _loading = false;
      });
      return;
    }
    final me = jsonDecode(meResp.body);
    final groupId = me['group_id'] as int?;
    final role = me['role'] as String? ?? 'user';

    // 2) Load group members
    if (groupId != null) {
      final resp = await ApiHelper.get('/gebruikers/groep/$groupId');
      if (resp.statusCode == 200) {
        _members = jsonDecode(resp.body) as List<dynamic>;
      } else {
        _members = [];
      }
    } else {
      _members = [];
    }

    // 3) If admin or superuser, allow broadcast
    if (role == 'admin' || role == 'superuser') {
      _members.insert(0, {'id': null, 'name': 'Stuur naar iedereen'});
    }

    setState(() => _loading = false);
  }

  Future<void> _send() async {
    final content = _bodyCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Typ eerst een bericht.')),
      );
      return;
    }

    final payload = {
      'content': content,
      if (_selectedUserId != null) 'recipient_id': _selectedUserId,
      if (_selectedUserId == null) 'group_broadcast': true,
    };

    final resp = await ApiHelper.post('/messages/send', payload);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bericht succesvol verzonden!')),
      );
      _bodyCtrl.clear();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kon niet versturen: ${resp.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nieuw bericht')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<int?>(
                    hint: const Text('Kies ontvanger'),
                    value: _selectedUserId,
                    items: _members.map((m) {
                      return DropdownMenuItem<int?>(
                        value: m['id'] as int?,
                        child: Text(m['name'] as String),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedUserId = v),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: _bodyCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Typ je bericht…',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      expands: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _send,
                      child: const Text('Verstuur'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
