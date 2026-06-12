// lib/screens/registratie_scherm.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_helper.dart';
import '../widgets/design_system.dart';
import 'home_screen.dart';
import 'dart:convert';

class RegistratieScherm extends StatefulWidget {
  const RegistratieScherm({super.key});

  @override
  State<RegistratieScherm> createState() => _RegistratieSchermState();
}

class _RegistratieSchermState extends State<RegistratieScherm> {
  final _formKey         = GlobalKey<FormState>();
  final naamController   = TextEditingController();
  final emailController  = TextEditingController();
  final telefoonController = TextEditingController();
  final adresController  = TextEditingController();
  final pin1Controller   = TextEditingController();
  final pin2Controller   = TextEditingController();
  final groepscodeController = TextEditingController();

  bool heeftGroepscode    = false;
  bool _obscurePin1       = true;
  bool _obscurePin2       = true;
  bool _isSubmitting      = false;
  List<dynamic> groepen   = [];
  int? geselecteerdeGroepId;

  @override
  void initState() {
    super.initState();
    _haalGroepenOp();
  }

  // ---- data ----------------------------------------------------------------

  Future<void> _haalGroepenOp() async {
    try {
      final response = await ApiHelper.get('/groups/all');
      final data = json.decode(response.body);
      setState(() {
        groepen = data;
        if (groepen.isNotEmpty) {
          geselecteerdeGroepId = groepen[0]['id'];
        }
      });
    } catch (_) {}
  }

  Future<void> _registreer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final pin = pin1Controller.text.trim();

    final Map<String, dynamic> body = {
      'name':         naamController.text.trim(),
      'email':        emailController.text.trim(),
      'phone_number': telefoonController.text.trim(),
      'address':      adresController.text.trim(),
      'pin_code':     pin,
    };

    if (heeftGroepscode) {
      body['invite_code'] = groepscodeController.text.trim();
    } else {
      if (geselecteerdeGroepId != null) {
        body['group_id'] = geselecteerdeGroepId;
      } else {
        _toonFout('Geen groep geselecteerd.');
        setState(() => _isSubmitting = false);
        return;
      }
    }

    try {
      final response = await ApiHelper.post('/register', body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;

        String? sessionId = responseData['access_token'] as String?;
        if (sessionId == null) {
          final rawCookie = response.headers['set-cookie'];
          if (rawCookie != null && rawCookie.contains('session_id=')) {
            sessionId = rawCookie
                .split(';')
                .firstWhere((e) => e.trim().startsWith('session_id='))
                .split('=')
                .last;
          }
        }

        if (sessionId == null) {
          _toonFout('Geen sessie ontvangen. Probeer opnieuw.');
          setState(() => _isSubmitting = false);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_id', sessionId);
        await prefs.setString('token', sessionId);

        final userResponse = await ApiHelper.get('/gebruikers/mij');
        final user = json.decode(userResponse.body);

        prefs.setString('user_id', user['id'].toString());
        prefs.setString('email', user['email']);
        prefs.setBool('is_admin', user['is_admin'] ?? false);
        prefs.setBool('is_approved', user['is_approved'] ?? false);
        prefs.setString('role', user['role'] ?? 'user');

        final isApproved = user['is_approved'] ?? false;

        if (isApproved) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          _toonDialoogEnSluit();
        }
      } else {
        _toonFout('Registratie mislukt: ${response.body}');
      }
    } catch (e) {
      _toonFout('Fout bij registratie: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _toonFout(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _toonDialoogEnSluit() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Aanmelding verzonden'),
        content: const Text(
          'Bedankt voor je aanmelding. De groepsbeheerder beoordeelt je verzoek. '
          'Zodra je goedgekeurd bent ontvang je een mail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isTablet = Breakpoints.isTablet(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Account aanmaken'),
        leading: BackButton(color: cs.primary),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 560 : double.infinity),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 48 : 16,
                  vertical: 24,
                ),
                children: [
                  // ---- header ----
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nieuw account',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vul je gegevens in om een account aan te maken.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ---- Persoonlijke gegevens ----
                  IosSection(
                    header: 'Persoonlijke gegevens',
                    margin: EdgeInsets.zero,
                    children: [
                      _field(
                        controller: naamController,
                        label: 'Naam',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => (v ?? '').isEmpty ? 'Vul naam in' : null,
                        next: true,
                      ),
                      _field(
                        controller: emailController,
                        label: 'E-mailadres',
                        icon: Icons.mail_outline_rounded,
                        type: TextInputType.emailAddress,
                        validator: (v) => (v ?? '').isEmpty ? 'Vul e-mail in' : null,
                        next: true,
                      ),
                      _field(
                        controller: telefoonController,
                        label: 'Telefoonnummer',
                        icon: Icons.phone_outlined,
                        type: TextInputType.phone,
                        validator: (v) => (v ?? '').isEmpty ? 'Vul telefoon in' : null,
                        next: true,
                      ),
                      _field(
                        controller: adresController,
                        label: 'Adres',
                        icon: Icons.location_on_outlined,
                        validator: (v) => (v ?? '').isEmpty ? 'Vul adres in' : null,
                        next: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ---- Beveiliging ----
                  IosSection(
                    header: 'Beveiliging',
                    margin: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: pin1Controller,
                          obscureText: _obscurePin1,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Pincode (4 cijfers)',
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
                          validator: (v) =>
                              (v ?? '').length != 4 ? '4 cijfers vereist' : null,
                        ),
                      ),
                      Divider(height: 0.5, thickness: 0.5, indent: 16, color: cs.outline),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: pin2Controller,
                          obscureText: _obscurePin2,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Herhaal pincode',
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
                          validator: (v) =>
                              v != pin1Controller.text ? 'Pin komt niet overeen' : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ---- Groep ----
                  IosSection(
                    header: 'Groep',
                    margin: EdgeInsets.zero,
                    children: [
                      SwitchListTile(
                        title: const Text('Ik heb een uitnodigingscode'),
                        subtitle: Text(
                          'Gebruik een code van je groepsbeheerder',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        value: heeftGroepscode,
                        onChanged: (val) => setState(() => heeftGroepscode = val),
                      ),
                      if (heeftGroepscode)
                        _field(
                          controller: groepscodeController,
                          label: 'Uitnodigingscode',
                          icon: Icons.key_outlined,
                          validator: (v) =>
                              (v ?? '').isEmpty ? 'Code vereist' : null,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: DropdownButtonFormField<int>(
                            value: geselecteerdeGroepId,
                            decoration: const InputDecoration(
                              labelText: 'Kies een groep',
                              prefixIcon: Icon(Icons.group_outlined),
                            ),
                            items: groepen.map<DropdownMenuItem<int>>((groep) {
                              return DropdownMenuItem<int>(
                                value: groep['id'],
                                child: Text(groep['name']),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => geselecteerdeGroepId = val),
                            validator: (val) =>
                                val == null ? 'Selecteer een groep' : null,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  AppleFilledButton(
                    label: 'Account aanmaken',
                    icon: Icons.check_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _registreer,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper: one text field row inside an IosSection
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
    bool next = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        textInputAction: next ? TextInputAction.next : TextInputAction.done,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: validator,
      ),
    );
  }
}
