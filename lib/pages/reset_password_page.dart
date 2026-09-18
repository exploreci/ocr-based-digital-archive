import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ResetPasswordPage extends StatefulWidget {
  final String? token;
  const ResetPasswordPage({super.key, this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;
  bool isObscureNew = true;      // ✅ hapus isObscure lama
  bool isObscureConfirm = true;

  Future<void> handleReset() async {
    final password = newPasswordController.text;

    // Validasi kekuatan password
    final String? errMsg = _validatePassword(password);
    if (errMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
      );
      return;
    }

    if (password != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password tidak cocok!")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("http://localhost:8000/auth/reset-password-final"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": widget.token,
          "new_password": newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password berhasil diubah! Silakan login."), backgroundColor: Colors.green),
        );
        Navigator.pushReplacementNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token tidak valid atau kadaluwarsa.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terjadi kesalahan server.")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Validasi aturan keamanan password.
  /// Mengembalikan pesan error jika tidak valid, null jika valid.
  String? _validatePassword(String password) {
    if (password.isEmpty) return "Password wajib diisi!";
    if (password.length < 8) return "Password minimal 8 karakter!";
    if (!RegExp(r'[A-Z]').hasMatch(password)) return "Password harus mengandung minimal 1 huruf besar!";
    if (!RegExp(r'[a-z]').hasMatch(password)) return "Password harus mengandung minimal 1 huruf kecil!";
    if (!RegExp(r'[0-9]').hasMatch(password)) return "Password harus mengandung minimal 1 angka!";
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return "Password harus mengandung minimal 1 simbol (contoh: @, #, !, _)!";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF194CB6);

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(child: Image.asset("assets/bg.png", fit: BoxFit.cover)),
          Container(color: Colors.black.withOpacity(0.6)),

          Center(
            child: Container(
              width: 450,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("RESET PASSWORD",
                    style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text("Masukkan password baru Anda",
                    style: GoogleFonts.nunito(color: Colors.grey[600])),
                  const SizedBox(height: 30),

                  // ✅ Input Password Baru — obscureText di TextField, bukan InputDecoration
                  TextField(
                    controller: newPasswordController,
                    obscureText: isObscureNew,
                    decoration: InputDecoration(
                      hintText: "Password Baru",
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: Colors.grey[100],
                      suffixIcon: IconButton(
                        icon: Icon(isObscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => isObscureNew = !isObscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ Input Konfirmasi Password
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: isObscureConfirm,
                    decoration: InputDecoration(
                      hintText: "Konfirmasi Password",
                      prefixIcon: const Icon(Icons.lock_reset),
                      filled: true,
                      fillColor: Colors.grey[100],
                      suffixIcon: IconButton(
                        icon: Icon(isObscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => isObscureConfirm = !isObscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Button Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : handleReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text("SIMPAN PASSWORD",
                            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}