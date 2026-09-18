class ArsipMasuk {
  final int id;
  final String tanggal;
  final String nomor;
  final String asal;
  final String perihal;
  final String id_disposisi; // Path ke file PDF
  final String status; // 'Belum Disposisi' atau 'Terdisposisi'

  ArsipMasuk({
    required this.id,
    required this.tanggal,
    required this.nomor,
    required this.asal,
    required this.perihal,
    required this.id_disposisi,
    required this.status,
  });
}