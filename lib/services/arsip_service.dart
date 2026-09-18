import 'package:dio/dio.dart';

class ArsipService {
  final Dio dio = Dio();
  final String apiUrl = "http://127.0.0.1:8000";

  Future<bool> simpanDataArsip(FormData formData) async {
    try {
      final response = await dio.post("$apiUrl/api/arsip", data: formData);
      return response.statusCode == 200;
    } catch (e) {
      print("Error simpan arsip: $e");
      return false;
    }
  }
}