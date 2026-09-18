import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Jangan lupa tambahkan ini
import 'package:http/http.dart' as http;
import '../services/auth_usecase.dart';
import '../models/user_model.dart'; // Import model user
import '../pages/select_unit_page.dart'; // Import halaman pemilihan unit

import 'package:shared_preferences/shared_preferences.dart'; // Pastikan import ini ada di paling atas file


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthUsecase authUsecase = AuthUsecase();

  bool isLoading = false;
  bool isObscure = true; // Untuk toggle mata password

  void handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("email / username dan password wajib diisi!")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      

      final prefs = await SharedPreferences.getInstance();
      
      // Ambil objek user-nya
      // result['user'] di sini sudah bertipe UserModels
      final userData = await authUsecase.login(
        emailController.text,
        passwordController.text,
      );

      // VALIDASI LOGIN GAGAL
      if (userData.userId == 0 || userData.role == "No Role") {
        throw Exception("Email / password salah");
      }

      // 🔴 PERBAIKAN DI SINI:
      // Gunakan tanda TITIK (.) untuk mengambil data dari objek UserModels
      // Jangan pakai ['role'] atau ['id_unit_akses']
      
      final String role = userData.role.toLowerCase(); 
      final String unitAkses = userData.idUnitAkses ?? ""; 

      print("==== DEBUG NAVIGASI ====");
      print("ROLE: $role");
      print("UNIT AKSES: $unitAkses");
      print("ID UNIT: ${userData.idUnit}");

      // Simpan ke SharedPreferences (Gunakan nama variabel dari user_model.dart kamu)
      await prefs.setString('role', role);
      await prefs.setInt('user_id', userData.userId);
      await prefs.setString('nama_lengkap', userData.name);

      await prefs.setString('unit', userData.unit ?? '');

      if (!mounted) return;

      // Logika navigasi pemilihan unit
      if (role == 'operator' && unitAkses.contains(',')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SelectUnitPage(unitIds: unitAkses),
          ),
        );
      } else {
        // Jika cuma 1 unit, simpan idUnit-nya
        await prefs.setInt('unit_id', userData.idUnit);

        if (role == 'administrator') {
          Navigator.pushReplacementNamed(context, '/dashboard_administrator');
        } else if (role == 'pimpinan') {
          Navigator.pushReplacementNamed(context, '/dashboard_pimpinan');
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard_operator');
        }
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }




void showForgotPasswordModal() {
  final resetEmailController = TextEditingController();
  bool isSending = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder( // Agar bisa update state loading di dalam dialog
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(
              "Lupa Password",
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Masukkan email Anda untuk menerima link reset password.",
                  style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: resetEmailController,
                  style: GoogleFonts.nunito(),
                  decoration: InputDecoration(
                    hintText: "Email terdaftar",
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Batal", style: GoogleFonts.nunito(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF194CB6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                // ... di dalam ElevatedButton onPressed ...
                onPressed: isSending ? null : () async {
                  if (resetEmailController.text.isEmpty) return;
                  
                  setModalState(() => isSending = true);
                  
                  try {
                    // 🔥 DI SINI LOGIKANYA DIMULAI
                    final response = await http.post(
                      Uri.parse("http://localhost:8000/auth/forgot-password"), // URL Python kamu
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode({"email": resetEmailController.text.trim()}),
                    );

                    // 🔥 ATURAN PENGECEKAN EMAIL TERDAFTAR
                    if (response.statusCode == 200) {
                      // Jika email ada di DB, Python kirim status 200
                      Navigator.pop(context); // Tutup modal
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Link reset password berhasil dikirim ke email!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else if (response.statusCode == 404) {
                      // Jika email TIDAK ADA di DB, Python kirim status 404
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Maaf Ci, email tersebut tidak terdaftar di sistem!"),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } else {
                      // Jika ada error lain (misal server mati)
                      throw Exception("Gagal terhubung ke server");
                    }

                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Terjadi kesalahan koneksi. Coba lagi nanti.")),
                    );
                  } finally {
                    setModalState(() => isSending = false);
                  }
              },
                child: isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Kirim", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}





  @override
  Widget build(BuildContext context) {
    // Definisi Warna sesuai gambar doc
    const Color primaryBlue = Color(0xFF194CB6); 

    return Scaffold(
      body: Stack(
        children: [
          /// 🔥 BACKGROUND IMAGE
          SizedBox.expand(
            child: Image.asset(
              "assets/bg.png", 
              fit: BoxFit.cover,
            ),
          ),

          /// 🔥 OVERLAY GELAP (Agak tebal dikit biar teks putih kebaca)
          Container(
            color: Colors.black.withOpacity(0.6),
          ),

          /// 🔥 CONTENT
          Center(
            child: SingleChildScrollView( // Tambahkan agar tidak error pixel di layar kecil
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// LOGO
                  Image.asset(
                    "assets/logo.png",
                    height: 100,
                  ),
                  const SizedBox(height: 20),

                  /// JUDUL SISTEM
                  Text(
                    "Sistem Informasi Penyimpanan Arsip Digital",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "Universitas Prabumulih",
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// 🔥 CARD LOGIN (Disesuaikan lebarnya)
                  Container(
                    width: 500, // Ukuran standar card login web
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "LOGIN",
                          style: GoogleFonts.nunito(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 35),

                        /// FIELD EMAIL
                        TextField(
                          controller: emailController,
                          style: GoogleFonts.nunito(),
                          decoration: InputDecoration(
                            hintText: "Email / Username",
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        /// FIELD PASSWORD
                        TextField(
                          controller: passwordController,
                          obscureText: isObscure,
                          style: GoogleFonts.nunito(),
                          decoration: InputDecoration(
                            hintText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                            fillColor: Colors.grey[100],
                            suffixIcon: IconButton(
                              icon: Icon(
                                isObscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => isObscure = !isObscure),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        /// BUTTON LOGIN (Biru Terang sesuai branding)
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    "LOGIN",
                                    style: GoogleFonts.nunito(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        TextButton(
                          onPressed: showForgotPasswordModal,
                          child: Text(
                            "Lupa password?",
                            style: GoogleFonts.nunito(color: Colors.grey[600]),
                          ),
                        ),
                      ],
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