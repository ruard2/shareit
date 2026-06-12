// lib/screens/vergeten_pin_scherm.dart
// Feature 7: Vergeten PIN – aanvraag en reset in twee stappen
import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import '../widgets/design_system.dart';
import '../theme.dart';
import 'dart:convert';

class VergetenPinScherm extends StatefulWidget {
  const VergetenPinScherm({super.key});

  @override
  State<VergetenPinScherm> createState() => _VergetenPinSchermState();
}

class _VergetenPinSchermState extends State<VergetenPinScherm> {
  int  _stap    = 1;
  bool _loading = false;

  final _emailCtrl      = TextEditingController();
  final _tokenCtrl      = TextEditingController();
  final _newPinCtrl     = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _obscurePin1 = true;
  bool _obscurePin2 = true;

  String? _fout;
  String? _succes;

  // ---- logic ---------------------------------------------------------------

  Future<void> _vraagReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _fout = 'Vul je e-mailadres in.');
      return;
    }
    setState(() { _loading = true; _fout = null; _succes = null; });
    try {
      final resp = await ApiHelper.post('/auth/forgot-pin', {'email': email});
      if (resp.statusCode == 200) {
        setState(() {
          _stap   = 2;
          _succes =
              'Als dit e-mailadres bekend is, ontvang je een resetcode.\nControleer ook je spammap.';
          _loading = false;
        });
      } else {
        String detail = 'Onbekende fout';
        try { detail = jsonDecode(resp.body)['detail']?.toString() ?? detail; } catch (_) {}
        setState(() { _fout = detail; _loading = false; });
      }
    } catch (e) {
      setState(() { _fout = 'Fout: $e'; _loading = false; });
    }
  }

  Future<void> _resetPin() async {
    final token   = _tokenCtrl.text.trim().toUpperCase();
    final newPin  = _newPinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();

    if (token.isEmpty || newPin.isEmpty) {
      setState(() => _fout = 'Vul de code en je nieuwe pincode in.');
      return;
    }
    if (newPin != confirm) {
      setState(() => _fout = 'Pincodes komen niet overeen.');
      return;
    }
    if (newPin.length < 4) {
      setState(() => _fout = 'Pincode moet minimaal 4 tekens zijn.');
      return;
    }
    setState(() { _loading = true; _fout = null; _succes = null; });
    try {
      final resp = await ApiHelper.post(
          '/auth/reset-pin', {'token': token, 'new_pin': newPin});
      if (resp.statusCode == 200) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Gelukt!'),
            content: const Text(
                'Je pincode is opnieuw ingesteld. Log opnieuw in met je nieuwe pincode.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        String detail = 'Ongeldige of verlopen code';
        try { detail = jsonDecode(resp.body)['detail']?.toString() ?? detail; } catch (_) {}
        setState(() { _fout = detail; _loading = false; });
      }
    } catch (e) {
      setState(() { _fout = 'Fout: $e'; _loading = false; });
    }
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isTablet = Breakpoints.isTablet(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pincode vergeten'),
        leading: BackButton(color: cs.primary),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 48 : 16,
                vertical: 24,
              ),
              children: [
                // ---- Stap-indicator ----
                _buildStepIndicator(cs),
                const SizedBox(height: 28),

                // ---- Header ----
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stap == 1 ? 'Stap 1: E-mailadres' : 'Stap 2: Nieuwe pincode',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _stap == 1
                            ? 'Voer je e-mailadres in. We sturen een resetcode als het account bestaat.'
                            : 'Voer de code uit je e-mail in en stel een nieuwe pincode in.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ---- Form fields ----
                if (_stap == 1)
                  IosSection(
                    margin: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _vraagReset(),
                          decoration: const InputDecoration(
                            labelText: 'E-mailadres',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  IosSection(
                    margin: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _tokenCtrl,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Resetcode (uit e-mail)',
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                          ),
                        ),
                      ),
                      Divider(height: 0.5, thickness: 0.5, indent: 16, color: cs.outline),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _newPinCtrl,
                          obscureText: _obscurePin1,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Nieuwe pincode',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePin1
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePin1 = !_obscurePin1),
                            ),
                          ),
                        ),
                      ),
                      Divider(height: 0.5, thickness: 0.5, indent: 16, color: cs.outline),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _confirmPinCtrl,
                          obscureText: _obscurePin2,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _resetPin(),
                          decoration: InputDecoration(
                            labelText: 'Herhaal nieuwe pincode',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePin2
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePin2 = !_obscurePin2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Info block (step 2 success notice)
                  if (_succes != null) ...[
                    const SizedBox(height: 12),
                    _infoBlock(_succes!, AppleColors.systemGreen, cs),
                  ],
                ],

                // ---- Error ----
                if (_fout != null) ...[
                  const SizedBox(height: 12),
                  _infoBlock(_fout!, AppleColors.systemRed, cs),
                ],

                const SizedBox(height: 24),

                // ---- Primary button ----
                AppleFilledButton(
                  label: _stap == 1 ? 'Resetcode aanvragen' : 'Pincode instellen',
                  isLoading: _loading,
                  onPressed: _stap == 1 ? _vraagReset : _resetPin,
                ),

                // ---- Back link (step 2) ----
                if (_stap == 2) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _stap   = 1;
                        _fout   = null;
                        _succes = null;
                      }),
                      child: Text(
                        'Ander e-mailadres gebruiken',
                        style: TextStyle(color: cs.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    return Row(
      children: [
        _StapChip(nr: 1, actief: _stap == 1, klaar: _stap > 1),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: _stap > 1 ? AppleColors.systemGreen : cs.outline,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        _StapChip(nr: 2, actief: _stap == 2, klaar: false),
      ],
    );
  }

  Widget _infoBlock(String text, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            color == AppleColors.systemRed
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StapChip extends StatelessWidget {
  final int  nr;
  final bool actief;
  final bool klaar;

  const _StapChip({required this.nr, required this.actief, required this.klaar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = klaar
        ? AppleColors.systemGreen
        : actief
            ? cs.primary
            : cs.outline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: (actief || klaar) ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: klaar
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : Text(
                '$nr',
                style: TextStyle(
                  color: actief ? Colors.white : color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
