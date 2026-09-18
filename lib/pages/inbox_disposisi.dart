import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // ← tambahkan ini
import 'package:arsipdigital_web/main_layout.dart';
import 'disposisi_page.dart';

// ══════════════════════════════════════════════════════════
// KONSTANTA WARNA — sesuai mockup HTML
// ══════════════════════════════════════════════════════════
const _kNavy        = Color(0xFF194CB6);
const _kNavyLight   = Color(0xFFE8EDF8);
const _kGreen       = Color(0xFF059669);
const _kGreenLight  = Color(0xFFD1FAE5);
const _kGreenDark   = Color(0xFF065F46);
const _kRowAlt      = Color(0xFFF5F8FF);
const _kRowNew      = Color(0xFFFFFBEB);
const _kBorder      = Color(0xFFDDE3F0);
const _kTextBody    = Color(0xFF1A202C);
const _kTextMuted   = Color(0xFF718096);

const _cOrangeBg    = Color(0xFFFFF7ED);
const _cOrangeFg    = Color(0xFFC2410C);
const _cBlueBg      = Color(0xFFEFF6FF);
const _cBlueFg      = Color(0xFF1D4ED8);
const _cGreenBg     = Color(0xFFF0FDF4);
const _cGreenFg     = Color(0xFF15803D);
const _cGrayBg      = Color(0xFFF1F5F9);
const _cGrayFg      = Color(0xFF475569);
const _cPurpleBg    = Color(0xFFF5F3FF);
const _cPurpleFg    = Color(0xFF6D28D9);
const _cRedBg       = Color(0xFFFCEBEB);
const _cRedFg       = Color(0xFFA32D2D);

const int _kPageSize = 10;


// ══════════════════════════════════════════════════════════
// PAGE
// ══════════════════════════════════════════════════════════
class InboxDisposisiPage extends StatefulWidget {
  const InboxDisposisiPage({super.key});
  @override
  State<InboxDisposisiPage> createState() => _InboxDisposisiPageState();
}

class _InboxDisposisiPageState extends State<InboxDisposisiPage>
    with SingleTickerProviderStateMixin {

  final String _apiUrl = "http://127.0.0.1:8000";
  late TabController _tabCtrl;

  List<dynamic> _dataMasuk     = [];
  List<dynamic> _dataTerkirim  = [];
  bool _loadingMasuk    = true;
  bool _loadingTerkirim = true;

  List<dynamic> _filteredMasuk    = [];
  List<dynamic> _filteredTerkirim = [];
  final _searchMasukCtrl    = TextEditingController();
  final _searchTerkirimCtrl = TextEditingController();

  int _pageMasuk    = 1;
  int _pageTerkirim = 1;

  int get _totalPagesMasuk =>
      (_filteredMasuk.length / _kPageSize).ceil().clamp(1, 99999);
  int get _totalPagesTerkirim =>
      (_filteredTerkirim.length / _kPageSize).ceil().clamp(1, 99999);

  List<dynamic> get _pageDataMasuk {
    final s = (_pageMasuk - 1) * _kPageSize;
    return _filteredMasuk.sublist(s, (s + _kPageSize).clamp(0, _filteredMasuk.length));
  }
  List<dynamic> get _pageDataTerkirim {
    final s = (_pageTerkirim - 1) * _kPageSize;
    return _filteredTerkirim.sublist(s, (s + _kPageSize).clamp(0, _filteredTerkirim.length));
  }

  String _role   = "";
  String _unit   = "";
  int    _unitId = 0;
  int    _userId = 0;

  int get _jumlahBaru => _dataMasuk.where((d) => d['status'] == 'baru').length;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchMasukCtrl.addListener(_filterMasuk);
    _searchTerkirimCtrl.addListener(_filterTerkirim);
    _loadSession();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchMasukCtrl.dispose();
    _searchTerkirimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role   = prefs.getString('role')   ?? "";
      _unit   = prefs.getString('unit')   ?? "";
      _unitId = prefs.getInt('unit_id')   ?? 0;
      _userId = prefs.getInt('id_user')   ?? 0;
    });
    _fetchMasuk();
    _fetchTerkirim();
  }

  Future<void> _fetchMasuk() async {
    setState(() => _loadingMasuk = true);
    try {
      final r = await http.get(Uri.parse('$_apiUrl/api/disposisi/masuk?id_unit=$_unitId'));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['success'] == true) {
          setState(() {
            _dataMasuk     = d['data'] ?? [];
            _filteredMasuk = _dataMasuk;
            _pageMasuk     = 1;
          });
        }
      }
    } catch (_) {}
    setState(() => _loadingMasuk = false);
  }

  Future<void> _fetchTerkirim() async {
    setState(() => _loadingTerkirim = true);
    try {
      final r = await http.get(
        Uri.parse('$_apiUrl/api/disposisi/terkirim?unit_id=$_unitId')
      );
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['success'] == true) {
          setState(() {
            _dataTerkirim     = d['data'] ?? [];
            _filteredTerkirim = _dataTerkirim;
            _pageTerkirim     = 1;
          });
        }
      }
    } catch (_) {}
    setState(() => _loadingTerkirim = false);
  }

  void _filterMasuk() {
    final q = _searchMasukCtrl.text.toLowerCase();
    setState(() {
      _filteredMasuk = q.isEmpty
          ? _dataMasuk
          : _dataMasuk.where((i) =>
              (i['nomor_surat']   ?? '').toLowerCase().contains(q) ||
              (i['perihal']       ?? '').toLowerCase().contains(q) ||
              (i['dari_unit']     ?? '').toLowerCase().contains(q) ||
              (i['isi_disposisi'] ?? '').toLowerCase().contains(q)).toList();
      _pageMasuk = 1;
    });
  }

  void _filterTerkirim() {
    final q = _searchTerkirimCtrl.text.toLowerCase();
    setState(() {
      _filteredTerkirim = q.isEmpty
          ? _dataTerkirim
          : _dataTerkirim.where((i) =>
              (i['nomor_surat']   ?? '').toLowerCase().contains(q) ||
              (i['perihal']       ?? '').toLowerCase().contains(q) ||
              (i['ke_unit']       ?? '').toLowerCase().contains(q) ||
              (i['isi_disposisi'] ?? '').toLowerCase().contains(q)).toList();
      _pageTerkirim = 1;
    });
  }

  Future<void> _tandaiDibaca(int idDisposisi) async {
    try {
      final r = await http.patch(
        Uri.parse('$_apiUrl/api/disposisi/$idDisposisi/status'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"status": "dibaca"}),
      );
      if (r.statusCode == 200) _fetchMasuk();
    } catch (e) {
      _snack("Gagal update status: $e");
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Sistem Informasi Penyimpanan Arsip Digital",
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text("Inbox Disposisi",
                      style: GoogleFonts.nunito(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: _kNavy)),
                  if (_jumlahBaru > 0) ...[
                    const SizedBox(width: 8),
                    _badgeCount(_jumlahBaru),
                  ],
                ]),
                const SizedBox(height: 2),
                Text("Unit: ${_unit.isEmpty ? '-' : _unit.toUpperCase()}",
                    style: GoogleFonts.nunito(fontSize: 12, color: _kTextMuted)),
              ]),
              const Spacer(),
              _headerChip(Icons.inbox_rounded, "${_dataMasuk.length} Masuk",
                  _kNavyLight, _kNavy),
              const SizedBox(width: 8),
              _headerChip(Icons.send_rounded, "${_dataTerkirim.length} Terkirim",
                  const Color(0xFFEAF3DE), const Color(0xFF3B6D11)),
            ]),
            const SizedBox(height: 16),

            // ── CARD ────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder, width: 0.8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04),
                        blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                          bottom: BorderSide(color: _kBorder, width: 0.8)),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      indicatorColor: _kNavy,
                      indicatorWeight: 2.5,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: _kNavy,
                      unselectedLabelColor: _kTextMuted,
                      labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w500, fontSize: 13),
                      tabs: [
                        Tab(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.inbox_rounded, size: 15),
                            const SizedBox(width: 6),
                            const Text("Disposisi Masuk"),
                            if (_jumlahBaru > 0) ...[
                              const SizedBox(width: 6),
                              _badgeCount(_jumlahBaru, small: true),
                            ],
                          ]),
                        ),
                        const Tab(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.send_rounded, size: 15),
                            SizedBox(width: 6),
                            Text("Disposisi Terkirim"),
                          ]),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [_buildTabMasuk(), _buildTabTerkirim()],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB MASUK
  // ══════════════════════════════════════════════════════════
  Widget _buildTabMasuk() {
    return Column(children: [
      _toolbar(_searchMasukCtrl, "Cari nomor, perihal, dari unit...", _fetchMasuk),
      Expanded(
        child: _loadingMasuk
            ? const Center(child: CircularProgressIndicator(color: _kNavy))
            : SingleChildScrollView(
                child: Column(children: [
                  _tableMasuk(),
                  _buildPagination(
                      current: _pageMasuk,
                      total: _totalPagesMasuk,
                      onGo: (p) => setState(() => _pageMasuk = p)),
                  _footerInfo(_pageMasuk, _totalPagesMasuk,
                      _pageDataMasuk.length, _filteredMasuk.length),
                ]),
              ),
      ),
    ]);
  }

  Widget _tableMasuk() {
    // ── Responsif: ukuran minimum tabel agar scroll horizontal
    // hanya aktif bila layar benar-benar sempit ──────────────
    return LayoutBuilder(
      builder: (context, constraints) {
        // Total lebar fixed + 1 flex perihal
        // No(44) + Tgl(140) + NoSurat(178) + DariUnit(155) + Sifat(84) + Status(110) + Aksi(124) = 835
        const double fixedTotal = 44 + 140 + 178 + 155 + 84 + 110 + 124;
        // Perihal minimum 140px; bila layar lebih lebar, perihal mengembang
        const double perihalMin = 140;
        final double tableMin   = fixedTotal + perihalMin;
        final double tableWidth = constraints.maxWidth > tableMin
            ? constraints.maxWidth
            : tableMin;

        // Hitung lebar perihal secara dinamis
        final double perihalWidth = tableWidth - fixedTotal;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Table(
              columnWidths: {
                0: const FixedColumnWidth(44),
                1: const FixedColumnWidth(140),
                2: const FixedColumnWidth(178),
                3: FixedColumnWidth(perihalWidth),
                4: const FixedColumnWidth(155),
                5: const FixedColumnWidth(84),
                6: const FixedColumnWidth(110),
                7: const FixedColumnWidth(124),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: _kNavy),
                  children: [
                    _thCell("No"),
                    _thCell("Tanggal"),
                    _thCell("Nomor Surat"),
                    _thCell("Perihal"),
                    _thCell("Dari Unit"),
                    _thCell("Sifat"),
                    _thCell("Status"),
                    _thCell("Aksi"),
                  ],
                ),

                if (_pageDataMasuk.isEmpty)
                  TableRow(
                    decoration: const BoxDecoration(color: Colors.white),
                    children: List.generate(8,
                        (i) => i == 3
                            ? _emptyCell("Tidak ada disposisi masuk")
                            : _emptyCell("")),
                  )
                else
                  ..._pageDataMasuk.asMap().entries.map((e) {
                    final idx       = e.key;
                    final item      = e.value;
                    final globalIdx = (_pageMasuk - 1) * _kPageSize + idx;
                    final isBaru    = item['status'] == 'baru';

                    return TableRow(
                      decoration: BoxDecoration(
                        color: isBaru
                            ? _kRowNew
                            : (globalIdx % 2 == 1 ? _kRowAlt : Colors.white),
                      ),
                      children: [
                        _tdCenter(Text("${globalIdx + 1}",
                            style: GoogleFonts.nunito(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: _kTextMuted))),

                        _tdCenter(Text(item['tanggal_disposisi'] ?? '-',
                            style: GoogleFonts.nunito(fontSize: 12, color: _kTextBody),
                            textAlign: TextAlign.center)),

                        _tdCenter(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: _kNavyLight,
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(item['nomor_surat'] ?? '-',
                              style: GoogleFonts.nunito(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _kNavy),
                              textAlign: TextAlign.center),
                        )),

                        _tdLeft(Text(item['perihal'] ?? '-',
                            style: GoogleFonts.nunito(fontSize: 13, color: _kTextBody))),

                        _tdCenter(Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isBaru)
                              Container(
                                width: 7, height: 7,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: const BoxDecoration(
                                    color: Color(0xFFF97316),
                                    shape: BoxShape.circle),
                              ),
                            Flexible(
                              child: Text(item['dari_unit'] ?? '-',
                                  style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: isBaru
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _kTextBody),
                                  textAlign: TextAlign.center),
                            ),
                          ],
                        )),

                        _tdCenter(_sifatPill(item['sifat_surat'] ?? 'Biasa')),
                        _tdCenter(_statusPillMasuk(item['status'] ?? 'baru')),
                        _tdCenter(_aksiMasuk(item)),
                      ],
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _aksiMasuk(Map<String, dynamic> item) {
    final status     = item['status'] ?? 'baru';
    final isPimpinan = _role.toLowerCase().trim() == "pimpinan";
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionBtn(
          icon: Icons.visibility_outlined,
          bg: _cBlueBg, fg: const Color(0xFF2563EB),
          tooltip: "Lihat Detail",
          onTap: () => _lihatDetailDisposisi(item),
        ),
        if (status == 'baru') ...[
          const SizedBox(width: 4),
          _actionBtn(
            icon: Icons.mark_email_read_outlined,
            bg: _cGreenBg, fg: const Color(0xFF059669),
            tooltip: "Tandai Dibaca",
            onTap: () => _tandaiDibaca(
                int.tryParse(item['id_disposisi'].toString()) ?? 0),
          ),
        ],
      ],
    );
  }

  void _lihatDetailDisposisi(Map<String, dynamic> item) {
    if ((item['status'] ?? '') == 'baru') {
      final idD = int.tryParse(item['id_disposisi'].toString()) ?? 0;
      if (idD > 0) _tandaiDibaca(idD);
    }
    _showInboxDetailModal(item);
  }

  Widget _sectionTitle(IconData icon, String label, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 17),
      const SizedBox(width: 6),
      Text(label,
          style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color)),
    ],
  );

  Widget _infoBox(List<TableRow> rows) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(2),
      },
      children: rows,
    ),
  );

  TableRow _infoRow(String label, String value) => TableRow(children: [
    Padding(
      padding: const EdgeInsets.all(10),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ),
    Padding(
      padding: const EdgeInsets.all(10),
      child: Text(value, style: const TextStyle(fontSize: 13)),
    ),
  ]);

  void _showInboxDetailModal(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 700,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text("Detail Disposisi Masuk",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.grey, size: 24),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.folder_open_rounded, "Informasi Surat", Colors.blue),
                      const SizedBox(height: 8),
                      _infoBox([
                        _infoRow("Nomor Surat",   item['nomor_surat']   ?? '-'),
                        _infoRow("Tanggal Surat",  item['tanggal_surat'] ?? '-'),
                        _infoRow("Asal Surat",     item['asal_surat']    ?? '-'),
                        _infoRow("Perihal",        item['perihal']       ?? '-'),
                      ]),

                      const SizedBox(height: 18),

                      _sectionTitle(Icons.assignment_outlined, "Instruksi Disposisi", const Color(0xFF194CB6)),
                      const SizedBox(height: 8),
                      _infoBox([
                        _infoRow("Dari Unit",    item['dari_unit']     ?? '-'),
                        _infoRow("Tanggal",      item['tanggal_disposisi'] ?? '-'),
                        _infoRow("Sifat Surat",  item['sifat_surat']   ?? 'Biasa'),
                        _infoRow("Instruksi",    item['isi_disposisi']  ?? '-'),
                      ]),

                      const SizedBox(height: 18),

                      if ((item['file_path'] ?? '').isNotEmpty) ...[
                        _sectionTitle(Icons.picture_as_pdf_outlined, "Dokumen Surat", Colors.red),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text("Buka / Unduh Dokumen Surat",
                                style: GoogleFonts.nunito(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF194CB6),
                              side: const BorderSide(color: Color(0xFF194CB6)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              final fileName = item['file_path'].toString().split('/').last;
                              final url = '$_apiUrl/uploads/arsip/$fileName';
                              html.window.open(url, '_blank');
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF194CB6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text("Tutup",
                          style: GoogleFonts.nunito(
                              fontSize: 14, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _teruskanDisposisi(Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FormDisposisiModal(
        item: {
          'id_surat'     : item['id_surat'],
          'nomor_surat'  : item['nomor_surat'],
          'perihal'      : item['perihal'],
          'asal_surat'   : item['asal_surat'] ?? '-',
          'tanggal_surat': item['tanggal_surat'],
        },
        apiUrl:        _apiUrl,
        currentUnit:   _unit,
        currentUserId: _userId,
        currentUnitId: _unitId,
        currentDisposisiId: 0,
        onSuccess:     _fetchMasuk,
      ),
    );
  }

  void _showTerkirimDetailModal(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 700,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text("Detail Disposisi Terkirim",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.grey, size: 24),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.folder_open_rounded, "Informasi Surat", Colors.blue),
                      const SizedBox(height: 8),
                      _infoBox([
                        _infoRow("Nomor Surat",   item['nomor_surat']   ?? '-'),
                        _infoRow("Tanggal Surat",  item['tanggal_surat'] ?? '-'),
                        _infoRow("Asal Surat",     item['asal_surat']    ?? '-'),
                        _infoRow("Perihal",        item['perihal']       ?? '-'),
                      ]),

                      const SizedBox(height: 18),

                      _sectionTitle(Icons.send_rounded, "Instruksi Terkirim", _kGreen),
                      const SizedBox(height: 8),
                      _infoBox([
                        _infoRow("Ke Unit",        item['ke_unit']           ?? '-'),
                        _infoRow("Tanggal Kirim",  item['tanggal_disposisi'] ?? '-'),
                        _infoRow("Sifat Surat",    item['sifat_surat']       ?? 'Biasa'),
                        _infoRow("Instruksi",      item['isi_disposisi']     ?? '-'),
                        _infoRow("Status",         item['status']            ?? '-'),
                      ]),

                      if ((item['file_path'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _sectionTitle(Icons.picture_as_pdf_outlined, "Dokumen Surat", Colors.red),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text("Buka / Unduh Dokumen Surat",
                                style: GoogleFonts.nunito(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF194CB6),
                              side: const BorderSide(color: Color(0xFF194CB6)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              final fileName =
                                  item['file_path'].toString().split('/').last;
                              html.window.open(
                                  '$_apiUrl/uploads/arsip/$fileName', '_blank');
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF194CB6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text("Tutup",
                          style: GoogleFonts.nunito(
                              fontSize: 14, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _konfirmasiHapusDisposisi(Map<String, dynamic> item) async {
    final idDisposisi =
        int.tryParse(item['id_disposisi'].toString()) ?? 0;
    if (idDisposisi == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("Hapus Disposisi",
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Text(
            "Yakin ingin menghapus disposisi ke '${item['ke_unit'] ?? '-'}'?\n"
            "Tindakan ini tidak dapat dibatalkan.",
            style: GoogleFonts.nunito(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final r = await http.delete(
          Uri.parse('$_apiUrl/api/disposisi/$idDisposisi'));
      if (r.statusCode == 200) {
        final body = json.decode(r.body);
        if (body['success'] == true) {
          _snack("Disposisi berhasil dihapus.");
          _fetchTerkirim();
          return;
        }
      }
      _snack("Gagal menghapus disposisi.");
    } catch (e) {
      _snack("Koneksi gagal: $e");
    }
  }

  // ══════════════════════════════════════════════════════════
  // TAB TERKIRIM
  // ══════════════════════════════════════════════════════════
  Widget _buildTabTerkirim() {
    return Column(children: [
      _toolbar(_searchTerkirimCtrl, "Cari nomor, perihal, ke unit...", _fetchTerkirim),
      Expanded(
        child: _loadingTerkirim
            ? const Center(child: CircularProgressIndicator(color: _kNavy))
            : SingleChildScrollView(
                child: Column(children: [
                  _tableTerkirim(),
                  _buildPagination(
                      current: _pageTerkirim,
                      total: _totalPagesTerkirim,
                      onGo: (p) => setState(() => _pageTerkirim = p)),
                  _footerInfo(_pageTerkirim, _totalPagesTerkirim,
                      _pageDataTerkirim.length, _filteredTerkirim.length),
                ]),
              ),
      ),
    ]);
  }

  Widget _tableTerkirim() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // No(44) + Tgl(140) + NoSurat(178) + KeUnit(155) + Sifat(84) + Status(130) + Aksi(88) = 819
        const double fixedTotal = 44 + 140 + 178 + 155 + 84 + 130 + 88;
        const double perihalMin = 140;
        final double tableMin   = fixedTotal + perihalMin;
        final double tableWidth = constraints.maxWidth > tableMin
            ? constraints.maxWidth
            : tableMin;

        final double perihalWidth = tableWidth - fixedTotal;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Table(
              columnWidths: {
                0: const FixedColumnWidth(44),
                1: const FixedColumnWidth(140),
                2: const FixedColumnWidth(178),
                3: FixedColumnWidth(perihalWidth),
                4: const FixedColumnWidth(155),
                5: const FixedColumnWidth(84),
                6: const FixedColumnWidth(130),
                // ── FIX: minimal 88px agar 2 tombol (28+4+28=60) + padding 16 = 76px muat ──
                7: const FixedColumnWidth(88),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: _kGreen),
                  children: [
                    _thCell("No"),
                    _thCell("Tanggal"),
                    _thCell("Nomor Surat"),
                    _thCell("Perihal"),
                    _thCell("Ke Unit"),
                    _thCell("Sifat"),
                    _thCell("Status"),
                    _thCell("Aksi"),
                  ],
                ),

                if (_pageDataTerkirim.isEmpty)
                  TableRow(
                    decoration: const BoxDecoration(color: Colors.white),
                    children: List.generate(8,
                        (i) => i == 3
                            ? _emptyCell("Belum ada disposisi terkirim")
                            : _emptyCell("")),
                  )
                else
                  ..._pageDataTerkirim.asMap().entries.map((e) {
                    final idx       = e.key;
                    final item      = e.value;
                    final globalIdx = (_pageTerkirim - 1) * _kPageSize + idx;

                    return TableRow(
                      decoration: BoxDecoration(
                        color: globalIdx % 2 == 1 ? _kRowAlt : Colors.white,
                      ),
                      children: [
                        _tdCenter(Text("${globalIdx + 1}",
                            style: GoogleFonts.nunito(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: _kTextMuted))),

                        _tdCenter(Text(item['tanggal_disposisi'] ?? '-',
                            style: GoogleFonts.nunito(fontSize: 12, color: _kTextBody),
                            textAlign: TextAlign.center)),

                        _tdCenter(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: _kGreenLight,
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(item['nomor_surat'] ?? '-',
                              style: GoogleFonts.nunito(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _kGreenDark),
                              textAlign: TextAlign.center),
                        )),

                        _tdLeft(Text(item['perihal'] ?? '-',
                            style: GoogleFonts.nunito(fontSize: 13, color: _kTextBody))),

                        _tdCenter(Text(item['ke_unit'] ?? '-',
                            style: GoogleFonts.nunito(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: _kTextBody),
                            textAlign: TextAlign.center)),

                        _tdCenter(_sifatPill(item['sifat_surat'] ?? 'Biasa')),
                        _tdCenter(_statusPillTerkirim(item['status'] ?? 'baru')),

                        // ── Aksi: 2 tombol dalam Row yang tidak overflow ──
                        _tdCenter(Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _actionBtn(
                              icon: Icons.visibility_outlined,
                              bg: _cBlueBg, fg: const Color(0xFF2563EB),
                              tooltip: "Lihat Detail",
                              onTap: () => _showTerkirimDetailModal(item),
                            ),
                            const SizedBox(width: 4),
                            _actionBtn(
                              icon: Icons.delete_outline_rounded,
                              bg: _cRedBg, fg: _cRedFg,
                              tooltip: "Hapus Disposisi",
                              onTap: () => _konfirmasiHapusDisposisi(item),
                            ),
                          ],
                        )),
                      ],
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════

  Widget _toolbar(
      TextEditingController ctrl, String hint, VoidCallback onRefresh) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder, width: 0.8))),
      child: Row(children: [
        SizedBox(
          width: 300, height: 36,
          child: TextField(
            controller: ctrl,
            style: GoogleFonts.nunito(fontSize: 13, color: _kTextBody),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.nunito(fontSize: 13, color: _kTextMuted),
              prefixIcon: const Icon(Icons.search, color: _kNavy, size: 16),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _kBorder, width: 0.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kNavy, width: 1),
              ),
            ),
          ),
        ),
        const Spacer(),
        Tooltip(
          message: "Refresh",
          child: InkWell(
            onTap: onRefresh,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder, width: 0.8),
              ),
              child: const Icon(Icons.refresh_rounded, color: _kNavy, size: 18),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _headerChip(IconData icon, String label, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.nunito(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _badgeCount(int n, {bool small = false}) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 5 : 7, vertical: small ? 1 : 3),
        decoration: BoxDecoration(
            color: _cRedBg, borderRadius: BorderRadius.circular(20)),
        child: Text("$n",
            style: GoogleFonts.nunito(
                color: _cRedFg,
                fontSize: small ? 10 : 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _sifatPill(String sifat) {
    Color bg; Color fg;
    switch (sifat) {
      case 'Segera' : bg = _cOrangeBg; fg = _cOrangeFg; break;
      case 'Rahasia': bg = _cPurpleBg; fg = _cPurpleFg; break;
      default       : bg = _cGrayBg;   fg = _cGrayFg;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(sifat,
          style: GoogleFonts.nunito(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusPillMasuk(String status) {
    Color bg; Color fg; String label; IconData icon;
    switch (status) {
      case 'baru':
        bg = _cOrangeBg; fg = _cOrangeFg;
        label = "Baru"; icon = Icons.fiber_new_rounded; break;
      case 'dibaca':
        bg = _cBlueBg; fg = _cBlueFg;
        label = "Dibaca"; icon = Icons.mark_email_read_outlined; break;
      case 'ditindaklanjuti':
        bg = _cGreenBg; fg = _cGreenFg;
        label = "Ditindak"; icon = Icons.task_alt_rounded; break;
      default:
        bg = _cGrayBg; fg = _cGrayFg;
        label = status; icon = Icons.circle_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg, size: 12),
        const SizedBox(width: 3),
        Text(label,
            style: GoogleFonts.nunito(
                color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _statusPillTerkirim(String status) {
    Color bg; Color fg; String label;
    switch (status) {
      case 'baru'           : bg = _cOrangeBg; fg = _cOrangeFg; label = "Belum Dibaca"; break;
      case 'dibaca'         : bg = _cBlueBg;   fg = _cBlueFg;   label = "Sudah Dibaca"; break;
      case 'ditindaklanjuti': bg = _cGreenBg;  fg = _cGreenFg;  label = "Ditindaklanjuti"; break;
      default               : bg = _cGrayBg;   fg = _cGrayFg;   label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.nunito(
              color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color bg,
    required Color fg,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: fg, size: 16),
          ),
        ),
      );

  Widget _buildPagination({
    required int current,
    required int total,
    required void Function(int) onGo,
  }) {
    if (total <= 1) return const SizedBox.shrink();
    final pages = <int>{1, total};
    for (int i = current - 1; i <= current + 1; i++) {
      if (i >= 1 && i <= total) pages.add(i);
    }
    final sorted = pages.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pgBtn(icon: Icons.chevron_left, enabled: current > 1,
              onTap: () => onGo(current - 1)),
          const SizedBox(width: 4),
          ...() {
            final ws = <Widget>[];
            int prev = 0;
            for (final p in sorted) {
              if (prev != 0 && p - prev > 1) {
                ws.add(Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text("...",
                        style: GoogleFonts.nunito(
                            color: _kTextMuted, fontSize: 12))));
              }
              final active = p == current;
              ws.add(Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onGo(p),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: active ? _kNavy : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: active ? _kNavy : _kBorder, width: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Text("$p",
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: active ? Colors.white : _kTextBody,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                ),
              ));
              prev = p;
            }
            return ws;
          }(),
          const SizedBox(width: 4),
          _pgBtn(icon: Icons.chevron_right, enabled: current < total,
              onTap: () => onGo(current + 1)),
        ],
      ),
    );
  }

  Widget _pgBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF8FAFC) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kBorder, width: 0.8),
          ),
          child: Icon(icon,
              size: 18, color: enabled ? _kNavy : Colors.grey.shade400),
        ),
      );

  Widget _footerInfo(int current, int total, int shown, int all) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: _kNavyLight,
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, color: _kNavy, size: 13),
          const SizedBox(width: 6),
          Text(
            "Halaman $current dari $total  •  Menampilkan $shown dari $all data",
            style: GoogleFonts.nunito(fontSize: 12, color: _kNavy),
          ),
        ]),
      );

  Widget _thCell(String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        alignment: Alignment.center,
        child: Text(label,
            style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13),
            textAlign: TextAlign.center),
      );

  Widget _tdCenter(Widget child) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Align(alignment: Alignment.center, child: child),
        ),
      );

  Widget _tdLeft(Widget child) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      );

  Widget _emptyCell(String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
        alignment: Alignment.center,
        child: Text(text,
            style: GoogleFonts.nunito(fontSize: 13, color: _kTextMuted)),
      );
}