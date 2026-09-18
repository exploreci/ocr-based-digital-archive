import '../models/user_model.dart'; // Pastikan nama file modelnya benar (UserModels atau UserModel)
import 'auth_api.dart';

class AuthRepository {
  final AuthApi api = AuthApi();

  Future<UserModels> login(String email, String password) async {
    // Panggil fungsi login yang baru (hanya 2 parameter)
    final data = await api.login(email, password); 

    
    
    // Pastikan mengirim SELURUH 'data' (bukan data['user'])
    return UserModels.fromJson(data);
  }
}