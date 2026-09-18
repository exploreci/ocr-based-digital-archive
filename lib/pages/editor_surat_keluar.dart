import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../services/user_session.dart';

import 'surat_keluar_preview.dart';


// ══════════════════════════════════════════════════════════════════════════════
// BLOCK MODELS — unit konten surat (paragraf teks ATAU tabel)
// Setiap blok dirender secara berurutan di preview & PDF
// ══════════════════════════════════════════════════════════════════════════════

abstract class SuratBlock {}

/// Blok berisi paragraf teks biasa
class _TextBlock extends SuratBlock {
  final TextEditingController ctrl;
  _TextBlock({String initialText = ''})
      : ctrl = TextEditingController(text: initialText);
}

/// Blok berisi tabel dengan sel yang bisa diedit
/// Baris pertama (index 0) diperlakukan sebagai baris header (bold)
class _TableBlock extends SuratBlock {
  int rows;
  int cols;
  List<List<TextEditingController>> cells;

  /// Lebar setiap kolom dalam satuan piksel editor (min 44, max 320).
  /// Dipakai di editor drag-resize, preview, dan PDF secara proporsional.
  List<double> colWidths;

  _TableBlock({required this.rows, required this.cols})
    : cells = List.generate(
          rows,
          (_) => List.generate(
            cols,
            (_) => TextEditingController(),
            growable: true,   // ← inner list WAJIB growable
          ),
          growable: true,     // ← outer list juga growable
        ),
      colWidths = List.filled(cols, 80.0, growable: true); // ← ini juga
      
  /// Data mentah: List<List<String>> — cocok untuk preview & PDF
  List<List<String>> get data =>
      cells.map((row) => row.map((c) => c.text).toList()).toList();

  /// Total lebar semua kolom (dipakai untuk perhitungan skala)
  double get totalWidth => colWidths.fold(0, (s, w) => s + w);

  /// Tambah satu baris baru di bawah (daftarkan listener agar preview ikut update)
  void addRow(VoidCallback listener) {
  final newRow = List.generate(cols, (_) {
    final c = TextEditingController();
    c.addListener(listener);
    return c;
  }, growable: true);  
  cells.add(newRow);
  rows++;
}

  /// Hapus baris pada indeks tertentu (minimal 1 baris tetap ada)
  void removeRow(int i) {
    if (rows <= 1) return;
    for (final c in cells[i]) c.dispose();
    cells.removeAt(i);
    rows--;
  }

  /// Tambah satu kolom baru di kanan dengan lebar default 80px
  void addCol(VoidCallback listener) {
    for (final row in cells) {
      final c = TextEditingController();
      c.addListener(listener);
      row.add(c);
    }
    colWidths.add(80.0);
    cols++;
  }

  /// Hapus kolom pada indeks tertentu (minimal 1 kolom tetap ada)
  void removeCol(int j) {
    if (cols <= 1) return;
    for (final row in cells) {
      row[j].dispose();
      row.removeAt(j);
    }
    colWidths.removeAt(j);
    cols--;
  }

  void disposeAll() {
    for (final row in cells) {
      for (final c in row) c.dispose();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HALAMAN EDITOR SURAT KELUAR
// Layout: Form (kiri, lebar 380) + Live Preview A4 (kanan)
// ══════════════════════════════════════════════════════════════════════════════

class EditorSuratKeluarPage extends StatefulWidget {
  const EditorSuratKeluarPage({super.key});

  @override
  State<EditorSuratKeluarPage> createState() => _EditorSuratKeluarPageState();
}

class _EditorSuratKeluarPageState extends State<EditorSuratKeluarPage> {
  // ── Controllers header surat ──────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kotaCtrl;
  late final TextEditingController _nomorCtrl;
  late final TextEditingController _lampiranCtrl;
  late final TextEditingController _perihalCtrl;
  late final TextEditingController _kepadaDiCtrl;
  late final TextEditingController _namaTtdCtrl;
  late final TextEditingController _jabatanTtdCtrl;
  late final TextEditingController _nipTtdCtrl;

  // ── Blok-blok konten isi surat ────────────────────────────────────────────
  final List<SuratBlock> _blocks = [];

  // ── Kepada Yth. — daftar dinamis ─────────────────────────────────────────
  final List<TextEditingController> _penerimaCtrls = [];

  // ── Tembusan — opsional + daftar dinamis ─────────────────────────────────
  bool _adaTembusan = false;
  final List<TextEditingController> _tembusanCtrls = [];

  DateTime _tanggalSurat = DateTime.now();
  bool _isCetak = false;
  bool _isSimpan = false;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final String _apiUrl = 'http://127.0.0.1:8000';

  // ── Getter helpers ────────────────────────────────────────────────────────

  List<String> get _penerima =>
      _penerimaCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

  List<String> get _tembusan =>
      _tembusanCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

  String get _tanggalFormatted {
    const bln = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${_tanggalSurat.day} ${bln[_tanggalSurat.month]} ${_tanggalSurat.year}';
  }

  String get _tanggalLengkap => '${_kotaCtrl.text.trim()}, $_tanggalFormatted';

  String get _tanggalDb =>
      '${_tanggalSurat.year}-'
      '${_tanggalSurat.month.toString().padLeft(2, '0')}-'
      '${_tanggalSurat.day.toString().padLeft(2, '0')}';

  /// Konversi blok menjadi List<dynamic>:
  ///   - String                  → _TextBlock
  ///   - Map{'data','colWidths'} → _TableBlock  (colWidths = List<double> px editor)
  List<dynamic> get _blocksData => _blocks.map((b) {
        if (b is _TextBlock) return b.ctrl.text;
        if (b is _TableBlock) return {
          'data'     : b.data,
          'colWidths': List<double>.from(b.colWidths),
        };
        return '';
      }).toList();

  // ── Init & Dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _kotaCtrl       = TextEditingController(text: 'Prabumulih');
    _nomorCtrl      = TextEditingController();
    _lampiranCtrl   = TextEditingController(text: '-');
    _perihalCtrl    = TextEditingController();
    _kepadaDiCtrl   = TextEditingController(text: 'Universitas Prabumulih');
    _namaTtdCtrl    = TextEditingController(text: 'Dr. Yuniar Pratiwi, S.Si., M.Si');
    _jabatanTtdCtrl = TextEditingController(text: 'Rektor');
    _nipTtdCtrl     = TextEditingController();

    for (final c in [
      _kotaCtrl, _nomorCtrl, _lampiranCtrl, _perihalCtrl,
      _kepadaDiCtrl, _namaTtdCtrl, _jabatanTtdCtrl, _nipTtdCtrl,
    ]) {
      c.addListener(_rebuild);
    }

    // Satu blok teks kosong sebagai default
    _tambahTextBlock();

    _tambahPenerima();
    _tambahTembusan();
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    for (final c in [
      _kotaCtrl, _nomorCtrl, _lampiranCtrl, _perihalCtrl,
      _kepadaDiCtrl, _namaTtdCtrl, _jabatanTtdCtrl, _nipTtdCtrl,
    ]) {
      c.dispose();
    }
    for (final c in _penerimaCtrls) c.dispose();
    for (final c in _tembusanCtrls) c.dispose();
    for (final b in _blocks) {
      if (b is _TextBlock) b.ctrl.dispose();
      if (b is _TableBlock) b.disposeAll();
    }
    super.dispose();
  }

  // ── Manajemen blok konten ─────────────────────────────────────────────────

  void _tambahTextBlock() {
    final block = _TextBlock();
    block.ctrl.addListener(_rebuild);
    setState(() => _blocks.add(block));
  }

  void _tambahTabelBlock(int rows, int cols) {
    final block = _TableBlock(rows: rows, cols: cols);
    for (final row in block.cells) {
      for (final c in row) c.addListener(_rebuild);
    }
    setState(() => _blocks.add(block));
  }

  void _hapusBlock(int i) {
    final b = _blocks[i];
    if (b is _TextBlock) b.ctrl.dispose();
    if (b is _TableBlock) b.disposeAll();
    setState(() => _blocks.removeAt(i));
  }

  void _naikanBlock(int i) {
    if (i <= 0) return;
    setState(() {
      final b = _blocks.removeAt(i);
      _blocks.insert(i - 1, b);
    });
  }

  void _turunkanBlock(int i) {
    if (i >= _blocks.length - 1) return;
    setState(() {
      final b = _blocks.removeAt(i);
      _blocks.insert(i + 1, b);
    });
  }

  // ── Dialog tambah tabel ───────────────────────────────────────────────────

  Future<void> _showDialogTambahTabel() async {
    int rows = 3, cols = 3;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.table_chart_outlined, color: Color(0xFF194CB6)),
            const SizedBox(width: 8),
            Text('Konfigurasi Tabel',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tentukan ukuran tabel yang akan ditambahkan:',
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                _stepperRow(
                  'Jumlah Baris',
                  rows, 1, 30,
                  onDec: () => setS(() { if (rows > 1) rows--; }),
                  onInc: () => setS(() { if (rows < 30) rows++; }),
                ),
                const SizedBox(height: 14),
                _stepperRow(
                  'Jumlah Kolom',
                  cols, 1, 10,
                  onDec: () => setS(() { if (cols > 1) cols--; }),
                  onInc: () => setS(() { if (cols < 10) cols++; }),
                ),
                const SizedBox(height: 18),
                // Mini-preview grid
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD0D9F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preview:',
                          style: GoogleFonts.nunito(
                              fontSize: 10, color: Colors.grey.shade500)),
                      const SizedBox(height: 6),
                      Table(
                        border: TableBorder.all(
                            color: const Color(0xFF194CB6), width: 0.5),
                        children: List.generate(
                          rows.clamp(1, 5),
                          (r) => TableRow(
                            decoration: BoxDecoration(
                               color: r == 0 ? const Color.fromARGB(255, 255, 255, 255) : Colors.white,
                            ),
                            children: List.generate(
                              cols.clamp(1, 6),
                              (_) => Container(
                                height: 16,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (rows > 5 || cols > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '* Preview ditampilkan sebagian',
                            style: GoogleFonts.nunito(
                                fontSize: 9, color: Colors.grey.shade400),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCC02)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Color(0xFFB8860B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Baris pertama akan dijadikan header tabel (bold).',
                          style: GoogleFonts.nunito(
                              fontSize: 10.5, color: const Color(0xFF7A5C00)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: GoogleFonts.nunito()),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: Text(
                'Tambah Tabel ($rows×$cols)',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF194CB6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _tambahTabelBlock(rows, cols);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperRow(
    String label,
    int value,
    int min,
    int max, {
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: value > min ? onDec : null,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(7)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Icon(Icons.remove,
                      size: 16,
                      color: value > min
                          ? const Color(0xFF194CB6)
                          : Colors.grey.shade300),
                ),
              ),
              SizedBox(
                width: 44,
                child: Center(
                  child: Text('$value',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              InkWell(
                onTap: value < max ? onInc : null,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(7)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Icon(Icons.add,
                      size: 16,
                      color: value < max
                          ? const Color(0xFF194CB6)
                          : Colors.grey.shade300),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Manajemen penerima ────────────────────────────────────────────────────

  void _tambahPenerima() {
    final c = TextEditingController();
    c.addListener(_rebuild);
    setState(() => _penerimaCtrls.add(c));
  }

  void _hapusPenerima(int i) {
    if (_penerimaCtrls.length <= 1) return;
    _penerimaCtrls[i].dispose();
    setState(() => _penerimaCtrls.removeAt(i));
  }

  // ── Manajemen tembusan ────────────────────────────────────────────────────

  void _tambahTembusan() {
    final c = TextEditingController();
    c.addListener(_rebuild);
    setState(() => _tembusanCtrls.add(c));
  }

  void _hapusTembusan(int i) {
    if (_tembusanCtrls.length <= 1) return;
    _tembusanCtrls[i].dispose();
    setState(() => _tembusanCtrls.removeAt(i));
  }

  // ── Pilih tanggal ─────────────────────────────────────────────────────────

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalSurat,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF194CB6),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tanggalSurat = picked);
  }

  // ── Cetak PDF ─────────────────────────────────────────────────────────────

  Future<void> _cetakPdf() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_penerima.isEmpty) {
      _snack('Harap isi minimal 1 penerima surat.', isError: true);
      return;
    }
    setState(() => _isCetak = true);
    try {
      await SuratKeluarPdf.cetak(
        kota            : _kotaCtrl.text.trim(),
        tanggalFormatted: _tanggalFormatted,
        nomor           : _nomorCtrl.text.trim(),
        lampiran        : _lampiranCtrl.text.trim(),
        perihal         : _perihalCtrl.text.trim(),
        penerima        : _penerima,
        kepadaDi        : _kepadaDiCtrl.text.trim(),
        blocks          : _blocksData,
        namaTtd         : _namaTtdCtrl.text.trim(),
        jabatanTtd      : _jabatanTtdCtrl.text.trim(),
        nipTtd          : _nipTtdCtrl.text.trim(),
        tembusan        : _adaTembusan ? _tembusan : [],
      );
    } catch (e) {
      if (mounted) _snack('Gagal membuat PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCetak = false);
    }
  }

  // ── Simpan metadata ke database ───────────────────────────────────────────

  Future<void> _simpanKeArsip() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_penerima.isEmpty) {
      _snack('Harap isi minimal 1 penerima surat.', isError: true);
      return;
    }
    setState(() => _isSimpan = true);
    try {
      final body = {
        'nomor_surat'  : _nomorCtrl.text.trim(),
        'tanggal_surat': _tanggalDb,
        'perihal'      : _perihalCtrl.text.trim(),
        'tujuan_surat' : _penerima.join(' | '),
        'id_user_input': int.tryParse(UserSession.userId.toString()) ?? 1,
        'id_unit'      : int.tryParse(UserSession.unitId.toString()) ?? 1,
      };
      final res = await _dio.post(
        '$_apiUrl/api/simpan-surat-keluar',
        data: body,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        if (mounted) {
          _snack(
            'Metadata berhasil disimpan! '
            'Upload PDF setelah surat ditandatangani via halaman Surat Keluar.',
            isError: false,
            duration: const Duration(seconds: 5),
          );
        }
      } else {
        throw Exception(res.data['message'] ?? 'Gagal menyimpan.');
      }
    } on DioException catch (e) {
      if (mounted) {
        _snack(e.response?.data?['message'] ?? e.message ?? 'Koneksi gagal.',
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSimpan = false);
    }
  }

  void _snack(String msg, {bool isError = false, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green.shade700,
      duration: duration ?? const Duration(seconds: 3),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF194CB6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Editor Surat Keluar',
            style: GoogleFonts.nunito(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              icon: _isSimpan
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
              label: Text(
                _isSimpan ? 'Menyimpan...' : 'Simpan ke Arsip',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSimpan ? null : _simpanKeArsip,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: _isCetak
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Color(0xFF194CB6), strokeWidth: 2))
                  : const Icon(Icons.print_outlined,
                      size: 18, color: Color(0xFF194CB6)),
              label: Text(
                _isCetak ? 'Memproses...' : 'Cetak Surat',
                style: GoogleFonts.nunito(
                    color: const Color(0xFF194CB6),
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isCetak ? null : _cetakPdf,
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ════════════════════════════════════════════
          // PANEL KIRI — Form Input
          // ════════════════════════════════════════════
          Container(
            width: 380,
            color: Colors.white,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Identitas Surat ──────────────────
                  _sectionLabel('📍 Identitas Surat'),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Kota',
                    controller: _kotaCtrl,
                    hint: 'Prabumulih',
                    icon: Icons.location_city_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildDateField(),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Nomor Surat',
                    controller: _nomorCtrl,
                    hint: '097/UNPRA/IV/2026',
                    icon: Icons.tag_outlined,
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Lampiran',
                    controller: _lampiranCtrl,
                    hint: '- atau 1 Berkas',
                    icon: Icons.attach_file_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Perihal',
                    controller: _perihalCtrl,
                    hint: 'Undangan Rapat',
                    icon: Icons.subject_outlined,
                    maxLines: 2,
                    required: true,
                  ),

                  // ── Kepada Yth. ──────────────────────
                  const SizedBox(height: 20),
                  _sectionLabel('👥 Kepada Yth.'),
                  const SizedBox(height: 12),
                  ...List.generate(_penerimaCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildField(
                              label: _penerimaCtrls.length == 1
                                  ? 'Penerima'
                                  : 'Penerima ${i + 1}',
                              controller: _penerimaCtrls[i],
                              hint: 'Sdr. Dekan Fakultas',
                              icon: Icons.person_outline,
                              required: i == 0,
                            ),
                          ),
                          if (_penerimaCtrls.length > 1) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _hapusPenerima(i),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red, size: 20),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: _tambahPenerima,
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Tambah Penerima'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF194CB6)),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    label: 'Di -',
                    controller: _kepadaDiCtrl,
                    hint: 'Universitas Prabumulih',
                    icon: Icons.place_outlined,
                  ),

                  // ── Konten Surat (Blok) ──────────────
                  const SizedBox(height: 20),
                  _sectionLabel('📝 Konten Surat'),
                  const SizedBox(height: 4),
                  // Info hint
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF8),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 13, color: Color(0xFF194CB6)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Surat terdiri dari blok-blok. Tambah paragraf teks atau tabel, '
                            'lalu atur urutannya dengan tombol ↑↓.',
                            style: GoogleFonts.nunito(
                                fontSize: 10.5,
                                color: const Color(0xFF194CB6)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Render semua blok
                  ..._blocks.asMap().entries.map(
                        (e) => _buildBlockWidget(e.key),
                      ),

                  // Tombol tambah blok
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.text_fields_outlined, size: 15),
                          label: Text('+ Paragraf Teks',
                              style: GoogleFonts.nunito(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: _tambahTextBlock,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF194CB6),
                            side: const BorderSide(
                                color: Color(0xFF194CB6), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.table_chart_outlined,
                              size: 15),
                          label: Text('+ Tabel',
                              style: GoogleFonts.nunito(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: _showDialogTambahTabel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF194CB6),
                            side: const BorderSide(
                                color: Color(0xFF194CB6), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Tanda Tangan ─────────────────────
                  const SizedBox(height: 20),
                  _sectionLabel('✍️ Tanda Tangan'),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Jabatan Penandatangan',
                    controller: _jabatanTtdCtrl,
                    hint: 'Rektor',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Nama Penandatangan',
                    controller: _namaTtdCtrl,
                    hint: 'Dr. Yuniar Pratiwi, S.Si., M.Si',
                    icon: Icons.person_pin_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'NIP (opsional)',
                    controller: _nipTtdCtrl,
                    hint: '19XXXXXXXXXXXXXXXXX',
                    icon: Icons.numbers_outlined,
                  ),

                  // ── Tembusan ─────────────────────────
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _sectionLabel('📎 Tembusan')),
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: _adaTembusan,
                          onChanged: (v) => setState(() => _adaTembusan = v),
                          activeColor: const Color(0xFF194CB6),
                        ),
                      ),
                      Text(
                        _adaTembusan ? 'Ada' : 'Tidak Ada',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: _adaTembusan
                                ? const Color(0xFF194CB6)
                                : Colors.grey),
                      ),
                    ],
                  ),
                  if (_adaTembusan) ...[
                    const SizedBox(height: 12),
                    ...List.generate(_tembusanCtrls.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _buildField(
                                label: 'Tembusan ${i + 1}',
                                controller: _tembusanCtrls[i],
                                hint: 'Ketua Yayasan Pendidikan Prabumulih',
                                icon: Icons.forward_to_inbox_outlined,
                              ),
                            ),
                            if (_tembusanCtrls.length > 1) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _hapusTembusan(i),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red, size: 20),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _tambahTembusan,
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Tambah Tembusan'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF194CB6)),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Garis pemisah
          Container(width: 1, color: const Color(0xFFE0E7F3)),

          // ════════════════════════════════════════════
          // PANEL KANAN — Live Preview A4
          // ════════════════════════════════════════════
          Expanded(
            child: Container(
              color: const Color(0xFFF0F4FB),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    color: const Color(0xFFE8EDF8),
                    child: Row(children: [
                      const Icon(Icons.preview_outlined,
                          color: Color(0xFF194CB6), size: 18),
                      const SizedBox(width: 8),
                      Text('Preview Surat A4 (Real-time)',
                          style: GoogleFonts.nunito(
                              color: const Color(0xFF194CB6),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF194CB6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('A4',
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: PreviewSurat(
                          tanggalLengkap: _tanggalLengkap,
                          nomor          : _nomorCtrl.text,
                          lampiran       : _lampiranCtrl.text,
                          perihal        : _perihalCtrl.text,
                          penerima       : _penerima.isEmpty
                              ? const ['...']
                              : _penerima,
                          kepadaDi       : _kepadaDiCtrl.text,
                          blocks         : _blocksData,
                          namaTtd        : _namaTtdCtrl.text,
                          jabatanTtd     : _jabatanTtdCtrl.text,
                          nipTtd         : _nipTtdCtrl.text,
                          tembusan       : _adaTembusan ? _tembusan : [],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET BLOK — Editor per blok di panel kiri
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBlockWidget(int i) {
    final block = _blocks[i];
    final isFirst = i == 0;
    final isLast = i == _blocks.length - 1;
    final isTabel = block is _TableBlock;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color(0xFF194CB6).withOpacity(0.22), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header blok ──────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isTabel
                  ? const Color(0xFFDCEAFF)
                  : const Color(0xFFE8EDF8),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Icon(
                  isTabel
                      ? Icons.table_chart_outlined
                      : Icons.text_fields_outlined,
                  size: 14,
                  color: const Color(0xFF194CB6),
                ),
                const SizedBox(width: 6),
                Text(
                    isTabel
                        ? 'Tabel  ${block.rows} baris × ${block.cols} kolom'
                        : 'Paragraf Teks',
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF194CB6)),
                  ),
                const Spacer(),
                // Tombol atas
                if (!isFirst)
                  _miniIconBtn(Icons.keyboard_arrow_up, () => _naikanBlock(i)),
                // Tombol bawah
                if (!isLast)
                  _miniIconBtn(
                      Icons.keyboard_arrow_down, () => _turunkanBlock(i)),
                // Hapus blok
                if (_blocks.length > 1)
                  _miniIconBtn(Icons.close, () => _hapusBlock(i),
                      color: Colors.red.shade300),
              ],
            ),
          ),
          // ── Konten blok ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(10),
            child: block is _TextBlock
                ? _buildTextBlockContent(block)
                : _buildTabelBlockContent(block as _TableBlock),
          ),
        ],
      ),
    );
  }

  Widget _miniIconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 16, color: color ?? const Color(0xFF194CB6)),
      ),
    );
  }

  /// Editor untuk blok teks
  Widget _buildTextBlockContent(_TextBlock block) {
    return TextFormField(
      controller: block.ctrl,
      maxLines: 6,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.nunito(
          fontSize: 12.5, color: const Color(0xFF1A202C)),
      decoration: InputDecoration(
        hintText: 'Ketik paragraf isi surat di sini...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFF194CB6), width: 1.5)),
        filled: true,
        fillColor: const Color(0xFFFAFBFF),
      ),
    );
  }

  /// Editor untuk blok tabel — grid sel + drag handle antar kolom
  Widget _buildTabelBlockContent(_TableBlock block) {
  const double minW = 44.0;
  const double maxW = 320.0;
  const double handleW = 8.0;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ── Toolbar ──────────────────────────────────────────────
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _tabelToolBtn(Icons.add_box_outlined, '+ Baris', () {
            block.addRow(_rebuild);
            setState(() {});
          }),
          _tabelToolBtn(Icons.view_week_outlined, '+ Kolom', () {
            block.addCol(_rebuild);
            setState(() {});
          }),
          if (block.rows > 1)
            _tabelToolBtn(Icons.remove_circle_outline, '− Baris terakhir', () {
              block.removeRow(block.rows - 1);
              setState(() {});
            }, isDestructive: true),
          if (block.cols > 1)
            _tabelToolBtn(Icons.remove_circle_outline, '− Kolom terakhir', () {
              block.removeCol(block.cols - 1);
              setState(() {});
            }, isDestructive: true),
        ],
      ),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.swap_horiz, size: 11, color: Color(0xFF194CB6)),
        const SizedBox(width: 4),
        Text(
          'Seret garis biru di antara kolom untuk mengubah lebar',
          style: GoogleFonts.nunito(
              fontSize: 10,
              color: const Color(0xFF194CB6),
              fontStyle: FontStyle.italic),
        ),
      ]),
      const SizedBox(height: 6),

      // ── Tabel ─────────────────────────────────────────────────
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── HEADER ROW + DRAG HANDLE (height eksplisit = 28) ──
            SizedBox(
              height: 28, // ✅ FIX: height eksplisit, tidak pakai IntrinsicHeight
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int j = 0; j < block.cols; j++) ...[
                    Container(
                      width: block.colWidths[j],
                      color: const Color.fromARGB(255, 255, 255, 255),
                      child: Center(
                        child: Text(
                          'K${j + 1}  ${block.colWidths[j].round()}px',
                          style: GoogleFonts.nunito(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF194CB6)),
                        ),
                      ),
                    ),
                    if (j < block.cols - 1)
                      // ✅ FIX: MouseRegion di dalam SizedBox dengan height eksplisit
                      SizedBox(
                        width: handleW,
                        height: 28,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (d) {
                              setState(() {
                                final delta = d.delta.dx;
                                final newLeft = (block.colWidths[j] + delta)
                                    .clamp(minW, maxW);
                                final newRight =
                                    (block.colWidths[j + 1] - delta)
                                        .clamp(minW, maxW);
                                block.colWidths[j] = newLeft;
                                block.colWidths[j + 1] = newRight;
                              });
                            },
                            child: Container(
                              color: const Color(0xFF194CB6),
                              child: const Center(
                                child: Icon(Icons.drag_indicator,
                                    size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),

            // ── DATA ROWS (tanpa MouseRegion, pakai SizedBox biasa) ──
            for (int r = 0; r < block.rows; r++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int c = 0; c < block.cols; c++) ...[
                      Container(
                        width: block.colWidths[c],
                        decoration: BoxDecoration(
                          color: r == 0
                              ? const Color(0xFFD6E0F8)
                              : (r.isEven
                                  ? const Color(0xFFF5F8FF)
                                  : Colors.white),
                          border: Border.all(
                              color: const Color(0xFF194CB6).withOpacity(0.3),
                              width: 0.5),
                        ),
                        child: TextField(
                          controller: block.cells[r][c],
                          onChanged: (_) => setState(() {}),
                          textAlign:
                              r == 0 ? TextAlign.center : TextAlign.left,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: r == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: const Color(0xFF1A202C),
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      // ✅ SizedBox biasa untuk spacer di data rows (bukan MouseRegion)
                      if (c < block.cols - 1)
                        SizedBox(
                          width: handleW,
                          child: Container(
                            color: const Color(0xFF194CB6).withOpacity(0.15),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),

      const SizedBox(height: 6),
      Row(children: [
        const Icon(Icons.info_outline, size: 11, color: Color(0xFF194CB6)),
        const SizedBox(width: 4),
        Text(
          'Baris pertama (biru) = header tabel',
          style: GoogleFonts.nunito(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic),
        ),
      ]),
    ],
  );
}

  Widget _tabelToolBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? Colors.red.shade400 : const Color(0xFF194CB6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers (form fields) ──────────────────────────────────────────

  Widget _sectionLabel(String text) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EDF8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: GoogleFonts.nunito(
                color: const Color(0xFF194CB6),
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D3748))),
          if (required)
            const Text(' *',
                style: TextStyle(color: Colors.red, fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: (_) => setState(() {}),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
                  ? '$label tidak boleh kosong'
                  : null
              : null,
          style: GoogleFonts.nunito(
              fontSize: 13, color: const Color(0xFF1A202C)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 12),
            prefixIcon: Icon(icon,
                color: const Color(0xFF194CB6), size: 18),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF194CB6), width: 1.5)),
            filled: true,
            fillColor: const Color(0xFFFAFBFF),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tanggal Surat',
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D3748))),
          const SizedBox(height: 5),
          InkWell(
            onTap: _pilihTanggal,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFF),
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Color(0xFF194CB6), size: 18),
                const SizedBox(width: 10),
                Text(_tanggalFormatted,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: const Color(0xFF1A202C))),
                const Spacer(),
                Icon(Icons.arrow_drop_down,
                    color: Colors.grey.shade500),
              ]),
            ),
          ),
        ],
      );
}