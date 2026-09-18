import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_operator.dart';
import 'pages/dashboard_admin.dart';
import 'pages/dashboard_pimpinan.dart';
import 'pages/manajemen_user.dart';
import 'pages/upload_arsip_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/arsip_surat_masuk_page.dart';
import 'pages/arsip_surat_keluar.dart';
import "pages/daftar_unit_page.dart";
import "pages/editor_surat_keluar.dart";
import "pages/surat_keluar_preview.dart";
import "pages/inbox_disposisi.dart";
import "package:flutter_localizations/flutter_localizations.dart"; // Import ini


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Hapus initialRoute dan routes, ganti dengan onGenerateRoute
      onGenerateRoute: (settings) {
        // 1. Logika Khusus untuk Reset Password (Menangkap Token)
        if (settings.name != null && settings.name!.contains('/reset-password')) {
          final uri = Uri.parse(settings.name!);
          final token = uri.queryParameters['token']; // Ambil token dari URL

          return MaterialPageRoute(
            builder: (context) => ResetPasswordPage(token: token),
          );
        }

        // 2. Logika untuk Route Standar lainnya
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/dashboard_operator':
            return MaterialPageRoute(builder: (_) => const DashboardOperator());
          case '/dashboard_administrator':
            return MaterialPageRoute(builder: (_) => const DashboardAdmin());
          case '/dashboard_pimpinan':
            return MaterialPageRoute(builder: (_) => const DashboardPimpinan());
          case '/manajemen-user':
            return MaterialPageRoute(builder: (_) => const ManajemenUserPage());
          case '/daftar-unit':
            return MaterialPageRoute(builder: (_) => const DaftarUnitPage());
          case '/upload-arsip':
            return MaterialPageRoute(builder: (_) => const UploadArsipPage(jenisArsip: 'masuk'));
          case '/upload_masuk':
            return MaterialPageRoute(builder: (_) => const UploadArsipPage(jenisArsip: 'masuk'));  
          case '/upload_keluar':
            return MaterialPageRoute(builder: (_) => const UploadArsipPage(jenisArsip: 'keluar'));
          case '/editor-surat-keluar':
            return MaterialPageRoute(builder: (_) => const EditorSuratKeluarPage());
          case '/arsip-surat-masuk':
            return MaterialPageRoute(builder: (_) => const DaftarArsipMasukPage());
          case '/inbox-disposisi':
            return MaterialPageRoute(builder: (_) => const InboxDisposisiPage());  
          case '/arsip-surat-keluar':
            return MaterialPageRoute(builder: (_) => const DaftarArsipKeluarPage());  
          default:
            return MaterialPageRoute(builder: (_) => const LoginPage());
        }
      },

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Bahasa Indonesia
        Locale('en', 'US'), // Bahasa Inggris
      ],
    );
  }
}