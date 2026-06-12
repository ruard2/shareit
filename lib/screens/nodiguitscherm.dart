import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/api_helper.dart';

class NodigUitScherm extends StatefulWidget {
  const NodigUitScherm({super.key});

  @override
  State<NodigUitScherm> createState() => _NodigUitSchermState();
}

class _NodigUitSchermState extends State<NodigUitScherm> {
  String? inviteCode;
  String? foutmelding;

  @override
  void initState() {
    super.initState();
    _haalInviteCodeOp();
  }

  Future<void> _haalInviteCodeOp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id'); // indien later nodig

      final response = await ApiHelper.get('/groep/invite_code');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          inviteCode = data['invite_code'];
        });
      } else {
        setState(() {
          foutmelding =
              'Kon uitnodigingscode niet ophalen (status: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        foutmelding = 'Fout bij ophalen uitnodigingscode: $e';
      });
    }
  }

  String _maakBericht() {
    final code = inviteCode ?? '';
    return 'Hoi! Sluit je aan bij onze groep in de app.\n'
        'Uitnodigingscode: $code\n'
        'Open de app en voer deze code in om toe te treden.';
  }

  Future<void> _launchOrSnack(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon geen app openen.')),
      );
    }
  }

  // ——— Deel-acties (zonder extra packages)
  Future<void> _deelWhatsApp() async {
    if (inviteCode == null) return;
    final text = Uri.encodeComponent(_maakBericht());
    final uri = Uri.parse('https://wa.me/?text=$text');
    await _launchOrSnack(uri);
  }

  Future<void> _deelTelegram() async {
    if (inviteCode == null) return;
    final text = Uri.encodeComponent(_maakBericht());
    final uri = Uri.parse('https://t.me/share/url?url=&text=$text');
    await _launchOrSnack(uri);
  }

  Future<void> _deelEmail() async {
    if (inviteCode == null) return;
    final subject = Uri.encodeComponent('Uitnodiging voor onze groep');
    final body = Uri.encodeComponent(_maakBericht());
    final uri = Uri(
      scheme: 'mailto',
      query: 'subject=$subject&body=$body',
    );
    await _launchOrSnack(uri);
  }

  Future<void> _deelSMS() async {
    if (inviteCode == null) return;
    final body = Uri.encodeComponent(_maakBericht());
    // Zonder nummer -> gebruiker kiest zelf contact
    final uri = Uri.parse('sms:?body=$body');
    await _launchOrSnack(uri);
  }

  Future<void> _kopieerCode() async {
    if (inviteCode == null) return;
    await Clipboard.setData(ClipboardData(text: inviteCode!)); // non-null
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code gekopieerd')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heeftFout = foutmelding != null;
    final heeftCode = inviteCode != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Nodig iemand uit')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (heeftFout)
                Text(
                  foutmelding!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              if (heeftCode) ...[
                const Text(
                  'Deel deze code met iemand om hem/haar toe te laten treden tot jouw groep:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                SelectableText(
                  inviteCode!, // non-null assertion; we zitten in heeftCode
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _deelWhatsApp,
                      icon: const Icon(Icons.chat), // geen extra icon pack
                      label: const Text('WhatsApp'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _deelTelegram,
                      icon: const Icon(Icons.send),
                      label: const Text('Telegram'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _deelEmail,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('E-mail'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _deelSMS,
                      icon: const Icon(Icons.sms_outlined),
                      label: const Text('SMS'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _kopieerCode,
                      icon: const Icon(Icons.copy),
                      label: const Text('Kopieer code'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tip: deze knoppen zetten de code en uitleg voor je klaar.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ] else if (!heeftFout)
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
