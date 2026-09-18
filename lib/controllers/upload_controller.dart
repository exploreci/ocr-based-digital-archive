import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'dart:async';

class UploadController extends ChangeNotifier {
  final Dio _dio = Dio();
  final String apiUrl = "http://127.0.0.1:8000";

  bool isLoading = false;
  String processStatus = "";
  double progress = 0.0;

  // Controller untuk Form
  final TextEditingController nomorCtrl = TextEditingController();
  final TextEditingController perihalCtrl = TextEditingController();
  final TextEditingController tanggalCtrl = TextEditingController();
  final TextEditingController asalTujuanCtrl = TextEditingController();

  void _updateStatus(String status, [double prog = 0.0]) {
    processStatus = status;
    progress = prog;
    notifyListeners();
  }

  // STEP 1: Upload & Mulai OCR
  Future<String?> startOCRJob(Uint8List bytes, String fileName) async {
    try {
      isLoading = true;
      _updateStatus("Mengunggah dokumen...", 0.1);

      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(bytes, filename: fileName),
      });

      var response = await _dio.post("$apiUrl/api/ocr/upload", data: formData);
      return response.data['job_id'];
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // STEP 2: Polling Status (Sesuai lifecycle di arsip_routes.py)
  Future<Map<String, dynamic>?> waitForOCR(String jobId) async {
    while (true) {
      try {
        var response = await _dio.get("$apiUrl/api/ocr/status/$jobId");
        var data = response.data;

        if (data['status'] == 'done') {
          isLoading = false;
          notifyListeners();
          return data['result'];
        } else if (data['status'] == 'error') {
          throw Exception(data['message']);
        }

        // Update teks status berdasarkan progress backend
        _updateStatus("Sedang diproses: ${data['status']}...", 0.5);
        
        await Future.delayed(const Duration(seconds: 2)); // Tunggu 2 detik sebelum cek lagi
      } catch (e) {
        isLoading = false;
        notifyListeners();
        return null;
      }
    }
  }

  // STEP 3: Simpan Akhir ke Database
  Future<bool> simpanKeDatabase({
    required String jenisArsip,
    required int userId,
    required int unitId,
  }) async {
    try {
      _updateStatus("Menyimpan ke database...");
      
      // Sesuaikan dengan parameter yang dibutuhkan di arsip_routes.py
      Map<String, dynamic> payload = {
        "nomor_surat": nomorCtrl.text,
        "tanggal_surat": tanggalCtrl.text,
        "perihal": perihalCtrl.text,
        "asal_tujuan": asalTujuanCtrl.text, // Satu kolom untuk dua fungsi
        "jenis_surat": jenisArsip,
        "id_user_input": userId,
        "id_unit": unitId,
      };

      var response = await _dio.post("$apiUrl/api/save-arsip", data: payload);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}