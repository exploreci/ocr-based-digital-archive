import 'package:flutter/material.dart'; // Tambahkan ini
import 'package:printing/printing.dart'; // Tambahkan jika butuh fungsi cetak
import 'package:pdf/pdf.dart';           // Tambahkan untuk tipe data PdfColor
import 'package:pdf/widgets.dart' as pw; // Tambahkan untuk PDF generator

// HAPUS BARIS INI: part of 'pages/editor_surat_keluar_page.dart';

class PreviewSurat extends StatelessWidget {
  // ... isi kode tetap sama
  final String tanggalLengkap;
  final String nomor;
  final String lampiran;
  final String perihal;
  final List<String> penerima;
  final String kepadaDi;
  final List<dynamic> blocks; // String | List<List<String>>
  final String namaTtd;
  final String jabatanTtd;
  final String nipTtd;
  final List<String> tembusan;

  const PreviewSurat({
    required this.tanggalLengkap,
    required this.nomor,
    required this.lampiran,
    required this.perihal,
    required this.penerima,
    required this.kepadaDi,
    required this.blocks,
    required this.namaTtd,
    required this.jabatanTtd,
    required this.nipTtd,
    required this.tembusan,
  });

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
        fontSize: 11.5, color: Color(0xFF1A1A2E), height: 1.65);
    const labelStyle = TextStyle(fontSize: 11.5, color: Color(0xFF1A1A2E));
    const boldStyle = TextStyle(
        fontSize: 11.5,
        color: Color(0xFF1A1A2E),
        fontWeight: FontWeight.bold);
    const italicStyle = TextStyle(
        fontSize: 11,
        color: Color(0xFF1A1A2E),
        fontStyle: FontStyle.italic);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 842),
      child: Container(
        width: 595,
        padding: const EdgeInsets.fromLTRB(56, 0, 56, 48),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _KopSurat(),
            Container(height: 2.5, color: const Color(0xFF1A1A2E)),
            const SizedBox(height: 2),
            Container(height: 0.8, color: const Color(0xFF1A1A2E)),
            const SizedBox(height: 18),

            // Tanggal
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                tanggalLengkap.isEmpty ? 'Kota, Tanggal' : tanggalLengkap,
                style: bodyStyle,
              ),
            ),
            const SizedBox(height: 14),

            // Nomor / Lampiran / Perihal
            _InfoBaris('Nomor', nomor.isEmpty ? '...' : nomor,
                labelStyle, bodyStyle),
            const SizedBox(height: 3),
            _InfoBaris('Lampiran', lampiran.isEmpty ? '-' : lampiran,
                labelStyle, bodyStyle),
            const SizedBox(height: 3),
            _InfoBaris('Perihal', perihal.isEmpty ? '...' : perihal,
                labelStyle, boldStyle),
            const SizedBox(height: 20),

            // Kepada Yth.
            Text('Kepada Yth.', style: bodyStyle),
            if (penerima.length == 1)
              Text(penerima.first, style: bodyStyle)
            else
              ...penerima.asMap().entries.map(
                    (e) => Text('${e.key + 1}.  ${e.value}',
                        style: bodyStyle),
                  ),
            Text('Di-', style: bodyStyle),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                  kepadaDi.isEmpty ? 'Tempat' : kepadaDi,
                  style: bodyStyle),
            ),
            const SizedBox(height: 20),

            // Salam pembuka
            Text('Dengan hormat,', style: bodyStyle),
            const SizedBox(height: 6),

            // ── Blok-blok konten ────────────────────
            if (blocks.isEmpty)
              Text('[ Isi surat akan muncul di sini ]',
                  style: bodyStyle.copyWith(color: Colors.grey.shade400))
            else
              ...blocks.map((block) {
                if (block is String) {
                  // Blok teks
                  if (block.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('[ Teks kosong ]',
                          style: bodyStyle.copyWith(
                              color: Colors.grey.shade300)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(block,
                        style: bodyStyle,
                        textAlign: TextAlign.justify),
                  );
                } else if (block is Map) {
                  // Blok tabel — format: {'data': List<List<String>>, 'colWidths': List<double>}
                  final tableData = (block['data'] as List)
                      .map((r) => (r as List).map((c) => c.toString()).toList())
                      .toList();
                  final rawWidths = (block['colWidths'] as List)
                      .map((w) => (w as num).toDouble())
                      .toList();
                  if (tableData.isEmpty) return const SizedBox.shrink();

                  // Skala lebar kolom proporsional ke lebar konten A4 (483px)
                  const double a4ContentW = 483.0;
                  final totalW = rawWidths.fold(0.0, (s, w) => s + w);
                  final scaledWidths = rawWidths
                      .map((w) => w / totalW * a4ContentW)
                      .toList();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 4),
                    child: Table(
                      border: TableBorder.all(
                        color: const Color(0xFF1A1A2E),
                        width: 0.6,
                      ),
                      columnWidths: {
                        for (int j = 0; j < scaledWidths.length; j++)
                          j: FixedColumnWidth(scaledWidths[j]),
                      },
                      children: () {
  final int colCount = tableData.isNotEmpty ? tableData[0].length : 0;
  return tableData.asMap().entries.map((entry) {
    final rowIndex = entry.key;
    final List<String> row = List<String>.from(entry.value);
    while (row.length < colCount) row.add('');
    final trimmed = row.take(colCount).toList();
    final isHeader = rowIndex == 0;
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader
            ? const Color.fromARGB(255, 255, 255, 255)
            : (rowIndex.isOdd ? const Color.fromARGB(255, 255, 255, 255) : Colors.white),
      ),
      children: trimmed
          .map((cell) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  cell.isEmpty && isHeader ? ' ' : cell,
                  textAlign: isHeader ? TextAlign.center : TextAlign.left,
                  style: isHeader
                      ? boldStyle.copyWith(fontSize: 10.5)
                      : bodyStyle.copyWith(fontSize: 10.5, height: 1.4),
                ),
              ))
          .toList(),
    );
  }).toList();
}(),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),

            const SizedBox(height: 28),

            // Tanda tangan
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      jabatanTtd.isEmpty
                          ? 'Jabatan,'
                          : jabatanTtd.endsWith(',')
                              ? jabatanTtd
                              : '$jabatanTtd,',
                      style: bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 58),
                    Container(height: 1, color: const Color(0xFF1A1A2E)),
                    const SizedBox(height: 4),
                    Text(
                      namaTtd.isEmpty ? 'Nama Penandatangan' : namaTtd,
                      style: boldStyle,
                      textAlign: TextAlign.center,
                    ),
                    if (nipTtd.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('NIP. $nipTtd',
                          style: bodyStyle.copyWith(fontSize: 10.5),
                          textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),

            // Tembusan
            if (tembusan.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Tembusan:', style: italicStyle),
              ...tembusan.asMap().entries.map((e) => Text(
                    '    ${e.key + 1}. ${e.value}.',
                    style: italicStyle,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Baris info Nomor / Lampiran / Perihal ─────────────────────────────────────

class _InfoBaris extends StatelessWidget {
  final String label, value;
  final TextStyle labelStyle, valueStyle;
  const _InfoBaris(this.label, this.value, this.labelStyle, this.valueStyle);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 64, child: Text(label, style: labelStyle)),
        Text(' :  ', style: labelStyle),
        Expanded(child: Text(value, style: valueStyle)),
      ],
    );
  }
}

// ── Kop Surat Universitas Prabumulih ──────────────────────────────────────────

class _KopSurat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF194CB6), width: 2),
              color: const Color(0xFFE8EDF8),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('UNPRA',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF194CB6))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Text('UNIVERSITAS PRABUMULIH',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: 0.5)),
                SizedBox(height: 3),
                Text(
                  'Jalan Patra No.50 RT.01 RW.03 Kelurahan Sukaraja Kecamatan Prabumulih Selatan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8.5, color: Color(0xFF444444)),
                ),
                Text(
                  'Kota Prabumulih Sumatera Selatan Indonesia Handphone: 081288764755',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8.5, color: Color(0xFF444444)),
                ),
                Text(
                  'e-mail: mail@unpra.ac.id',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 8.5,
                      color: Color(0xFF194CB6),
                      decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PDF GENERATOR — render blocks (teks + tabel) ke dokumen PDF A4
// ══════════════════════════════════════════════════════════════════════════════

class SuratKeluarPdf {
  static Future<void> cetak({
    required String kota,
    required String tanggalFormatted,
    required String nomor,
    required String lampiran,
    required String perihal,
    required List<String> penerima,
    required String kepadaDi,
    required List<dynamic> blocks, // String | List<List<String>>
    required String namaTtd,
    required String jabatanTtd,
    required String nipTtd,
    required List<String> tembusan,
  }) async {
    final pdf = pw.Document();

    const PdfColor hitam  = PdfColor.fromInt(0xFF1A1A2E);
    const PdfColor navy   = PdfColor.fromInt(0xFF194CB6);
    const PdfColor abuAbu = PdfColor.fromInt(0xFF444444);
    const PdfColor biru10 = PdfColor.fromInt(0xFFD6E0F8);
    const PdfColor white   = PdfColor.fromInt(0xFFFFFFFF);

    final jabatanDenganKoma = jabatanTtd.endsWith(',')
        ? jabatanTtd
        : '$jabatanTtd,';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(56, 28, 56, 48),
        build: (pw.Context ctx) {
          final bodyStyle   = pw.TextStyle(fontSize: 10.5, color: hitam, lineSpacing: 3);
          final labelStyle  = pw.TextStyle(fontSize: 10.5, color: hitam);
          final boldStyle   = pw.TextStyle(fontSize: 10.5, color: hitam, fontWeight: pw.FontWeight.bold);
          final italicStyle = pw.TextStyle(fontSize: 10,   color: hitam, fontStyle: pw.FontStyle.italic);
          final cellStyle   = pw.TextStyle(fontSize: 9.5,  color: hitam, lineSpacing: 2);
          final cellBold    = pw.TextStyle(fontSize: 9.5,  color: hitam, fontWeight: pw.FontWeight.bold);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── KOP SURAT ──────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 55, height: 55,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: navy, width: 1.5),
                      color: const PdfColor.fromInt(0xFFE8EDF8),
                    ),
                    child: pw.Center(
                      child: pw.Text('UNPRA',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: navy)),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('UNIVERSITAS PRABUMULIH',
                            style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                color: hitam)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Jalan Patra No.50 RT.01 RW.03 Kelurahan Sukaraja Kecamatan Prabumulih Selatan',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 8, color: abuAbu),
                        ),
                        pw.Text(
                          'Kota Prabumulih Sumatera Selatan Indonesia Handphone: 081288764755',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 8, color: abuAbu),
                        ),
                        pw.Text(
                          'e-mail: mail@unpra.ac.id',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: navy,
                              decoration: pw.TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(height: 2.5, color: hitam),
              pw.SizedBox(height: 1.5),
              pw.Container(height: 0.8, color: hitam),
              pw.SizedBox(height: 18),

              // ── Tanggal ────────────────────────────────
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('$kota, $tanggalFormatted', style: bodyStyle),
              ),
              pw.SizedBox(height: 12),

              // ── Nomor / Lampiran / Perihal ─────────────
              _pdfBaris('Nomor',    nomor,    labelStyle, bodyStyle),
              pw.SizedBox(height: 3),
              _pdfBaris('Lampiran', lampiran.isEmpty ? '-' : lampiran,
                  labelStyle, bodyStyle),
              pw.SizedBox(height: 3),
              _pdfBaris('Perihal',  perihal,  labelStyle, boldStyle),
              pw.SizedBox(height: 18),

              // ── Kepada Yth. ────────────────────────────
              pw.Text('Kepada Yth.', style: bodyStyle),
              if (penerima.length == 1)
                pw.Text(penerima.first, style: bodyStyle)
              else
                ...penerima.asMap().entries.map((e) =>
                    pw.Text('${e.key + 1}.  ${e.value}', style: bodyStyle)),
              pw.Text('Di-', style: bodyStyle),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 24),
                child: pw.Text(
                    kepadaDi.isEmpty ? 'Tempat' : kepadaDi,
                    style: bodyStyle),
              ),
              pw.SizedBox(height: 18),

              // ── Salam pembuka ──────────────────────────
              pw.Text('Dengan hormat,', style: bodyStyle),
              pw.SizedBox(height: 6),

              // ── Blok-blok konten ───────────────────────
              ...blocks.map((block) {
                if (block is String) {
                  if (block.trim().isEmpty) return pw.SizedBox(height: 0);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text(block,
                        textAlign: pw.TextAlign.justify,
                        style: bodyStyle),
                  );
                } else if (block is Map) {
                  // Format: {'data': List<List<String>>, 'colWidths': List<double>}
                  final tableData = (block['data'] as List)
                      .map((r) => (r as List).map((c) => c.toString()).toList())
                      .toList();
                  final rawWidths = (block['colWidths'] as List)
                      .map((w) => (w as num).toDouble())
                      .toList();
                  if (tableData.isEmpty) return pw.SizedBox(height: 0);

                  // A4 content width: 595 - margin 56*2 = 483pt
                  const double a4ContentW = 483.0;
                  final totalW = rawWidths.fold(0.0, (s, w) => s + w);
                  final scaledWidths = rawWidths
                      .map((w) => w / totalW * a4ContentW)
                      .toList();

                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8, top: 4),
                    child: pw.Table(
                      border: pw.TableBorder.all(color: hitam, width: 0.5),
                      columnWidths: {
                        for (int j = 0; j < scaledWidths.length; j++)
                          j: pw.FixedColumnWidth(scaledWidths[j]),
                      },
                      children: () {
  final int colCount = tableData.isNotEmpty ? tableData[0].length : 0;
  return tableData.asMap().entries.map((entry) {
    final rowIndex = entry.key;
    final List<String> row = List<String>.from(entry.value);
    while (row.length < colCount) row.add('');
    final trimmed = row.take(colCount).toList();
    final isHeader = rowIndex == 0;
    return pw.TableRow(         // ← pakai pw.TableRow
      decoration: pw.BoxDecoration(
        color: isHeader ? biru10 : (rowIndex.isOdd ? white : PdfColors.white),
      ),
      children: trimmed
          .map((cell) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: pw.Text(
                  cell,
                  textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
                  style: isHeader ? cellBold : cellStyle,
                ),
              ))
          .toList(),
    );
  }).toList();
}(),
                    ),
                  );
                }
                return pw.SizedBox(height: 0);
              }),

              pw.SizedBox(height: 28),

              // ── Tanda Tangan ───────────────────────────
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.SizedBox(
                  width: 160,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(jabatanDenganKoma,
                          textAlign: pw.TextAlign.center,
                          style: bodyStyle),
                      pw.SizedBox(height: 52),
                      pw.Container(height: 0.5, color: hitam),
                      pw.SizedBox(height: 4),
                      pw.Text(namaTtd,
                          textAlign: pw.TextAlign.center,
                          style: boldStyle),
                      if (nipTtd.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('NIP. $nipTtd',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 9.5, color: hitam)),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Tembusan ───────────────────────────────
              if (tembusan.isNotEmpty) ...[
                pw.SizedBox(height: 28),
                pw.Text('Tembusan:', style: italicStyle),
                ...tembusan.asMap().entries.map((e) =>
                    pw.Text('    ${e.key + 1}. ${e.value}.',
                        style: italicStyle)),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Surat_Keluar_${nomor.replaceAll('/', '-')}.pdf',
    );
  }

  static pw.Widget _pdfBaris(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 58, child: pw.Text(label, style: labelStyle)),
        pw.Text(' :  ', style: labelStyle),
        pw.Expanded(
          child: pw.Text(value.isEmpty ? '-' : value, style: valueStyle),
        ),
      ],
    );
  }
}