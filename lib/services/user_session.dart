class UserSession {
  // Gunakan variabel static agar bisa diakses di mana saja tanpa membuat objek baru
  static String name = "";
  static String username = "";   // ← TAMBAH INI
  static String role = "";
  static String email = "";
  static String unit = "";       // ← pastikan ada ini (bukan unitId)
  static int userId = 0;
  static int unitId = 0;

  // Fungsi untuk mengisi data setelah login berhasil
  static void updateSession(Map<String, dynamic> userData) {
    name     = userData['nama']     ?? "";   // ← fix key
    role     = userData['role']     ?? "";
    email    = userData['email']    ?? "";
    username = userData['username'] ?? "";
    unit     = userData['unit']     ?? "";
    userId   = userData['id_user']  ?? 0;
    unitId   = userData['id_unit']  ?? 0;
  }

  // Fungsi untuk hapus data saat logout
  static void clearSession() {
    name = "";
    role = "";
    username = "";
    email = "";
    userId = 0;
    unit     = "";
    unitId = 0;
  }
}