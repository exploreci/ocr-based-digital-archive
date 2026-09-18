import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ==========================================
// PDF GENERATOR — LEMBAR DISPOSISI
// Layout mengikuti lembar disposisi manual
// ==========================================
class LembarDisposisiPdf {
  static Future<void> cetak({
    required List<dynamic> listDisposisi,
    String namaInstansi = "UNIVERSITAS PRABUMULIH",
  }) async {
    final pdf = pw.Document();
    final first = listDisposisi.isNotEmpty ? listDisposisi[0] : {};

    // ── Warna tema ──
    const PdfColor navyBlue   = PdfColor.fromInt(0xFF194CB6);
    const PdfColor lightBlue  = PdfColor.fromInt(0xFFE8EDF8);
    const PdfColor borderGrey = PdfColor.fromInt(0xFF999999);
    const PdfColor textDark   = PdfColor.fromInt(0xFF1A1A2E);
    const PdfColor textGrey   = PdfColor.fromInt(0xFF555555);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [

              // ══════════════════════════════════════════
              // BINGKAI LUAR
              // ══════════════════════════════════════════
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: textDark, width: 1.2),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [

                    // ── JUDUL ─────────────────────────────
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: pw.BoxDecoration(
                        color: navyBlue,
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(3),
                          topRight: pw.Radius.circular(3),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            namaInstansi,
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            "LEMBAR DISPOSISI",
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),

                    // ── INFO ATAS — 2 kolom ────────────────
                    pw.Table(
                      border: pw.TableBorder(
                        bottom: pw.BorderSide(color: borderGrey, width: 0.8),
                        verticalInside:
                            pw.BorderSide(color: borderGrey, width: 0.8),
                      ),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1),
                        1: pw.FlexColumnWidth(1),
                      },
                      children: [
                        pw.TableRow(children: [
                          // KIRI
                          pw.Table(
                            border: pw.TableBorder(
                              horizontalInside: pw.BorderSide(
                                  color: borderGrey, width: 0.6),
                            ),
                            columnWidths: const {
                              0: pw.FixedColumnWidth(68),
                              1: pw.FlexColumnWidth(),
                            },
                            children: [
                              _infoRow("Surat dari",
                                  first['asal_surat'] ?? "-",
                                  lightBlue: lightBlue,
                                  textDark: textDark),
                              _infoRow("No. Surat",
                                  first['nomor_surat'] ?? "-",
                                  lightBlue: lightBlue,
                                  textDark: textDark),
                              _infoRow("Tgl. Surat",
                                  first['tanggal_surat'] ?? "-",
                                  lightBlue: lightBlue,
                                  textDark: textDark),
                            ],
                          ),
                          // KANAN
                          pw.Table(
                            border: pw.TableBorder(
                              horizontalInside: pw.BorderSide(
                                  color: borderGrey, width: 0.6),
                            ),
                            columnWidths: const {
                              0: pw.FixedColumnWidth(72),
                              1: pw.FlexColumnWidth(),
                            },
                            children: [
                              _infoRow("Diterima tgl",
                                  first['tanggal_disposisi'] ?? "-",
                                  lightBlue: lightBlue,
                                  textDark: textDark,
                                  valueColor: PdfColors.green,
                                  bold: true),
                              _infoRow("No. Agenda",
                                  first['id_surat']?.toString() ?? "-",
                                  lightBlue: lightBlue,
                                  textDark: textDark),
                              _infoRow("Sifat",
                                  first['sifat_surat'] ?? "Biasa",
                                  lightBlue: lightBlue,
                                  textDark: textDark,
                                  valueColor: _sifatColorPdf(
                                      first['sifat_surat']),
                                  bold: true),
                            ],
                          ),
                        ]),
                      ],
                    ),

                    // ── CHECKBOX SIFAT ─────────────────────
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom:
                              pw.BorderSide(color: borderGrey, width: 0.8),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text("Sifat Surat :  ",
                              style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: textDark)),
                          // Hanya 3 opsi sesuai lembar fisik
                          ...["Biasa", "Segera", "Rahasia"].map((s) {
                            final checked =
                                (first['sifat_surat'] ?? "Biasa") == s;
                            return pw.Row(children: [
                              pw.Container(
                                width: 11,
                                height: 11,
                                margin: const pw.EdgeInsets.only(right: 4),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                      color: checked
                                          ? navyBlue
                                          : borderGrey,
                                      width: 1),
                                  color: checked
                                      ? navyBlue
                                      : PdfColors.white,
                                  borderRadius:
                                      pw.BorderRadius.circular(2),
                                ),
                                child: checked
                                    ? pw.Center(
                                        child: pw.Text("✓",
                                            style: pw.TextStyle(
                                                color: PdfColors.white,
                                                fontSize: 7,
                                                fontWeight:
                                                    pw.FontWeight.bold)))
                                    : null,
                              ),
                              pw.Text(s,
                                  style: pw.TextStyle(
                                      fontSize: 8.5,
                                      color: checked
                                          ? navyBlue
                                          : textGrey,
                                      fontWeight: checked
                                          ? pw.FontWeight.bold
                                          : pw.FontWeight.normal)),
                              pw.SizedBox(width: 18),
                            ]);
                          }),
                        ],
                      ),
                    ),

                    // ── PERIHAL ────────────────────────────
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: pw.BoxDecoration(
                        color: lightBlue,
                        border: pw.Border(
                          bottom:
                              pw.BorderSide(color: borderGrey, width: 0.8),
                        ),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Perihal  :  ",
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: textDark)),
                          pw.Expanded(
                            child: pw.Text(
                              first['perihal'] ?? "-",
                              style: pw.TextStyle(
                                  fontSize: 9, color: textDark),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── TABEL INSTRUKSI DISPOSISI ──────────
                    // Kolom: Dari | Kepada | Keterangan | Paraf
                    // (sesuai lembar fisik)
                    pw.Table(
                      border: pw.TableBorder.all(
                          color: borderGrey, width: 0.8),
                      columnWidths: const {
                        0: pw.FixedColumnWidth(85),   // Dari
                        1: pw.FixedColumnWidth(95),   // Kepada
                        2: pw.FlexColumnWidth(),       // Keterangan
                        3: pw.FixedColumnWidth(55),   // Paraf
                      },
                      children: [
                        // Header tabel
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: navyBlue),
                          children: [
                            _thCell("Dari"),
                            _thCell("Kepada"),
                            _thCell("Keterangan"),
                            _thCell("Paraf"),
                          ],
                        ),

                        // Baris data
                        ...listDisposisi.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final d = entry.value;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                                color: idx % 2 == 0
                                    ? PdfColors.white
                                    : const PdfColor.fromInt(0xFFF0F4FF)),
                            children: [
                              _tdCell(
                                  d['nama_unit_pengirim'] ?? "Rektor",
                                  minHeight: 34),
                              _tdCell(d['nama_unit'] ?? "-",
                                  minHeight: 34),
                              _tdCell(d['isi_disposisi'] ?? "-",
                                  minHeight: 34),
                              _tdCell("", minHeight: 34),
                            ],
                          );
                        }),

                        // Baris kosong pelengkap (minimal 4 baris total)
                        if (listDisposisi.length < 4)
                          ...List.generate(
                              4 - listDisposisi.length,
                              (_) => pw.TableRow(children: [
                                    _tdCell("", minHeight: 34),
                                    _tdCell("", minHeight: 34),
                                    _tdCell("", minHeight: 34),
                                    _tdCell("", minHeight: 34),
                                  ])),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

             

              pw.SizedBox(height: 10),
              pw.Divider(
                  color: const PdfColor.fromInt(0xFFCCCCCC),
                  thickness: 0.5),
              pw.SizedBox(height: 3),
              pw.Text(
                "Dokumen ini dicetak secara otomatis oleh Sistem Informasi Arsip Digital $namaInstansi",
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 7,
                    color: const PdfColor.fromInt(0xFF999999),
                    fontStyle: pw.FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
          'Lembar_Disposisi_${first['nomor_surat']?.toString().replaceAll('/', '-') ?? 'dokumen'}.pdf',
    );
  }

  // ── Warna sifat untuk PDF ──
  static PdfColor _sifatColorPdf(String? s) {
    switch (s) {
      case "Segera":  return PdfColors.orange;
      case "Penting": return PdfColors.red;
      case "Rahasia": return PdfColors.purple;
      default:        return const PdfColor.fromInt(0xFF1A1A2E);
    }
  }

  // ── Baris info (label | value) ──
  static pw.TableRow _infoRow(
    String label,
    String value, {
    required PdfColor lightBlue,
    required PdfColor textDark,
    PdfColor? valueColor,
    bool bold = false,
  }) {
    return pw.TableRow(children: [
      pw.Container(
        color: lightBlue,
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(label,
            style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: textDark)),
      ),
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(value,
            style: pw.TextStyle(
                fontSize: 8.5,
                color: valueColor ?? textDark,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
    ]);
  }

  // ── Sel header tabel ──
  static pw.Widget _thCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  // ── Sel data tabel ──
  static pw.Widget _tdCell(String text,
      {bool center = false, double minHeight = 28}) {
    return pw.Container(
      constraints: pw.BoxConstraints(minHeight: minHeight),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: const pw.TextStyle(fontSize: 8.5),
      ),
    );
  }
}