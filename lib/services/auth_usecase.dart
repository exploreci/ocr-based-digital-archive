import '../models/user_model.dart';
import 'auth_repository.dart';
import 'user_session.dart'; // 📍 Import UserSession yang kita buat tadi

class AuthUsecase {
  final AuthRepository repository = AuthRepository();

  Future<UserModels> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception("Email dan password tidak boleh kosong");
    }

    // 1. Ambil data user dari repository (yang menembak API Python port 8000)
    final UserModels user = await repository.login(email, password);
    
    // 2. 📍 SIMPAN KE SESSION
    // Kita petakan data dari UserModels ke UserSession
    // Setelah memanggil AuthRepository.login

    // Buat Map yang kuncinya (key) SESUAI dengan UserSession di atas
    // Di dalam AuthUsecase.login
    Map<String, dynamic> dataMap = {
      'id_user': user.userId,
      'nama': user.name,      
      'email': user.email,
      'role': user.role,
      'unit': user.unit,      
      'id_role': user.idRole,
      'id_unit': user.idUnit,
      'username': user.username, 
      'id_unit_akses': user.idUnitAkses, // Tambahkan ini juga
    };

    UserSession.updateSession(dataMap);

    // 3. Kembalikan data user ke UI (Login Page)
    return user; 
  }
}