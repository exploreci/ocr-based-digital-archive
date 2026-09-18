class UserModels {
  final int userId; // Tambahkan ini untuk menyimpan ID user
  final String name;
  final String email;
  final String role;
  final String unit;
  final int idRole;  // Tambahkan ini untuk filter arsip nanti
  final int idUnit;  // Simpan ID-nya juga untuk query ke API
  final String? idUnitAkses; // Tambahkan ini untuk menyimpan ID unit akses
  final String username; // Tambahkan ini untuk menyimpan username

  UserModels({
    required this.userId, // Jangan lupa inisialisasi userId
    required this.name,
    required this.email,
    required this.role,
    required this.unit,
    required this.idRole,
    this.idUnitAkses, // 2. Tambahkan di constructor (opsional)
    required this.username,
    required this.idUnit,
  });

  factory UserModels.fromJson(Map<String, dynamic> json) {
  // 1. Ambil object 'user' dari response
  // Kita cek dulu, kalau json-nya sudah berisi data user langsung (bukan terbungkus key 'user')
  final userData = json.containsKey('user') ? json['user'] : json;

  return UserModels(
    // Gunakan .toString() lalu parse agar aman dari tipe data yang berubah-ubah
    userId: int.tryParse(userData['id_user']?.toString() ?? '0') ?? 0,
    name: userData['nama'] ?? userData['nama_lengkap'] ?? "User", 
    email: userData['email'] ?? "",
    username: userData['username'] ?? "",
    role: userData['role'] ?? "TIDAK_ADA_ROLE",
    
    // Ini bagian penting untuk id_role dan id_unit
    idRole: int.tryParse(userData['id_role']?.toString() ?? '0') ?? 0,
    idUnit: int.tryParse(userData['id_unit']?.toString() ?? '0') ?? 0,
    
    unit: userData['unit'] ?? "-",
    
    // id_unit_akses null? Tidak masalah, kita jadikan String kosong atau null aman
    idUnitAkses: userData['id_unit_akses']?.toString(), 
  );
}

  UserModels operator [](String other) {
    switch (other) {
      case 'userId':
        return UserModels(
          userId: userId,
          name: name,
          email: email,
          role: role,
          unit: unit,
          idRole: idRole,
          idUnitAkses: idUnitAkses,
          username: username,
          idUnit: idUnit,
        );
      // Tambahkan case lain sesuai kebutuhan
      default:
        throw ArgumentError('Invalid key: $other');
    }
  }
}