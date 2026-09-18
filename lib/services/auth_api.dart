import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  final String baseUrl = "http://127.0.0.1:8000/auth";

  // Cukup minta email & password saja
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        // JANGAN kirim role di sini, biar Python yang menentukan
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // Ambil pesan error dari backend jika ada
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? "Email atau Password salah");
    }
  }
}