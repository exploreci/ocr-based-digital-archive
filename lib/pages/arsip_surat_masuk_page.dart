import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arsipdigital_web/main_layout.dart';
import 'disposisi_page.dart';
import 'dart:html' as html;

const _kNavy      = Color(0xFF194CB6);
const _kNavyDark  = Color(0xFF0F3280);
const _kNavyLight = Color(0xFFE8EDF8);
const _kRowAlt    = Color(0xFFF5F8FF);
const _kBorder    = Color(0xFFDDE3F0);
const _kTextHead  = Colors.white;
const _kTextBody  = Color(0xFF1A202C);
const _kTextMuted = Color(0xFF718096);

const int _kPageSize = 10;

class DaftarArsipMasukPage extends StatefulWidget {
  const DaftarArsipMasukPage({super.key});
  @override
  State<DaftarArsipMasukPage> createState() => _DaftarArsipMasukPageState();
}

class _DaftarArsipMasukPageState extends State<DaftarArsipMasukPage> {
  final String apiUrl = "http://127.0.0.1:8000";
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<dynamic> dataArsip    = [];
  List<dynamic> dataFiltered = [];
  bool isLoading = true;

  String currentRole   = "";
  int    currentUserId = 0;
  int    currentUnitId = 0;
  String currentUnit   = "";

  // ── Pagination ──
  int _currentPage = 1;

  int get _totalPages =>
      (dataFiltered.length / _kPageSize).ceil().clamp(1, 99999);

  List<dynamic> get _pageData {
    final start = (_currentPage - 1) * _kPageSize;
    final end   = (start + _kPageSize).clamp(0, dataFiltered.length);
    return dataFiltered.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _loadRole();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentRole   = prefs.getString('role')   ?? "";
      currentUserId = prefs.getInt('user_id')   ?? 0;
      currentUnit   = prefs.getString('unit')   ?? ""; 
      currentUnitId = prefs.getInt('unit_id')   ?? 0;
    });
    fetchSuratMasuk();
  }

  Future<void> fetchSuratMasuk() async {
    setState(() => isLoading = true);
    try {
      final url =
          '$apiUrl/api/surat-masuk?role=$currentRole&id_unit=$currentUnitId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          setState(() {
            dataArsip    = decoded['data'];
            dataFiltered = decoded['data'];
            _currentPage = 1;
            isLoading    = false;
          });
        }
      } else {
        _snack("Server Error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      _snack("Koneksi Gagal: $e");
      setState(() => isLoading = false);
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      dataFiltered = q.isEmpty
          ? dataArsip
          : dataArsip.where((item) {
              return (item['nomor_surat'] ?? '').toLowerCase().contains(q) ||
                  (item['asal_surat']   ?? '').toLowerCase().contains(q) ||
                  (item['perihal']      ?? '').toLowerCase().contains(q);
            }).toList();
      _currentPage = 1;
    });
  }

  void _goPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() => _currentPage = page);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }
  }

  String _formatTanggal(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    const bln = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    try {
      final d = DateTime.parse(raw);
      return "${d.day} ${bln[d.month]} ${d.year}";
    } catch (_) { return raw; }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ── Hapus ───────────────────────────────────────────────────
  Future<void> _konfirmasiHapus(int idSurat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Text("Hapus Arsip",
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: const Text(
            "Yakin ingin menghapus arsip surat ini?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final r = await http
            .delete(Uri.parse('$apiUrl/api/surat/$idSurat'));
        if (r.statusCode == 200) {
          _snack("Arsip berhasil dihapus.");
          fetchSuratMasuk();
        } else {
          _snack("Gagal menghapus. Server: ${r.statusCode}");
        }
      } catch (e) { _snack("Koneksi gagal: $e"); }
    }
  }

  // ── Edit ────────────────────────────────────────────────────
  void _showEditDialog(Map<String, dynamic> item) {
    final noCtrl      = TextEditingController(text: item['nomor_surat']   ?? '');
    final tglCtrl     = TextEditingController(text: item['tanggal_surat'] ?? '');
    final perihalCtrl = TextEditingController(text: item['perihal']       ?? '');
    final asalCtrl    = TextEditingController(text: item['asal_surat']    ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 460,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.edit_document, color: _kNavy),
                  const SizedBox(width: 10),
                  Text("Edit Arsip Surat Masuk",
                      style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
                const Divider(),
                const SizedBox(height: 8),
                _editField("Asal Surat",               asalCtrl),
                _editField("Nomor Surat",               noCtrl),
                _editField("Tanggal Surat (YYYY-MM-DD)", tglCtrl),
                _editField("Perihal",                   perihalCtrl),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                      child: const Text("Batal"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kNavy,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        try {
                          final res = await http.put(
                            Uri.parse(
                                '$apiUrl/api/surat/${item['id_surat']}'),
                            headers: {
                              "Content-Type": "application/json"
                            },
                            body: json.encode({
                              "nomor_surat":   noCtrl.text.trim(),
                              "tanggal_surat": tglCtrl.text.trim(),
                              "perihal":       perihalCtrl.text.trim(),
                              "asal_surat":    asalCtrl.text.trim(),
                            }),
                          );
                          final data = json.decode(res.body);
                          Navigator.pop(ctx);
                          _snack(data['message'] ??
                              "Berhasil diperbarui");
                          fetchSuratMasuk();
                        } catch (e) { _snack("Gagal: $e"); }
                      },
                      child: Text("Simpan",
                          style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.nunito(fontSize: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  // ── PDF Preview ─────────────────────────────────────────────
  void _showPdfPreview(String fileName) {
    final fullUrl = "$apiUrl/uploads/arsip/$fileName";
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                gradient:
                    LinearGradient(colors: [_kNavy, _kNavyDark]),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(15)),
              ),
              child: Row(children: [
                const Icon(Icons.picture_as_pdf,
                    color: Colors.white),
                const SizedBox(width: 12),
                Text("Pratinjau Dokumen Digital",
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      _downloadPdf(fullUrl, fileName),
                  icon: const Icon(Icons.download_rounded,
                      color: Colors.white, size: 18),
                  label: Text("Unduh",
                      style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
            ),
            Expanded(
              child: SfPdfViewer.network(fullUrl,
                  onDocumentLoadFailed: (d) =>
                      _snack("Gagal memuat PDF: ${d.description}")),
            ),
          ]),
        ),
      ),
    );
  }

  void _downloadPdf(String url, String fileName) {
    final a = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body!.append(a);
    a.click();
    a.remove();
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Sistem Informasi Penyimpanan Arsip Digital",
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text("Daftar Arsip Surat Masuk",
                      style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _kNavy)),
                  Text("Total ${dataArsip.length} surat tercatat",
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: _kTextMuted)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kNavy, _kNavyDark]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: _kNavy.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.inbox_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text("${dataArsip.length} Surat",
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(
                        color: _kNavy)),
              )
            else
              Expanded(child: _buildTableCard()),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard() {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _kNavy.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            // ── Toolbar ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(children: [
                Container(
                  width: 320, height: 40,
                  decoration: BoxDecoration(
                    color: _kNavyLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.nunito(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Cari nomor, asal, atau perihal...",
                      hintStyle: GoogleFonts.nunito(
                          fontSize: 13, color: _kTextMuted),
                      prefixIcon: const Icon(Icons.search,
                          color: _kNavy, size: 18),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: "Refresh Data",
                  child: InkWell(
                    onTap: fetchSuratMasuk,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _kNavyLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: _kNavy, size: 20),
                    ),
                  ),
                ),
              ]),
            ),

            Container(height: 1, color: _kBorder),

            // ── Tabel ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth:
                        MediaQuery.of(context).size.width - 56 - 2),
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(52),
                    1: FixedColumnWidth(186),
                    2: FixedColumnWidth(240),
                    3: FixedColumnWidth(250),
                    4: FlexColumnWidth(),
                    5: FixedColumnWidth(148),
                    6: FixedColumnWidth(128),
                  },
                  defaultVerticalAlignment:
                      TableCellVerticalAlignment.middle,
                  children: [
                    // Header
                    TableRow(
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [_kNavy, _kNavyDark])),
                      children: [
                        _thCell("No"),
                        _thCell("Tanggal"),
                        _thCell("Nomor Surat"),
                        _thCell("Asal Surat"),
                        _thCell("Perihal"),
                        _thCell("Status"),
                        _thCell("Aksi"),
                      ],
                    ),

                    // Data rows — hanya tampil _pageData
                    if (_pageData.isEmpty)
                      TableRow(
                        decoration:
                            const BoxDecoration(color: Colors.white),
                        children: List.generate(
                          7,
                          (i) => i == 3
                              ? _emptyCell("Tidak ada data")
                              : _emptyCell(""),
                        ),
                      )
                    else
                      ..._pageData.asMap().entries.map((entry) {
                        final idx       = entry.key;
                        final item      = entry.value;
                        final globalIdx =
                            (_currentPage - 1) * _kPageSize + idx;
                        final isAlt     = globalIdx % 2 == 1;

                        return TableRow(
                          decoration: BoxDecoration(
                              color: isAlt ? _kRowAlt : Colors.white),
                          children: [
                            _tdCenter(Text("${globalIdx + 1}",
                                style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _kTextMuted))),
                            _tdCenter(Text(
                              _formatTanggal(
                                  item['tanggal_surat']?.toString()),
                              style: GoogleFonts.nunito(
                                  fontSize: 12.5,
                                  color: _kTextBody),
                              textAlign: TextAlign.center,
                            )),
                            _tdCenter(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kNavyLight,
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Text(
                                item['nomor_surat'] ?? "-",
                                style: GoogleFonts.nunito(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: _kNavy),
                                textAlign: TextAlign.center,
                              ),
                            )),
                            _tdCenter(Text(
                                item['asal_surat'] ?? "-",
                                style: GoogleFonts.nunito(
                                    fontSize: 12.5,
                                    color: _kTextBody),
                                textAlign: TextAlign.center)),
                            _tdCenter(Text(item['perihal'] ?? "-",
                                style: GoogleFonts.nunito(
                                    fontSize: 12.5,
                                    color: _kTextBody),
                                textAlign: TextAlign.center)),
                            _tdCenter(_buildStatusBadge(item)),
                            _tdCenter(_buildAksi(item)),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ),

            // ── Pagination ──
            _buildPagination(),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: _kNavyLight,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: _kNavy, size: 14),
                const SizedBox(width: 6),
                Text(
                  "Halaman $_currentPage dari $_totalPages  •  "
                  "Menampilkan ${_pageData.length} dari ${dataFiltered.length} data",
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: _kNavy),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pagination bar ──────────────────────────────────────────
  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pageBtn(
            icon: Icons.chevron_left,
            enabled: _currentPage > 1,
            onTap: () => _goPage(_currentPage - 1),
          ),
          const SizedBox(width: 6),
          ..._buildPageNumbers(),
          const SizedBox(width: 6),
          _pageBtn(
            icon: Icons.chevron_right,
            enabled: _currentPage < _totalPages,
            onTap: () => _goPage(_currentPage + 1),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final pages = <int>{};
    pages.add(1);
    pages.add(_totalPages);
    for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
      if (i >= 1 && i <= _totalPages) pages.add(i);
    }
    final sorted = pages.toList()..sort();

    final widgets = <Widget>[];
    int prev = 0;
    for (final p in sorted) {
      if (prev != 0 && p - prev > 1) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text("...",
              style: GoogleFonts.nunito(
                  color: _kTextMuted,
                  fontWeight: FontWeight.bold)),
        ));
      }
      widgets.add(_pageNumber(p));
      prev = p;
    }
    return widgets;
  }

  Widget _pageNumber(int page) {
    final isActive = page == _currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => _goPage(page),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isActive ? _kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? _kNavy : _kBorder,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text("$page",
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: isActive ? Colors.white : _kTextBody,
                  fontWeight: isActive
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? _kNavyLight : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 20,
            color: enabled ? _kNavy : Colors.grey.shade400),
      ),
    );
  }

  Widget _thCell(String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        alignment: Alignment.center,
        child: Text(label,
            style: GoogleFonts.nunito(
                color: _kTextHead,
                fontWeight: FontWeight.bold,
                fontSize: 13),
            textAlign: TextAlign.center),
      );

  Widget _tdCenter(Widget child) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: 13, horizontal: 8),
          alignment: Alignment.center,
          child: child,
        ),
      );

  Widget _emptyCell(String text) => Container(
        padding: const EdgeInsets.symmetric(
            vertical: 28, horizontal: 8),
        alignment: Alignment.center,
        child: Text(text,
            style: GoogleFonts.nunito(
                fontSize: 13, color: _kTextMuted)),
      );

  Widget _buildStatusBadge(Map<String, dynamic> item) {
    final status   = item['status_label'] ?? "Belum Disposisi";
    final safeRole = currentRole.toLowerCase().trim();

    if (status == "Lihat Disposisi") {
      return _pillButton(
        label: "Lihat Disposisi",
        color: const Color(0xFF16A34A),
        icon: Icons.assignment_turned_in_outlined,
        onTap: () {
          final idSurat =
              int.parse(item['id_surat'].toString());
          DisposisiViewer.showDetail(
            context, apiUrl, idSurat,
            currentRole, currentUnit, currentUserId,
            itemSurat: item,
            onRefresh: fetchSuratMasuk,
          );
        },
      );
    }

    if (safeRole == "pimpinan") {
      return _pillButton(
        label: "Beri Disposisi",
        color: const Color(0xFFD97706),
        icon: Icons.rate_review_outlined,
        onTap: () => showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => FormDisposisiModal(
            item: item,
            apiUrl: apiUrl,
            currentUnit: currentUnit,
            currentUserId: currentUserId,
            currentDisposisiId: item['id_disposisi'] ?? 0,
            currentUnitId: currentUnitId, // ← TAMBAHKAN INI
            onSuccess: fetchSuratMasuk,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text("Belum Disposisi",
          style: GoogleFonts.nunito(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _pillButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAksi(Map<String, dynamic> item) {
    final isOperator =
        currentRole.toLowerCase().trim() == "operator";

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconBtn(
          icon: Icons.visibility_outlined,
          color: const Color(0xFF2563EB),
          tooltip: "Lihat PDF",
          onTap: () {
            final path = item['file_path'] ?? "";
            final fileName = path.split('/').last;
            if (fileName.isNotEmpty) _showPdfPreview(fileName);
          },
        ),
        if (isOperator) ...[
          const SizedBox(width: 4),
          _iconBtn(
            icon: Icons.edit_outlined,
            color: const Color(0xFFD97706),
            tooltip: "Edit",
            onTap: () => _showEditDialog(item),
          ),

           const SizedBox(width: 4),
        _iconBtn(
          icon: Icons.delete_outline_rounded,
          color: const Color(0xFFDC2626),
          tooltip: "Hapus",
          onTap: () {
            final id =
                int.tryParse(item['id_surat'].toString()) ?? 0;
            if (id > 0) _konfirmasiHapus(id);
          },
        ),
        ],
       
      ],
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}