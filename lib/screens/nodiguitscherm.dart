import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/api_helper.dart';
import '../widgets/design_system.dart';

class NodigUitScherm extends StatefulWidget {
  const NodigUitScherm({super.key});

  @override
  State<NodigUitScherm> createState() => _NodigUitSchermState();
}

class _NodigUitSchermState extends State<NodigUitScherm> {
  String? inviteCode;
  String? groepNaam;
  String? foutmelding;

  @override
  void initState() {
    super.initState();
    _haalInviteCodeOp();
  }

  Future<void> _haalInviteCodeOp() async {
    try {
      final response = await ApiHelper.get('/groep/invite_code');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          inviteCode = data['invite_code'];
          groepNaam = data['group_name'];
        });
      } else {
        setState(() => foutmelding =
            'Kon uitnodigingscode niet ophalen (status: ${response.statusCode})');
      }
    } catch (e) {
      setState(() => foutmelding = 'Fout bij ophalen uitnodigingscode: $e');
    }
  }

  /// Bouwt een tap-to-join link op basis van de huidige host.
  /// Op het web: https://<host><pad>?invite=CODE
  String _inviteLink() {
    final base = Uri.base;
    final root = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
    );
    return root.replace(queryParameters: {'invite': inviteCode!}).toString();
  }

  String _maakBericht() {
    final naam = groepNaam ?? 'onze groep';
    return 'Hoi! Je bent uitgenodigd voor "$naam" in ShareIt.\n\n'
        'Tik op deze link om mee te doen:\n${_inviteLink()}\n\n'
        '(Of voer in de app de code in: $inviteCode)';
  }

  Future<void> _launchOrSnack(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kon geen app openen.')));
    }
  }

  Future<void> _deelWhatsApp() async =>
      _launchOrSnack(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_maakBericht())}'));

  Future<void> _deelEmail() async => _launchOrSnack(Uri(
        scheme: 'mailto',
        query:
            'subject=${Uri.encodeComponent('Uitnodiging voor ${groepNaam ?? 'onze groep'}')}&body=${Uri.encodeComponent(_maakBericht())}',
      ));

  Future<void> _deelSMS() async =>
      _launchOrSnack(Uri.parse('sms:?body=${Uri.encodeComponent(_maakBericht())}'));

  Future<void> _kopieer(String waarde, String melding) async {
    await Clipboard.setData(ClipboardData(text: waarde));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(melding)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nodig iemand uit')),
      body: foutmelding != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(foutmelding!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error)),
              ),
            )
          : inviteCode == null
              ? const Center(child: CircularProgressIndicator())
              : ResponsiveCenter(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Icon(Icons.group_add_rounded, size: 56, color: cs.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Nodig mensen uit voor ${groepNaam ?? 'je groep'}',
                        textAlign: TextAlign.center,
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deel de link hieronder. Wie erop tikt komt direct in het '
                        'aanmeldscherm met de code al ingevuld.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),

                      // Link-kaart
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Uitnodigingslink',
                                style: tt.labelMedium
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            SelectableText(_inviteLink(),
                                style: tt.bodyMedium),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _kopieer(_inviteLink(), 'Link gekopieerd'),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Kopieer link'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Delen via', style: tt.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _deelWhatsApp,
                            icon: const Icon(Icons.chat_rounded),
                            label: const Text('WhatsApp'),
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
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Code als terugval
                      Center(
                        child: Column(
                          children: [
                            Text('Of geef de code door',
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () =>
                                  _kopieer(inviteCode!, 'Code gekopieerd'),
                              child: Text(
                                inviteCode!,
                                style: tt.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            Text('(tik om te kopiëren)',
                                style: tt.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}
