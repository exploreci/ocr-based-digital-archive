import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:convert';
import 'package:arsipdigital_web/main_layout.dart';
import '../services/user_session.dart';
import '../widgets/document_painter.dart';

Uint8List? originalFileBytes;
Uint8List? previewPdfBytes;

class UploadArsipPage extends StatefulWidget {
  final String jenisArsip;

  const UploadArsipPage({super.key, required this.jenisArsip});

  @override
  State<UploadArsipPage> createState() => _UploadArsipPageState();
}

class _UploadArsipPageState extends State<UploadArsipPage> {
  int currentStep = 0;
  double progress = 0.0;
  String fileName = "Belum ada file";
  Uint8List? fileBytes;

  // Progress bar sekarang real — diupdate dari response polling backend
  String processText = "Menyiapkan proses...";

  List<Offset> manualPoints = [];
  double imgWidth = 0;
  double imgHeight = 0;
  final GlobalKey _imageKey = GlobalKey();

  // ================================================================
  // DIO — FIX: Tidak ada duplikat timeout.
  // receiveTimeout per-request di-override saat polling (pendek),
  // sedangkan request upload awal diberi timeout cukup panjang.
  // ================================================================
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),    // upload file ke server
      receiveTimeout: const Duration(seconds: 30), // default, di-override per request
    ),
  );

  // ================================================================
  // MAP STATUS BACKEND → PROGRESS + LABEL
  // Sesuaikan dengan print() di pipeline.py:
  //   "Step 1: Preprocessing..."  → status: "preprocessing"
  //   "Step 2: Extracting text..." → status: "ocr"
  //   "Step 3: Generating PDF..." → status: "generating_pdf"
  //   done                        → status: "done"
  // ================================================================
  static const Map<String, Map<String, dynamic>> _statusMap = {
  "queued": {
    "progress": 0.05,
    "label": "Dokumen diterima, menunggu antrian...",
  },
  "parsing_coords": {
    "progress": 0.20,
    "label": "Memproses koordinat dokumen...",
  },
  "preprocessing": {
    "progress": 0.40,
    "label": "Mendeteksi & meningkatkan kualitas gambar...",
  },
  "ocr": {
    "progress": 0.65,
    "label": "Mengekstrak teks dengan OCR...",
  },
  "generating_pdf": {
    "progress": 0.82,
    "label": "Menyusun PDF hasil scan...",
  },
  "extracting_metadata": {
    "progress": 0.93,
    "label": "Menganalisis metadata surat...",
  },
  "done": {
    "progress": 1.0,
    "label": "Selesai!",
  },
};

  @override
  void initState() {
    super.initState();
    _tglSuratCtrl.addListener(_updateDynamicFileName);
    _asalTujuanCtrl.addListener(_updateDynamicFileName);
  }

  @override
  void dispose() {
    _tglSuratCtrl.dispose();
    _asalTujuanCtrl.dispose();
    _noSuratCtrl.dispose();
    _perihalCtrl.dispose();
    _rawOcrCtrl.dispose();
    super.dispose();
  }

  // ================================================================
  // STEP 1 — SUBMIT JOB (cepat, langsung dapat job_id)
  // Backend wajib response segera dengan { job_id: "..." }
  // tanpa nunggu proses selesai.
  // ================================================================
  Future<String?> _submitOcrJob(FormData formData) async {
    try {
      final response = await _dio.post(
        "$apiUrl/api/ocr",
        data: formData,
        options: Options(
          receiveTimeout: const Duration(seconds: 30), // server harus balas job_id < 30 detik
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        final jobId = response.data['job_id'] as String?;
        if (jobId == null || jobId.isEmpty) {
          throw Exception("Server tidak mengembalikan job_id.");
        }
        return jobId;
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } on DioException catch (e) {
      throw Exception("Gagal mengirim file: ${e.message}");
    }
  }

  // ================================================================
  // STEP 2 — POLLING STATUS (tiap 2 detik, sampai done/error)
  // GET /api/ocr/status/{job_id}
  // Response contoh:
  //   { "status": "preprocessing" }
  //   { "status": "ocr" }
  //   { "status": "done", "success": true, "pdf_base64": "...", "text": "...", "metadata": {...} }
  //   { "status": "error", "message": "..." }
  // ================================================================
  Future<Map<String, dynamic>> _pollJobStatus(String jobId) async {
    while (true) {
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) throw Exception("Widget sudah di-dispose.");

      try {
        final res = await _dio.get(
          "$apiUrl/api/ocr/status/$jobId",
          options: Options(
            receiveTimeout: const Duration(seconds: 10), // polling cepat
          ),
        );

        final data = res.data as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'queued';

        // Update progress bar dari status real backend
        if (_statusMap.containsKey(status)) {
          final info = _statusMap[status]!;
          if (mounted) {
            setState(() {
              progress = (info['progress'] as double);
              processText = info['label'] as String;
            });
          }
        }

        // Kalau sudah selesai atau error, berhenti polling dan return
        if (status == 'done' || status == 'error') {
          return data;
        }

      } on DioException catch (e) {
        // Kalau satu kali polling gagal (network fluke), jangan langsung throw.
        // Cukup log dan coba lagi di iterasi berikutnya.
        print("⚠ Polling error (akan retry): ${e.message}");
      }
    }
  }

  // ================================================================
  // MAIN FLOW — Submit → Polling → Selesai
  // ================================================================
  Future<void> prosesOCRSetelahWarp() async {
    if (!fileName.toLowerCase().endsWith('.pdf') && manualPoints.length < 4) {
      _showError("Silakan pilih 4 titik sudut terlebih dahulu.");
      return;
    }

    if (currentStep == 1) {
      final RenderBox? renderBox =
          _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        imgWidth = renderBox.size.width;
        imgHeight = renderBox.size.height;
      }
    }

    setState(() {
      currentStep = 2;
      progress = 0.05; // sedikit bergerak, tanda request sudah dikirim
      processText = "Mengirim dokumen ke server...";
    });

    List<List<double>> coords =
        manualPoints.map((p) => [p.dx, p.dy]).toList();

    final formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(originalFileBytes!, filename: fileName),
      "coords": fileName.toLowerCase().endsWith('.pdf')
          ? null
          : jsonEncode(coords),
      "width": imgWidth > 0 ? imgWidth : null,
      "height": imgHeight > 0 ? imgHeight : null,
      "jenis_surat": widget.jenisArsip,  // ← TAMBAH BARIS INI
    });

    try {
      // --- FASE 1: Kirim file, dapat job_id ---
      final jobId = await _submitOcrJob(formData);
      if (jobId == null) throw Exception("job_id kosong dari server.");

      if (mounted) {
        setState(() {
          progress = _statusMap['queued']!['progress'] as double;
          processText = _statusMap['queued']!['label'] as String;
        });
      }

      // --- FASE 2: Polling sampai server selesai ---
      final result = await _pollJobStatus(jobId);

      // --- FASE 3: Handle hasil ---
      if (result['status'] == 'error') {
        final errorType = result['error_type'] as String? ?? 'server_error';
        final message   = result['message']    as String? ?? 'Proses gagal di server.';
        if (mounted) {
          setState(() { currentStep = 0; progress = 0.0; });
          if (errorType == 'unprocessable') {
            _showAlertTidakBisaDiproses(message);
          } else {
            _showError("Terjadi kesalahan server: $message");
          }
        }
        return;
      }

      if (result['success'] != true) {
        throw Exception(result['message'] ?? "Server mengembalikan respons tidak valid.");
      }

      final String b64 = result['pdf_base64'] as String;
      final Uint8List hasilPreprocessing = base64Decode(b64);

      if (mounted) {
        setState(() {
          currentStep = 3;
          progress = 1.0;
          processText = "Selesai!";

          previewPdfBytes = hasilPreprocessing;
          fileBytes = hasilPreprocessing;  

          _rawOcrCtrl.text = result['text'] ?? "";
          final meta = result['metadata'] ?? {};
          _noSuratCtrl.text = meta['nomor_surat'] ?? "";
          _tglSuratCtrl.text = meta['tanggal_surat'] ?? "";
          _perihalCtrl.text = meta['perihal'] ?? "";
         _asalTujuanCtrl.text = widget.jenisArsip == 'masuk'
              ? (meta['asal_surat']   ?? "")
              : (meta['tujuan_surat'] ?? "");

          _updateDynamicFileName();
        });
      }
    } catch (e) {
      print("Detail Error: $e");
      if (mounted) {
        _showError("Terjadi kesalahan: ${e.toString().replaceAll('Exception: ', '')}");
        setState(() {
          currentStep = 0;
          progress = 0.0;
        });
      }
    }
  }

  // ================================================================
  // FORM CONTROLLERS & CONSTANTS (tidak berubah)
  // ================================================================
  final TextEditingController _noSuratCtrl = TextEditingController();
  final TextEditingController _tglSuratCtrl = TextEditingController();
  final TextEditingController _perihalCtrl = TextEditingController();
  final TextEditingController _asalTujuanCtrl = TextEditingController();
  final TextEditingController _rawOcrCtrl = TextEditingController();

  final String apiUrl = "http://127.0.0.1:8000";
  final Color blueHeader = const Color(0xFF194CB6);

  
  Future<void> pilihDanProsesFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    withData: true,
  );

  if (result != null) {
    final bytes = result.files.first.bytes;
    final name  = result.files.first.name;
    final ext   = name.split('.').last.toLowerCase();

    // ── VALIDASI TIPE ─────────────────────────────────────
    const allowedExt = {'pdf', 'jpg', 'jpeg', 'png'};
    if (!allowedExt.contains(ext)) {
      _showError("Format tidak didukung. Gunakan: PDF, JPG, JPEG, PNG.");
      return;
    }

    // ── VALIDASI UKURAN (maks 3 MB) ───────────────────────
    const int maxBytes = 3 * 1024 * 1024;
    if ((bytes?.length ?? 0) > maxBytes) {
      _showError("Ukuran file terlalu besar. Maksimal 3MB.");
      return;
    }

    // ── VALIDASI BYTES TIDAK KOSONG ───────────────────────
    if (bytes == null || bytes.isEmpty) {
      _showAlertTidakBisaDiproses(
          "File tidak dapat dibaca. File mungkin kosong atau corrupt.");
      return;
    }

    // ── VALIDASI GAMBAR BISA DI-DECODE (khusus non-PDF) ───
    if (ext != 'pdf') {
      final decoded = await decodeImageFromList(bytes);
      if (decoded == null) {
        _showAlertTidakBisaDiproses(
            "Format gambar tidak valid atau file corrupt. Silakan coba file lain.");
        return;
      }
    }

    // ── SEMUA VALIDASI LULUS → SET STATE ──────────────────
    setState(() {
      originalFileBytes = bytes;
      fileBytes         = originalFileBytes;
      fileName          = name;
      manualPoints.clear();

      if (fileName.toLowerCase().endsWith('.pdf')) {
        currentStep = 2;
        prosesOCRSetelahWarp();
      } else {
        currentStep = 1;
      }
    });
  } // ← tutup if (result != null)
} // ← tutup pilihDanProsesFile()

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }


 void _showAlertTidakBisaDiproses(String detail) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  // ── Ukuran & posisi ──────────────────────────────────────
  const double notifWidth  = 320;  // ← lebar notif, perkecil/perbesar di sini
  const double notifTop    = 30;   // ← jarak dari atas
  const double notifRight  = 24;   // ← jarak dari kanan

  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 350),
  );
  final fadeAnim = CurvedAnimation(parent: controller, curve: Curves.easeOut);

  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top:   notifTop,
      right: notifRight,
      width: notifWidth,
      child: FadeTransition(
        opacity: fadeAnim,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // ← padding dalam
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.broken_image_outlined,
                    color: Colors.white, size: 22), // ← ukuran icon
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dokumen Tidak Dapat Diproses',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13, // ← ukuran teks judul
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12), // ← ukuran teks detail
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Silakan upload dokumen lain.',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11, // ← ukuran teks bawah
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  controller.forward(); // ← fade in

  Future.delayed(const Duration(seconds: 7), () async { // ← durasi tampil
    await controller.reverse();  // ← fade out smooth
    if (entry.mounted) entry.remove();
    controller.dispose();
  });
}


  void _showAlertDuplikat({
  required String nomor,
  required String tanggal,
  required String perihal,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: const [
        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
        SizedBox(width: 8),
        Text('Nomor Surat Sudah Ada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Surat ini sudah tercatat di arsip:'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nomor   : $nomor'),
                const SizedBox(height: 4),
                Text('Tanggal : $tanggal'),
                const SizedBox(height: 4),
                Text('Perihal : $perihal'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.block, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Data tidak dapat dimasukkan ulang.',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Oke, Mengerti',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  void _showPdfPreview(BuildContext context) {
    if (fileBytes == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Preview Dokumen",
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            width: MediaQuery.of(context).size.width * 0.7,
            child: SfPdfViewer.memory(
              fileBytes!,
              key: ValueKey(fileName),
            ),
          ),
        );
      },
    );
  }

  void _updateDynamicFileName() {
    if (currentStep != 3) return;

    String safeAsalTujuan = _asalTujuanCtrl.text
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();
    if (safeAsalTujuan.isEmpty) safeAsalTujuan = "instansi";

    String prefix = widget.jenisArsip == 'masuk' ? 'm' : 'k';

    DateTime tglObj = DateTime.now();
    try {
      if (_tglSuratCtrl.text.isNotEmpty) {
        tglObj = DateTime.parse(_tglSuratCtrl.text);
      }
    } catch (e) {
      // fallback DateTime.now()
    }

    String formattedDate =
        "${tglObj.year}${tglObj.month.toString().padLeft(2, '0')}${tglObj.day.toString().padLeft(2, '0')}";

    setState(() {
      fileName = "${formattedDate}_${safeAsalTujuan}_$prefix[X].pdf";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Sistem Informasi Penyimpanan Arsip Digital",
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderText(),
              const SizedBox(height: 30),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _buildCurrentStepView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    return Column(
      children: [
       
        Text(
          "Upload Surat ${widget.jenisArsip}",
          style: GoogleFonts.nunito(
              fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildCurrentStepView() {
    if (currentStep == 0) return _buildInitialUploadView();
    if (currentStep == 1) return _buildManualCornerView();
    if (currentStep == 2) return _buildProcessingView();
    return _buildFormMetadataView();
  }

  Widget _buildInitialUploadView() {
    return Container(
      key: const ValueKey(0),
      width: 750,
      padding: const EdgeInsets.all(40),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload_outlined,
              size: 70, color: Colors.grey),
          const SizedBox(height: 20),
          Text("Pilih File Surat",
              style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: pilihDanProsesFile,
            icon: const Icon(Icons.search, color: Colors.white),
            label: const Text("Pilih Dokumen",
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: blueHeader,
                padding: const EdgeInsets.symmetric(
                    horizontal: 30, vertical: 15)),
          ),
          
          // --- TOMBOL TAMBAHAN DISINI ---
          // Masukkan ke dalam children Column di _buildInitialUploadView
if (widget.jenisArsip == 'keluar') ...[
  const SizedBox(height: 15),
  OutlinedButton.icon(
    onPressed: () {
      // Navigasi ke halaman editor surat keluar
      Navigator.pushNamed(context, '/editor-surat-keluar'); 
      // Atau pakai service kamu:
      // NavigationService.navigateTo('/editor-surat-keluar');
      
      print("Tombol khusus surat keluar ditekan");
    },
    icon: const Icon(Icons.edit_document, color: Colors.orange),
    label: Text(
      "Buat Surat Keluar Baru",
      style: GoogleFonts.nunito(
        color: Colors.orange, 
        fontWeight: FontWeight.bold,
      ),
    ),
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Colors.orange),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
],
          // ------------------------------

          const SizedBox(height: 15),
          Text("Format yang didukung: PDF, JPG, JPEG, PNG (Maks 2MB)",
              style: GoogleFonts.nunito(
                  color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }


  Widget _buildProcessingView() {
    return Container(
      key: const ValueKey(1),
      width: 750,
      padding: const EdgeInsets.all(40),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 25),
          Text(
            "Sistem OCR sedang mengekstrak dokumen...",
            style: GoogleFonts.nunito(
                fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          // Progress bar sekarang ter-update dari status polling backend
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: Colors.grey.shade200,
              color: blueHeader,
            ),
          ),
          const SizedBox(height: 10),
          // Label sekarang mencerminkan step real backend
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              processText,
              key: ValueKey(processText),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "${(progress * 100).toStringAsFixed(0)}% Diproses",
            style: TextStyle(
                color: blueHeader, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }



  Widget _buildFormMetadataView() {
    return Container(
      key: const ValueKey(2),
      width: 1000,
      padding: const EdgeInsets.all(30),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description,
                          size: 40, color: Colors.blueAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fileName,
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (fileName
                              .toLowerCase()
                              .endsWith('.pdf') &&
                          fileBytes != null)
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye,
                              color: Colors.blueAccent),
                          tooltip: "Lihat PDF",
                          onPressed: () =>
                              _showPdfPreview(context),
                        ),
                    ],
                  ),
                  const Divider(height: 30),
                  Text(
                    "Hasil Pemindaian Mentah (OCR):",
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rawOcrCtrl,
                    maxLines: 15,
                    readOnly: true,
                    style: GoogleFonts.firaCode(
                        fontSize: 12, color: Colors.black87),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Info: Anda dapat mengedit keterangan surat di sebelah kanan jika ada karakter yang kurang tepat.",
                    style: GoogleFonts.nunito(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Keterangan Surat",
                    style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildField(
                    widget.jenisArsip == 'masuk'
                        ? "Asal Surat"
                        : "Tujuan Surat",
                    _asalTujuanCtrl),
                _buildField("Nomor Surat", _noSuratCtrl),
                _buildField(
                    "Tanggal Surat (YYYY-MM-DD)", _tglSuratCtrl),
                _buildField("Perihal", _perihalCtrl),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => currentStep = 0),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 20)),
                        child: const Text("Batal"),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveDataToDatabase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueHeader,
                          padding: const EdgeInsets.symmetric(
                              vertical: 20),
                          elevation: 2,
                        ),
                        child: const Text("Simpan ke Arsip",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 15, vertical: 15),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderSide:
                BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _saveDataToDatabase() async {
    Uint8List? dataYangDisimpan =
        previewPdfBytes ?? originalFileBytes;

    if (dataYangDisimpan == null) {
      _showError("File tidak ditemukan. Silakan upload ulang.");
      return;
    }

    if (_asalTujuanCtrl.text.isEmpty ||
        _noSuratCtrl.text.isEmpty) {
      _showError(
          "Harap pastikan Nomor Surat dan Asal/Tujuan sudah terisi.");
      return;
    }

    try {
      _showLoadingDialog();

      MultipartFile fileSimpan = MultipartFile.fromBytes(
        dataYangDisimpan,
        filename:
            "arsip_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );

      FormData formData = FormData.fromMap({
        "file": fileSimpan,
        "nomor_surat": _noSuratCtrl.text.trim(),
        "tanggal_surat": _tglSuratCtrl.text.trim(),
        "perihal": _perihalCtrl.text.trim(),
        "asal_tujuan": _asalTujuanCtrl.text.trim(),
        "jenis_surat": widget.jenisArsip,
        "id_user_input":
            int.tryParse(UserSession.userId.toString()) ?? 1,
        "id_unit":
            int.tryParse(UserSession.unitId.toString()) ?? 1,
      });

     // SESUDAH — ada cek duplikat
      var response = await _dio.post(
        "$apiUrl/api/simpan-arsip",
        data: formData,
      );

      if (mounted && Navigator.canPop(context))
        Navigator.pop(context); // tutup loading dialog dulu

      // ── Cek duplikat SEBELUM cek success ──
      if (response.data['duplikat'] == true) {
        final dataLama = response.data['data_lama'];
        _showAlertDuplikat(
          nomor  : dataLama['nomor_surat']   ?? '-',
          tanggal: dataLama['tanggal_surat'] ?? '-',
          perihal: dataLama['perihal']       ?? '-',
        );
        return; // ← stop di sini, jangan lanjut
      }

if (response.statusCode == 200 && response.data['success'] == true) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Arsip Berhasil Disimpan!"),
      backgroundColor: Colors.green,
    ),
  );
  await Future.delayed(const Duration(milliseconds: 800));
  if (mounted) Navigator.of(context).pop();
} else {
  _showError(response.data['message'] ?? 'Gagal menyimpan.');
}
    } catch (e) {
      if (mounted && Navigator.canPop(context))
        Navigator.pop(context);

      print("Error Simpan: $e");
      _showError(
          "Gagal menyimpan. Pastikan semua field valid.");
    }
  }

  Widget _buildManualCornerView() {
    return Container(
      key: const ValueKey(1.5),
      width: 800,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text("Sesuaikan Sudut Dokumen",
              style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
              "Klik pada 4 sudut dokumen (urutan: Kiri Atas, Kanan Atas, Kanan Bawah, Kiri Bawah)",
              style: GoogleFonts.nunito(
                  color: Colors.grey)),
          const SizedBox(height: 20),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    if (manualPoints.length < 4) {
                      setState(() {
                        manualPoints
                            .add(details.localPosition);
                      });
                    }
                  },
                  child: Stack(
                    children: [
                      Image.memory(
                        originalFileBytes!,
                        key: _imageKey,
                        fit: BoxFit.contain,
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: DocumentCornerPainter(
                              points: manualPoints),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () =>
                    setState(() => manualPoints.clear()),
                child: const Text("Reset Titik"),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: manualPoints.length == 4
                    ? prosesOCRSetelahWarp
                    : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: blueHeader),
                child: const Text("Proses Dokumen",
                    style:
                        TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator()),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10))
      ],
      border: Border.all(color: Colors.grey.shade100),
    );
  }
}