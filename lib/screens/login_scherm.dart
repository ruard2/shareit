// lib/screens/login_scherm.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_helper.dart';
import '../widgets/design_system.dart';
import 'vergeten_pin_scherm.dart';

class LoginScherm extends StatefulWidget {
  const LoginScherm({super.key});

  @override
  _LoginSchermState createState() => _LoginSchermState();
}

class _LoginSchermState extends State<LoginScherm> {
  final _emailCtrl = TextEditingController();
  final _pinCtrl   = TextEditingController();
  bool _isLoading  = false;
  bool _showPin    = false;

  // ---- core logic (unchanged) ------------------------------------------------

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _pinCtrl.text.trim().isEmpty) {
      _showMessage('Vul je e-mail en pincode in.');
      return;
    }
    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final pin   = _pinCtrl.text.trim();

    try {
      final url = '${ApiHelper.baseUrl}/login';
      print('🌐 [LOGIN] POST → $url');
      print('🌐 [LOGIN] Body: email=$email, pin=[hidden]');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'pin_code': pin}),
      );

      print('🌐 [LOGIN] Response status: ${response.statusCode}');
      print('🌐 [LOGIN] Response headers: ${response.headers}');
      print('🌐 [LOGIN] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final loginResult = json.decode(response.body);

        final accessToken = loginResult['access_token'] as String?;
        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('session_id', accessToken);
          await prefs.setString('token', accessToken);
        } else {
          final rawCookie = response.headers['set-cookie'];
          if (rawCookie != null) {
            final sessionId = _extractSessionId(rawCookie);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('session_id', sessionId);
          } else {
            _showMessage('Inloggen mislukt: geen sessie ontvangen.');
            setState(() => _isLoading = false);
            return;
          }
        }

        final isApproved = loginResult['is_approved'] ?? false;
        final isAdmin    = loginResult['is_admin'] ?? false;

        if (!isApproved && !isAdmin) {
          _showMessage(
              'Je bent nog niet goedgekeurd door de beheerder van je groep.');
          setState(() => _isLoading = false);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        prefs.setString('user_id', loginResult['id']?.toString() ?? '');
        prefs.setString('email', loginResult['email'] ?? '');
        prefs.setBool('is_admin', isAdmin);
        prefs.setBool('is_approved', isApproved);
        prefs.setString('role', loginResult['role'] ?? 'user');

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showMessage('Inloggen mislukt. Controleer je gegevens.');
      }
    } catch (e, stackTrace) {
      print('❌ [LOGIN] Exception type: ${e.runtimeType}');
      print('❌ [LOGIN] Exception: $e');
      print('❌ [LOGIN] Stack: $stackTrace');
      _showMessage('Fout: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _extractSessionId(String rawCookie) {
    for (final part in rawCookie.split(';')) {
      if (part.trim().startsWith('session_id=')) {
        return part.trim().substring('session_id='.length);
      }
    }
    return '';
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Let op'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isTablet = Breakpoints.isTablet(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Inloggen'),
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
                // ---- header ----
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welkom terug',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Log in met je e-mail en pincode.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ---- form section ----
                IosSection(
                  margin: EdgeInsets.zero,
                  children: [
                    // Email
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-mailadres',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                    ),

                    // Divider
                    Divider(height: 0.5, thickness: 0.5, indent: 16, color: cs.outline),

                    // PIN
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _pinCtrl,
                        obscureText: !_showPin,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Pincode',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPin
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: cs.onSurfaceVariant,
                            ),
                            onPressed: () => setState(() => _showPin = !_showPin),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ---- primary button ----
                AppleFilledButton(
                  label: 'Inloggen',
                  isLoading: _isLoading,
                  onPressed: _login,
                ),

                const SizedBox(height: 12),

                // ---- forgot pin ----
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VergetenPinScherm()),
                    ),
                    child: Text(
                      'Pincode vergeten?',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
