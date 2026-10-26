import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // static const String baseUrl = 'http://10.102.157.67:8000';
  static const String baseUrl = 'http://10.29.216.67:8000';

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 &&
        data['status'] == 'success') {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'access_token',
        data['access_token'],
      );

      await prefs.setString(
        'user_name',
        data['user']['name'],
      );

      await prefs.setString(
        'user_email',
        data['user']['email'],
      );

      await prefs.setString(
        'user_role',
        data['user']['role'],
      );

      return data;
    }

    throw Exception(
      data['detail'] ?? data['message'] ?? 'Login failed',
    );
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 &&
        data['status'] == 'success') {
      return data;
    }

    throw Exception(
      data['detail'] ?? data['message'] ?? 'Registration failed',
    );
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('access_token') != null;
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('user_role');
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('user_name');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    
    return prefs.getString('access_token');
  }
}