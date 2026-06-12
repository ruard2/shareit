import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../env.dart';

class UserService {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id') ?? '';
    return {
      'Content-Type': 'application/json',
      'cookie': 'session_id=$sessionId',
    };
  }

  static Future<Map<String, dynamic>?> login(String email, String pin) async {
    final response = await http.post(
      Uri.parse('${Env.apiBase}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'pin_code': pin}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      // Backend puts the access_token in the JSON body AND as the session_id cookie value.
      // On Android, Set-Cookie headers are not accessible, so we read the token from the body.
      if (data['access_token'] != null) {
        await prefs.setString('session_id', data['access_token'] as String);
        await prefs.setString('token', data['access_token'] as String);
      }

      return data;
    } else {
      print('❌ Login mislukt: ${response.statusCode} ${response.body}');
      return null;
    }
  }

  static Future<bool> registreer(Map<String, dynamic> gebruiker) async {
    final response = await http.post(
      Uri.parse('${Env.apiBase}/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(gebruiker),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<List<dynamic>> haalGebruikersTerGoedkeuringOp() async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('${Env.apiBase}/users/pending'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<bool> keurGebruikerGoed(int gebruikerId) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('${Env.apiBase}/users/approve/$gebruikerId'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> haalGebruikerOp(int id) async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('${Env.apiBase}/gebruikers/mij'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  static Future<List<UserModel>> getGroupMembers(int groupId) async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('${Env.apiBase}/gebruikers/groep/$groupId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => UserModel.fromJson(json)).toList();
    }
    throw Exception('Fout bij ophalen groepsleden');
  }

  static Future<void> approveUser(int userId) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('${Env.apiBase}/users/approve/$userId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Gebruiker goedkeuren mislukt');
    }
  }

  static Future<void> makeAdmin(int userId, int groupId) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('${Env.apiBase}/groups/$groupId/admins/$userId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Beheerder maken mislukt');
    }
  }

  static Future<bool> updateUser({
    required int userId,
    required String name,
    required String address,
    required String pin,
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('${Env.apiBase}/users/me/preferences'),
      headers: headers,
      body: jsonEncode({
        'profile': {
          'name': name,
        },
      }),
    );
    return response.statusCode == 200;
  }

  static Future<UserModel?> haalHuidigeGebruikerOp() async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('${Env.apiBase}/gebruikers/mij'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson(data);
    } else {
      print('❌ Fout bij ophalen gebruiker: ${response.statusCode}');
      return null;
    }
  }

  static Future<int?> getUserId() async {
    final gebruiker = await haalHuidigeGebruikerOp();
    return gebruiker?.id;
  }
}
