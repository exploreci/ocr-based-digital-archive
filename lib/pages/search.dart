// search_delegate.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArsipSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> allMasuk;
  final List<dynamic> allKeluar;

  ArsipSearchDelegate({
    required this.allMasuk,
    required this.allKeluar,
  });

  // ── Tombol X untuk clear ──
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => query = '',
        ),
    ];
  }

  // ── Tombol back di kiri ──
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  // ── Hasil pencarian ──
  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  bool _matches(dynamic item, String q) {
    return (item['nomor_surat'] ?? '').toLowerCase().contains(q) ||
        (item['perihal'] ?? '').toLowerCase().contains(q) ||
        (item['asal_surat'] ?? '').toLowerCase().contains(q) ||
        (item['tujuan_surat'] ?? '').toLowerCase().contains(q);
  }

  String _formatTanggal(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    const bulan = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    try {
      final d = DateTime.parse(raw);
      return "${d.day} ${bulan[d.month]} ${d.year}";
    } catch (_) {
      return raw;
    }
  }

  Widget _buildSearchResults(BuildContext context) {
    final q = query.trim().toLowerCase();

    // Kalau belum ketik apa-apa → tampilkan hint
    if (q.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "Ketik nomor surat, perihal,\natau asal/tujuan surat",
              style: GoogleFonts.nunito(
                  fontSize: 15, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final hasilMasuk =
        allMasuk.where((item) => _matches(item, q)).toList();
    final hasilKeluar =
        allKeluar.where((item) => _matches(item, q)).toList();

    // Tidak ada hasil sama sekali
    if (hasilMasuk.isEmpty && hasilKeluar.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "Tidak ada arsip yang cocok\ndengan \"$query\"",
              style: GoogleFonts.nunito(
                  fontSize: 15, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      children: [
        // ── SURAT MASUK ──
        if (hasilMasuk.isNotEmpty) ...[
          _groupHeader(
            label: "Surat Masuk",
            count: hasilMasuk.length,
            color: Colors.blue.shade700,
            icon: Icons.move_to_inbox,
          ),
          const SizedBox(height: 8),
          ...hasilMasuk.map((item) => _buildCard(
                context: context,
                item: item,
                jenis: 'masuk',
                namaLawan: item['asal_surat'] ?? '-',
                labelLawan: "Dari",
                badgeColor: Colors.blue.shade50,
                badgeBorderColor: Colors.blue.shade200,
                badgeTextColor: Colors.blue.shade800,
                route: '/arsip-surat-masuk',
              )),
          const SizedBox(height: 20),
        ],

        // ── SURAT KELUAR ──
        if (hasilKeluar.isNotEmpty) ...[
          _groupHeader(
            label: "Surat Keluar",
            count: hasilKeluar.length,
            color: Colors.green.shade700,
            icon: Icons.send_rounded,
          ),
          const SizedBox(height: 8),
          ...hasilKeluar.map((item) => _buildCard(
                context: context,
                item: item,
                jenis: 'keluar',
                namaLawan: item['tujuan_surat'] ?? '-',
                labelLawan: "Kepada",
                badgeColor: Colors.green.shade50,
                badgeBorderColor: Colors.green.shade200,
                badgeTextColor: Colors.green.shade800,
                route: '/arsip-surat-keluar',
              )),
        ],
      ],
    );
  }

  Widget _groupHeader({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count hasil",
            style: GoogleFonts.nunito(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required Map<String, dynamic> item,
    required String jenis,
    required String namaLawan,
    required String labelLawan,
    required Color badgeColor,
    required Color badgeBorderColor,
    required Color badgeTextColor,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          close(context, '');
          Navigator.pushNamed(context, route);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Info surat ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nomor_surat'] ?? '-',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['perihal'] ?? '-',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatTanggal(item['tanggal_surat']?.toString()),
                          style: GoogleFonts.nunito(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.person_outline,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "$labelLawan: $namaLawan",
                            style: GoogleFonts.nunito(
                                fontSize: 12, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Badge jenis ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeBorderColor),
                ),
                child: Text(
                  jenis == 'masuk' ? "Masuk" : "Keluar",
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}