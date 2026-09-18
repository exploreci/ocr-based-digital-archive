import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arsipdigital_web/main_layout.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:arsipdigital_web/pages/search.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPimpinan extends StatefulWidget {
  const DashboardPimpinan({super.key});

  @override
  State<DashboardPimpinan> createState() => _DashboardPimpinanState();
}

class _DashboardPimpinanState extends State<DashboardPimpinan> {
  final String apiUrl = "http://127.0.0.1:8000";
  List<dynamic> _allMasuk = [];
  List<dynamic> _allKeluar = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // dashboard_pimpinan.dart
Future<void> _loadAllData() async {
  try {
    // ✅ Ambil role dan unit_id yang sudah disimpan saat login
    final prefs = await SharedPreferences.getInstance();
    final role   = prefs.getString('role') ?? '';
    final unitId = prefs.getInt('unit_id') ?? 0;

    // ✅ Kirim sebagai query parameter
    final resMasuk = await http.get(
      Uri.parse('$apiUrl/api/surat-masuk?role=$role&id_unit=$unitId'),
    );
    final resKeluar = await http.get(
      Uri.parse('$apiUrl/api/surat-keluar?role=$role&id_unit=$unitId'),
    );

    if (resMasuk.statusCode == 200) {
      final d = json.decode(resMasuk.body);
      if (d['success'] == true) setState(() => _allMasuk = d['data']);
    }
    if (resKeluar.statusCode == 200) {
      final d = json.decode(resKeluar.body);
      if (d['success'] == true) setState(() => _allKeluar = d['data']);
    }
  } catch (_) {}
}

  @override
  Widget build(BuildContext context) {
    // Kita gunakan MainLayout sebagai pembungkus utama
    return MainLayout(
      title: "Sistem Informasi Penyimpanan Arsip Digital",
      showHamburger: false, //  tombol garis tiga (sidebar) muncul
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 850, // Membatasi lebar konten agar terpusat rapi
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- 1. JUDUL & SUBJUDUL ---
                      Text(
                        "Sistem Informasi Penyimpanan Arsip Digital",
                        style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Kelola Arsip Surat Masuk dan Surat Keluar Berbasis OCR & Rule-Based System",
                        style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 25),

                      // --- 2. SEARCH BAR ---
                      GestureDetector(
                        onTap: () {
                          showSearch(
                            context: context,
                            delegate: ArsipSearchDelegate(
                              allMasuk: _allMasuk,
                              allKeluar: _allKeluar,
                            ),
                          );
                        },
                        child: AbsorbPointer(
                          child: SizedBox(
                            width: 500,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Cari nomor surat, perihal, asal/tujuan...",
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Color(0xFF194CB6)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // --- 3. BARIS ATAS: KOTAK SURAT MASUK & KELUAR ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildMainCard(
                              title: "Arsip Surat Masuk",
                              subtitle: "Kelola dan Cari Arsip Surat Masuk",
                              icon: Icons.inventory_2_outlined,
                              iconColor: Colors.blue,
                              onTap: () {
                                Navigator.pushNamed(context, '/arsip-surat-masuk');
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildMainCard(
                              title: "Arsip Surat Keluar",
                              subtitle: "Kelola dan Cari Arsip Surat Keluar",
                              icon: Icons.inventory_outlined,
                              iconColor: Colors.lime, 
                              onTap: () {
                                Navigator.pushNamed(context, '/arsip-surat-keluar');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- 4. BARIS BAWAH: KOTAK STATISTIK ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              count: _allMasuk.length.toString(),
                              label: "Surat Masuk",
                              icon: Icons.move_to_inbox,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildStatBox(
                              count: _allKeluar.length.toString(),
                              label: "Surat Keluar",
                              icon: Icons.send_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // --- 5. FOOTER BAWAH ---
          
        ],
      ),
    );
  }

  

  // --- WIDGET HELPER: KOTAK ARSIP UTAMA ---
  Widget _buildMainCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 50, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B71CA), // Warna biru tombol
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              child: Text("Lihat Arsip Surat", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER: KOTAK STATISTIK ---
  Widget _buildStatBox({
    required String count,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 50, color: const Color(0xFF3B71CA)), // Icon warna biru
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count, style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.bold)),
              Text(label, style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade600)),
            ],
          )
        ],
      ),
    );
  }
}