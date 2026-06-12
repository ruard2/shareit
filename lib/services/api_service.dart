import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  // GET-request met optionele user-id, bearer-token én session cookie
  Future<http.Response> getRequest(String endpoint, {bool withUserId = false}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _buildHeaders(withUserId: withUserId);
    return await http.get(url, headers: headers);
  }

  // POST-request met JSON + bearer-token en session cookie indien nodig
  Future<http.Response> postJson(String endpoint, Map<String, dynamic> data, {bool withUserId = false}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _buildHeaders(withUserId: withUserId, json: true);
    return await http.post(url, headers: headers, body: jsonEncode(data));
  }

  // POST-request voor login: sla token én session ID op in SharedPreferences
  Future<http.Response> postForm(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(url, body: data);

    if (endpoint == '/login' && response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final token = responseData['access_token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token); // ✅ Opslaan token

      // ✅ Probeer ook session ID uit cookies te halen (Set-Cookie: session_id=xyz...)
      final rawCookie = response.headers['set-cookie'];
      if (rawCookie != null) {
        final sessionMatch = RegExp(r'session_id=([^;]+)').firstMatch(rawCookie);
        if (sessionMatch != null) {
          final sessionId = sessionMatch.group(1);
          await prefs.setString('session_id', sessionId!);
        }
      }
    }

    return response; // ✅ correct type
  }

  // ✅ Headers bouwen inclusief token, user-id en session cookie indien beschikbaar
  Future<Map<String, String>> _buildHeaders({bool withUserId = false, bool json = false}) async {
    final headers = <String, String>{};

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (withUserId) {
      final userId = prefs.getString('user_id');
      if (userId != null) {
        headers['user-id'] = userId;
      }
    }

    // ✅ Voeg Cookie-header toe met session ID als beschikbaar
    final sessionId = prefs.getString('session_id');
    if (sessionId != null) {
      headers['Cookie'] = 'session_id=$sessionId';
    }

    return headers;
  }
}
