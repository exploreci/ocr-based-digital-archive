import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Pastikan package ini sudah ada
import '../widgets/dashboard_card.dart';
import 'package:arsipdigital_web/main_layout.dart'; // Sesuaikan path ini dengan folder kamu

class DashboardAdmin extends StatelessWidget {
  const DashboardAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    // Bungkus semua konten dengan MainLayout
    return MainLayout(
      // Catatan: Jika MainLayout kamu pakai parameter 'body', ganti 'child:' jadi 'body:'
      showHamburger: false, 
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Pusatkan elemen ke tengah
          children: [
            // 🔹 1. JUDUL DAN SUBJUDUL
            Text(
              "Dashboard Administrator",
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Kelola Akun & Unit Kerja Universitas Prabumulih",
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // 🔹 2. SEARCH BAR (KOLOM CARI)
            // Center(
            //   child: Container(
            //     width: 600, // Lebar fixed agar tidak terlalu memanjang
            //     decoration: BoxDecoration(
            //       color: Colors.white,
            //       borderRadius: BorderRadius.circular(25),
            //       boxShadow: [
            //         BoxShadow(
            //           color: Colors.black.withOpacity(0.05),
            //           blurRadius: 10,
            //           offset: const Offset(0, 4),
            //         ),
            //       ],
            //       border: Border.all(color: Colors.grey.shade300),
            //     ),
            //     child: TextField(
            //       style: GoogleFonts.nunito(),
            //       decoration: InputDecoration(
            //         hintText: "Cari",
            //         hintStyle: GoogleFonts.nunito(color: Colors.grey[500]),
            //         prefixIcon: const Icon(Icons.search, color: Colors.grey),
            //         border: InputBorder.none,
            //         contentPadding: const EdgeInsets.symmetric(vertical: 15),
            //       ),
            //     ),
            //   ),
            // ),
            const SizedBox(height: 50),

            // 🔹 3. MENU CARD
           // 🔹 3. MENU CARD (User, Unit, Role)
            Center(
              child: Wrap(
                spacing: 40, // Jarak horizontal antar card (diperlebar dikit biar lega)
                runSpacing: 40, // Jarak vertikal kalau layarnya mengecil
                alignment: WrapAlignment.center,
                children: [
                  // CARD 1: MANAJEMEN USER
                  DashboardCard(
                    title: "Manajemen User",
                    subtitle: "Kelola akun pengguna dan hak akses",
                    buttonText: "Kelola User",
                    icon: Icons.person_outline, 
                    onTap: () {
                      Navigator.pushNamed(context, '/manajemen-user');
                    }
                  ),
                  
                  // CARD 2: MANAJEMEN UNIT
                  DashboardCard(
                    title: "Manajemen Unit",
                    subtitle: "Kelola data unit kerja di universitas",
                    buttonText: "Kelola Unit",
                    icon: Icons.account_balance_outlined, // Ikon ala institusi/gedung
                    onTap: () {
                      Navigator.pushNamed(context, '/daftar-unit');
                    }
                  ),

                  // CARD 3: MANAJEMEN ROLE
                  // DashboardCard(
                  //   title: "Manajemen Role",
                  //   subtitle: "Atur tingkat kewenangan akses sistem",
                  //   buttonText: "Kelola Role",
                  //   icon: Icons.admin_panel_settings_outlined, // Ikon perisai/akses
                  //   onTap: () {
                  //     Navigator.pushNamed(context, '/manajemen-role');
                  //   }
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}