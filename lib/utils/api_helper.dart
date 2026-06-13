import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../env.dart';

class ApiHelper {
  static String get baseUrl => Env.apiBase;

  /// Zet een opgeslagen image_path om naar een toonbare URL.
  /// - Absolute http(s)-URL (bv. Cloudinary) → ongewijzigd gebruiken
  /// - Server-pad (/static/...) → baseUrl ervoor plakken
  /// - Anders (lokaal bestandspad) → ongewijzigd teruggeven
  static String resolveImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$baseUrl$path';
    return path;
  }

  /// True als het pad een netwerk-URL is (Cloudinary of /static/), niet een
  /// lokaal bestand — handig om Image.network vs Image.file te kiezen.
  static bool isNetworkImage(String path) =>
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('/');

  /// Headers voor geauthenticeerde requests.
  /// Stuurt ZOWEL Authorization: Bearer (werkt op web) ALS Cookie (werkt op mobiel).
  /// Public version so callers using http.Request / MultipartRequest can add auth headers.
  static Future<Map<String, String>> getHeaders() => _getHeaders();

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_id') ?? '';
    final preview = token.isEmpty ? 'EMPTY❌' : token.substring(0, token.length > 20 ? 20 : token.length);
    print('🔑 [API-HEADERS] token = "$preview..."');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'cookie': 'session_id=$token', // genegeerd op web, werkt op mobiel
    };
  }

  /// GET
  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    return http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
  }

  /// POST (body optioneel)
  static Future<http.Response> post(
      String endpoint, Map<String, dynamic>? body) async {
    final headers = await _getHeaders();
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// PUT
  static Future<http.Response> put(
      String endpoint, Map<String, dynamic>? body) async {
    final headers = await _getHeaders();
    return http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// DELETE
  static Future<http.Response> delete(String endpoint,
      {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    return http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
