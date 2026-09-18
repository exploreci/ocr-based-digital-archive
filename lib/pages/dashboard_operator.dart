import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:arsipdigital_web/main_layout.dart';
import 'package:arsipdigital_web/pages/search.dart';

import 'package:shared_preferences/shared_preferences.dart';

class DashboardOperator extends StatefulWidget {
  const DashboardOperator({super.key});

  @override
  State<DashboardOperator> createState() => _DashboardOperatorState();
}

class _DashboardOperatorState extends State<DashboardOperator> {
  final String apiUrl = "http://127.0.0.1:8000";
  List<dynamic> _allMasuk = [];
  List<dynamic> _allKeluar = [];


  String currentRole = "";
  int currentUserId = 0;
  int currentUnitId = 0;
  String currentUnit = "";

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentRole = prefs.getString('role') ?? "";
      currentUnitId = prefs.getInt('unit_id') ?? 0; // ← Ambil data unit_id
    });
    
    // Pastikan ngambil data suratnya SETELAH role & unit keload
    _loadAllData(); 
  }


  Future<void> _loadAllData() async {
    try {
      final resMasuk = await http.get(Uri.parse('$apiUrl/api/surat-masuk?role=$currentRole&id_unit=$currentUnitId'));
      
      final resKeluar = await http.get(Uri.parse('$apiUrl/api/surat-keluar?role=$currentRole&id_unit=$currentUnitId'));
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
    return MainLayout(
      showHamburger: false,
      title: "Sistem Informasi Penyimpanan Arsip Digital",
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              children: [
                Text(
                  "Sistem Informasi Penyimpanan Arsip Digital",
                  style: GoogleFonts.nunito(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Kelola Arsip Surat Masuk dan Surat Keluar Berbasis OCR & Rule-Based System",
                  style: GoogleFonts.nunito(
                      fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 40),

                // ── SEARCH BAR ──
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
                    child: Container(
                      width: 600,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Cari nomor surat, perihal, asal/tujuan...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // ── GRID UTAMA ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 900;

                    if (isMobile) {
                      return Column(children: _buildMobileLayout(context));
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── KOLOM KIRI ──
                        Column(
                          children: [
                            _buildMainCard(
                              context,
                              title: "Upload Surat Masuk",
                              subtitle: "Unggah dan Ekstraksi Surat Masuk",
                              icon: Icons.cloud_upload,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _buildStatCard(
                                  _allMasuk.length.toString(),
                                  "Surat Masuk",
                                  Icons.mail_outline,
                                  Colors.blue,
                                ),
                                const SizedBox(width: 20),
                                _buildStatCard(
                                  _allKeluar.length.toString(),
                                  "Surat Keluar",
                                  Icons.send_outlined,
                                  Colors.teal,
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(width: 25),

                        // ── KOLOM KANAN ──
                        Column(
                          children: [
                            _buildSideCard(
                              "Upload Surat Keluar",
                              "Unggah dan Ekstraksi Surat Keluar",
                              Icons.upload_file,
                              Colors.amber,
                              onTap: () => Navigator.pushNamed(
                                  context, "/upload_keluar"),
                            ),
                            const SizedBox(height: 20),
                            _buildSideCard(
                              "Arsip Surat Masuk",
                              "Kelola dan Cari Arsip Surat Masuk",
                              Icons.folder_shared,
                              Colors.blue,
                              onTap: () => Navigator.pushNamed(
                                  context, "/arsip-surat-masuk"),
                            ),
                            const SizedBox(height: 20),
                            _buildSideCard(
                              "Arsip Surat Keluar",
                              "Kelola dan Cari Arsip Surat Keluar",
                              Icons.menu_book,
                              Colors.brown,
                              onTap: () => Navigator.pushNamed(
                                  context, "/arsip-surat-keluar"),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // WIDGET HELPERS
  // ================================================================

  Widget _buildMainCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 550,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 90, color: color.withOpacity(0.8)),
          const SizedBox(height: 15),
          Text(title,
              style: GoogleFonts.nunito(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          Text(subtitle,
              style: GoogleFonts.nunito(color: Colors.grey[600])),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, "/upload-arsip"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              minimumSize: const Size(180, 45),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Unggah Surat",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String count, String label, IconData icon, Color color) {
    return Container(
      width: 265,
      height: 130,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count,
                  style: GoogleFonts.nunito(
                      fontSize: 26, fontWeight: FontWeight.w900)),
              Text(label,
                  style: GoogleFonts.nunito(
                      color: Colors.grey[600], fontSize: 15)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSideCard(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 500,
        height: 130,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(subtitle,
                      style: GoogleFonts.nunito(
                          fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMobileLayout(BuildContext context) {
    return [
      _buildMainCard(
        context,
        title: "Upload Surat Masuk",
        subtitle: "Unggah Dokumen",
        icon: Icons.cloud_upload,
        color: Colors.blue,
      ),
      const SizedBox(height: 20),
      _buildSideCard(
        "Upload Surat Keluar",
        "Unggah Dokumen",
        Icons.upload_file,
        Colors.amber,
      ),
    ];
  }
}