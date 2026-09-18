import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:arsipdigital_web/pages/cetak_disposisi.dart';

// ══════════════════════════════════════════════════════════════
// 1. WIDGET MODAL FORM DISPOSISI
// ══════════════════════════════════════════════════════════════
class FormDisposisiModal extends StatefulWidget {
  final Map<String, dynamic> item;
  final String apiUrl;
  final String currentUnit;
  final int currentUserId;
  final int currentDisposisiId; // dipertahankan optional agar tidak breaking
  final int currentUnitId;
  final VoidCallback onSuccess;

  const FormDisposisiModal({
    super.key,
    required this.item,
    required this.apiUrl,
    required this.currentUnit,
    required this.currentUserId,
    this.currentDisposisiId = 0, // ← optional, default 0
    required this.currentUnitId,
    required this.onSuccess,
  });

  @override
  State<FormDisposisiModal> createState() => _FormDisposisiModalState();
}

class _FormDisposisiModalState extends State<FormDisposisiModal> {
  final TextEditingController _catatanCtrl = TextEditingController();
  late TextEditingController _dariCtrl;

  // Dropdown single-select
  String? _unitTerpilihId;
  List<dynamic> _listUnit = [];
  bool _loadingUnit = true;

  String? _sifatTerpilih;
  final List<String> _listSifat = ["Biasa", "Segera", "Rahasia"];

  @override
  void initState() {
    super.initState();
    _dariCtrl = TextEditingController(
      text: widget.currentUnit.isNotEmpty
          ? widget.currentUnit.toUpperCase()
          : "UNIT TIDAK TERDETEKSI",
    );
    _fetchUnit();
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    _dariCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUnit() async {
    setState(() => _loadingUnit = true);
    try {
      final r = await http.get(Uri.parse('${widget.apiUrl}/api/unit'));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['success'] == true) {
          setState(() {
            _listUnit = List<dynamic>.from(d['data']);
          });
        }
      }
    } catch (_) {}
    setState(() => _loadingUnit = false);
  }

  Future<void> _simpan() async {
    if (_unitTerpilihId == null) {
      _snack("Pilih unit tujuan disposisi terlebih dahulu.");
      return;
    }
    if (_catatanCtrl.text.trim().isEmpty) {
      _snack("Keterangan / instruksi wajib diisi.");
      return;
    }

    try {
      final r = await http.post(
        Uri.parse('${widget.apiUrl}/api/disposisi'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id_surat"        : int.parse(widget.item['id_surat'].toString()),
          "id_unit_tujuan"  : [int.parse(_unitTerpilihId!)],
          "isi_disposisi"   : _catatanCtrl.text.trim(),
          "id_user_pimpinan": widget.currentUserId,
          "sifat_surat"     : _sifatTerpilih ?? "Biasa",
        }),
      );

      if (r.statusCode == 200) {
        final body = json.decode(r.body);
        if (body['success'] == true) {
          if (mounted) Navigator.pop(context);
          _snack(body['message'] ?? "Disposisi berhasil disimpan");
          widget.onSuccess();
          return;
        }
      }
      _snack("Gagal menyimpan ke database.");
    } catch (e) {
      _snack("Kesalahan koneksi: $e");
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // FIX: batasi tinggi dialog dan bungkus isi dengan scroll
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 880,
          maxHeight: screenH * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── HEADER (tidak ikut scroll) ──────────────────────────
            _buildHeader(),

            // ── BODY SCROLLABLE ─────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kolom kiri — detail surat
                    Expanded(child: _buildDetailSurat()),
                    const SizedBox(width: 20),
                    // Kolom kanan — form disposisi
                    Expanded(child: _buildFormDisposisi()),
                  ],
                ),
              ),
            ),

            // ── FOOTER (tidak ikut scroll) ──────────────────────────
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Text(
              "Disposisi Surat Masuk",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.grey, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── KOLOM KIRI: Detail Surat ───────────────────────────────────
  Widget _buildDetailSurat() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
              border:
                  Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Icon(Icons.folder_open_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text("Detail Surat Masuk",
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade200),
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2),
              },
              children: [
                _tableRowStatic("Nomor Surat",
                    widget.item['nomor_surat'] ?? "-"),
                _tableRowStatic(
                    "Tanggal", widget.item['tanggal_surat'] ?? "-"),
                _tableRowStatic(
                    "Asal", widget.item['asal_surat'] ?? "-"),
                _tableRowStatic(
                    "Perihal", widget.item['perihal'] ?? "-"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── KOLOM KANAN: Form Disposisi ────────────────────────────────
  Widget _buildFormDisposisi() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Form Disposisi",
              style: GoogleFonts.nunito(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),

          // Dari (readonly)
          _label("Dari"),
          const SizedBox(height: 5),
          TextField(
            controller: _dariCtrl,
            readOnly: true,
            style: GoogleFonts.nunito(fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 14),

          // ── KEPADA: Dropdown single-select ──────────────────────
          _label("Kepada"),
          const SizedBox(height: 5),
          _loadingUnit
              ? const SizedBox(
                  height: 44,
                  child: Center(child: LinearProgressIndicator()))
              : DropdownButtonFormField<String>(
                  value: _unitTerpilihId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "— Pilih unit tujuan —",
                    hintStyle: GoogleFonts.nunito(
                        fontSize: 13, color: Colors.grey),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade400)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF194CB6), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                  ),
                  items: _listUnit.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit['id_unit'].toString(),
                      child: Text(
                        unit['nama_unit'].toString(),
                        style: GoogleFonts.nunito(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _unitTerpilihId = val),
                ),
          const SizedBox(height: 14),

          // Keterangan / Instruksi
          _label("Keterangan / Instruksi"),
          const SizedBox(height: 5),
          TextField(
            controller: _catatanCtrl,
            maxLines: 3,
            style: GoogleFonts.nunito(fontSize: 13),
            decoration: InputDecoration(
              hintText: "Tulis catatan atau instruksi disposisi...",
              hintStyle: GoogleFonts.nunito(
                  fontSize: 13, color: Colors.grey),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFF194CB6), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // Sifat Surat
          _label("Sifat Surat"),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: _sifatTerpilih,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              hintText: "— Pilih sifat —",
              hintStyle:
                  GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFF194CB6), width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
            items: _listSifat
                .map((s) => DropdownMenuItem(
                    value: s,
                    child:
                        Text(s, style: GoogleFonts.nunito(fontSize: 13))))
                .toList(),
            onChanged: (val) => setState(() => _sifatTerpilih = val),
          ),
        ],
      ),
    );
  }

  // ── FOOTER ────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.grey.shade400),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: GoogleFonts.nunito(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded,
                size: 16, color: Colors.white),
            label: Text("Simpan Disposisi",
                style: GoogleFonts.nunito(
                    fontSize: 14, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF194CB6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _simpan,
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w600));

  static TableRow _tableRowStatic(String label, String value) =>
      TableRow(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ]);
}


// ══════════════════════════════════════════════════════════════
// 2. CLASS HELPER UNTUK LIHAT DETAIL DISPOSISI
// ══════════════════════════════════════════════════════════════
class DisposisiViewer {
  static Future<void> showDetail(
    BuildContext context,
    String apiUrl,
    int idSurat,
    String role,
    String currentUnit,
    int currentUserId, {
    required Map<String, dynamic> itemSurat,
    VoidCallback? onRefresh,
  }) async {
    final nav       = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final r =
          await http.get(Uri.parse('$apiUrl/api/disposisi/$idSurat'));
      nav.pop();

      if (r.statusCode == 200) {
        final decoded = json.decode(r.body);
        if (decoded['success'] == true &&
            decoded['data'] != null &&
            (decoded['data'] as List).isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              _displayModal(
                context,
                decoded['data'],
                role,
                apiUrl: apiUrl,
                itemSurat: itemSurat,
                currentUnit: currentUnit,
                currentUserId: currentUserId,
                onRefresh: onRefresh,
              );
            }
          });
        } else {
          messenger.showSnackBar(
              const SnackBar(
                  content: Text("Data disposisi tidak ditemukan.")));
        }
      } else {
        messenger.showSnackBar(
            SnackBar(
                content: Text("Server error: ${r.statusCode}")));
      }
    } catch (e) {
      nav.pop();
      messenger
          .showSnackBar(SnackBar(content: Text("Gagal koneksi: $e")));
    }
  }

  static Future<bool> _deleteDisposisi(
      String apiUrl, int idDisposisi) async {
    try {
      final r = await http
          .delete(Uri.parse('$apiUrl/api/disposisi/$idDisposisi'));
      if (r.statusCode == 200) {
        return json.decode(r.body)['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static void _displayModal(
    BuildContext context,
    List<dynamic> listDisposisiAwal,
    String role, {
    required String apiUrl,
    required Map<String, dynamic> itemSurat,
    required String currentUnit,
    required int currentUserId,
    VoidCallback? onRefresh,
  }) {
    final bool isPimpinan = role == "pimpinan";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final first =
              listDisposisiAwal.isNotEmpty ? listDisposisiAwal[0] : {};

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 780,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── HEADER ────────────────────────────────────
                  Container(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Colors.grey.shade200))),
                    child: Row(children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Text(
                          "Disposisi Surat Masuk",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel,
                            color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ]),
                  ),

                  // ── BODY SCROLLABLE ───────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // KIRI: Detail Surat
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Column(children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(9)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.folder,
                                        color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text("Detail Surat Masuk",
                                        style: GoogleFonts.nunito(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.bold)),
                                  ]),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Table(
                                    border: TableBorder.all(
                                        color: Colors.grey.shade200),
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.2),
                                      1: FlexColumnWidth(2),
                                    },
                                    children: [
                                      _tableRow("Nomor Surat",
                                          first['nomor_surat'] ?? "-"),
                                      _tableRow("Tanggal",
                                          first['tanggal_surat'] ??
                                              "-"),
                                      _tableRow("Asal",
                                          first['asal_surat'] ?? "-"),
                                      _tableRow("Perihal",
                                          first['perihal'] ?? "-"),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // KANAN: Instruksi Disposisi
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text("Instruksi Disposisi",
                                      style: GoogleFonts.nunito(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  Table(
                                    border: TableBorder.all(
                                        color: Colors.grey.shade300),
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.2),
                                      1: FlexColumnWidth(2),
                                    },
                                    children: [
                                      _tableRow(
                                          "Dari",
                                          first['dari_unit'] ??
                                              "Rektor"),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Daftar instruksi per unit
                                  ...listDisposisiAwal
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final idx  = entry.key;
                                    final d    = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors
                                                .grey.shade300),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Column(children: [
                                        // Sub-header instruksi
                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 10,
                                                  vertical: 7),
                                          decoration: BoxDecoration(
                                            color: Colors
                                                .grey.shade100,
                                            borderRadius:
                                                const BorderRadius
                                                    .vertical(
                                                    top: Radius
                                                        .circular(7)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Text(
                                                "Instruksi ${idx + 1}",
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight
                                                            .bold,
                                                    fontSize: 12,
                                                    color: Colors
                                                        .blueGrey),
                                              ),
                                              if (isPimpinan)
                                                _hapusBtn(() async {
                                                  final ok =
                                                      await _confirmHapus(
                                                          context,
                                                          idx,
                                                          d);
                                                  if (ok) {
                                                    final berhasil =
                                                        await _deleteDisposisi(
                                                            apiUrl,
                                                            d['id_disposisi']);
                                                    if (berhasil) {
                                                      setState(() =>
                                                          listDisposisiAwal
                                                              .removeAt(
                                                                  idx));
                                                      onRefresh
                                                          ?.call();
                                                      if (context
                                                          .mounted) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                              content:
                                                                  Text("Instruksi berhasil dihapus")),
                                                        );
                                                      }
                                                    }
                                                  }
                                                }),
                                            ],
                                          ),
                                        ),
                                        Table(
                                          border: TableBorder.all(
                                              color: Colors
                                                  .grey.shade200),
                                          columnWidths: const {
                                            0: FlexColumnWidth(1.2),
                                            1: FlexColumnWidth(2),
                                          },
                                          children: [
                                            _tableRow(
                                                "Kepada",
                                                d['ke_unit'] ??
                                                    d['nama_unit'] ??
                                                    "-"),
                                            _tableRow(
                                                "Keterangan",
                                                d['isi_disposisi'] ??
                                                    "-"),
                                          ],
                                        ),
                                      ]),
                                    );
                                  }),

                                  const SizedBox(height: 10),

                                  // Sifat & Tanggal
                                  Table(
                                    border: TableBorder.all(
                                        color: Colors.grey.shade300),
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.2),
                                      1: FlexColumnWidth(2),
                                    },
                                    children: [
                                      TableRow(children: [
                                        const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: Text("Sifat Surat",
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight
                                                          .w600)),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.all(10),
                                          child: Text(
                                            first['sifat_surat'] ??
                                                "Biasa",
                                            style: TextStyle(
                                              color: _sifatColor(
                                                  first['sifat_surat']),
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ]),
                                      TableRow(children: [
                                        const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: Text(
                                              "Tanggal Disposisi",
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight
                                                          .w600)),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.all(10),
                                          child: Text(
                                            first[
                                                    'tanggal_disposisi'] ??
                                                "-",
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                      ]),
                                    ],
                                  ),

                                  // Tombol tambah instruksi (hanya pimpinan)
                                  if (isPimpinan) ...[
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.add),
                                        label: const Text(
                                            "Tambah Instruksi"),
                                        style:
                                            OutlinedButton.styleFrom(
                                          foregroundColor:
                                              Colors.blue.shade700,
                                          side: BorderSide(
                                              color:
                                                  Colors.blue.shade200),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8)),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) =>
                                                FormDisposisiModal(
                                              item: itemSurat,
                                              apiUrl: apiUrl,
                                              currentUnit: currentUnit,
                                              currentUserId:
                                                  currentUserId,
                                              currentUnitId:
                                                  itemSurat['id_unit'] ??
                                                      0,
                                              onSuccess: () =>
                                                  onRefresh?.call(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── FOOTER ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                          top: BorderSide(
                              color: Colors.grey.shade200)),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(
                                color: Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text("Tutup",
                              style: GoogleFonts.nunito(
                                  fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print,
                              color: Colors.white, size: 16),
                          label: Text("Cetak Disposisi",
                              style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF194CB6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            try {
                              await LembarDisposisiPdf.cetak(
                                  listDisposisi: listDisposisiAwal);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      "Gagal membuat PDF: $e"),
                                ));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── HELPER STATICS ─────────────────────────────────────────────
  static Future<bool> _confirmHapus(
      BuildContext context, int idx, Map d) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: const Text("Hapus Instruksi?"),
            content: Text(
                "Instruksi ke-${idx + 1} untuk unit '${d['ke_unit'] ?? d['nama_unit'] ?? '-'}' akan dihapus permanen."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Batal")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Hapus",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Widget _hapusBtn(VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.redAccent),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.delete_outline,
                size: 14, color: Colors.redAccent),
            SizedBox(width: 4),
            Text("Hapus",
                style: TextStyle(
                    fontSize: 12, color: Colors.redAccent)),
          ]),
        ),
      );

  static Color _sifatColor(String? sifat) {
    switch (sifat) {
      case "Segera":  return Colors.orange;
      case "Rahasia": return Colors.red;
      default:        return Colors.blue;
    }
  }

  static TableRow _tableRow(String label, String value) => TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      );
}