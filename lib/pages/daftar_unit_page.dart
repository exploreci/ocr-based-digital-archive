import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:arsipdigital_web/main_layout.dart';

class DaftarUnitPage extends StatefulWidget {
  const DaftarUnitPage({super.key});

  @override
  State<DaftarUnitPage> createState() => _DaftarUnitPageState();
}

class _DaftarUnitPageState extends State<DaftarUnitPage> {
  final String apiUrl = "http://127.0.0.1:8000";
  List<dynamic> dataUnit = [];
  List<dynamic> filteredData = [];
  bool isLoading = true;
  TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUnits();
  }

  // --- 1. AMBIL DATA ---
  Future<void> fetchUnits() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$apiUrl/api/unit'));
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        setState(() {
          dataUnit = res['data'] ?? [];
          filteredData = dataUnit; // Reset filter saat fetch ulang
          isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar("Gagal mengambil data: $e");
      setState(() => isLoading = false);
    }
  }

  // --- 2. LOGIKA SEARCH ---
  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredData = dataUnit;
      } else {
        filteredData = dataUnit.where((unit) {
          final name = (unit['nama_unit'] ?? "").toString().toLowerCase();
          final desc = (unit['deskripsi'] ?? "").toString().toLowerCase();
          return name.contains(query.toLowerCase()) || desc.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  // --- 3. CRUD FUNCTIONS (Simpan, Update, Hapus) ---
  Future<void> _prosesSimpanUnit(String nama, String deskripsi) async {
    if (nama.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/unit'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"nama_unit": nama, "deskripsi": deskripsi}),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context);
        fetchUnits();
        _showSnackBar("Unit berhasil ditambahkan");
      }
    } catch (e) {
      _showSnackBar("Gagal menyimpan unit");
    }
  }

  Future<void> _toggleStatusUnit(int id, int status) async {
    try {
      var currentItem = dataUnit.firstWhere((x) => x['id_unit'] == id);
      await http.put(
        Uri.parse('$apiUrl/api/unit/$id'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "is_activate": status,
          "nama_unit": currentItem['nama_unit'],
          "deskripsi": currentItem['deskripsi'],
        }),
      );
      fetchUnits();
    } catch (e) {
      _showSnackBar("Gagal mengubah status");
    }
  }

  Future<void> _hapusUnit(int id) async {
    try {
      final response = await http.delete(Uri.parse('$apiUrl/api/unit/$id'));
      if (response.statusCode == 200) {
        fetchUnits();
        _showSnackBar("Unit telah dihapus");
      }
    } catch (e) {
      _showSnackBar("Gagal menghapus data");
    }
  }

  // --- 4. DIALOGS ---
  void _showAddDialog() {
    TextEditingController unitCtrl = TextEditingController();
    TextEditingController descCtrl = TextEditingController();
    _showFormDialog(title: "Tambah Unit", unitCtrl: unitCtrl, descCtrl: descCtrl, onSave: () => _prosesSimpanUnit(unitCtrl.text, descCtrl.text));
  }

  void _showEditDialog(dynamic item) {
    TextEditingController unitCtrl = TextEditingController(text: item['nama_unit']);
    TextEditingController descCtrl = TextEditingController(text: item['deskripsi']);
    _showFormDialog(
      title: "Edit Unit",
      unitCtrl: unitCtrl,
      descCtrl: descCtrl,
      onSave: () async {
        final response = await http.put(
          Uri.parse('$apiUrl/api/unit/${item['id_unit']}'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({"nama_unit": unitCtrl.text, "deskripsi": descCtrl.text, "is_activate": item['is_activate']}),
        );
        if (response.statusCode == 200) {
          Navigator.pop(context);
          fetchUnits();
          _showSnackBar("Unit diperbarui");
        }
      },
    );
  }

  void _showFormDialog({required String title, required TextEditingController unitCtrl, required TextEditingController descCtrl, required VoidCallback onSave}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: "Nama Unit")),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Deskripsi"), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(onPressed: onSave, child: const Text("Simpan")),
        ],
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Hapus"),
        content: const Text("Hapus unit ini secara permanen?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _hapusUnit(id); }, child: const Text("Hapus"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Manajemen Unit",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Center(
              child: Text(
                "DAFTAR UNIT KERJA",
                style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: _filterSearch,
                    decoration: InputDecoration(
                      hintText: "Cari Nama Unit...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Tambah Unit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
            isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator()))
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: Theme(
                      data: Theme.of(context).copyWith(cardTheme: const CardThemeData(elevation: 0)),
                      child: 
                      PaginatedDataTable(
                        columns: const [
                          DataColumn(label: Text("No", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Nama Unit", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Deskripsi", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Aksi", style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        // PROTEKSI 1: Pastikan source selalu dapat list, minimal list kosong
                        source: UnitDataSource(
                          filteredData, 
                          context, 
                          _toggleStatusUnit, 
                          _showEditDialog, 
                          _confirmDelete
                        ),
                        // PROTEKSI 2: Jangan pakai .isEmpty langsung di sini jika ragu
                        // Kita pakai perbandingan length saja yang lebih stabil di JS/Web
                        rowsPerPage: (filteredData.length < 1) 
                            ? 1 
                            : (filteredData.length < 10 ? filteredData.length : 10),
                        columnSpacing: 20,
                        horizontalMargin: 20,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class UnitDataSource extends DataTableSource {
  final List<dynamic> data;
  final BuildContext context;
  final Function toggleStatus;
  final Function editAction;
  final Function deleteAction;

  UnitDataSource(List<dynamic>? inputData, this.context, this.toggleStatus, this.editAction, this.deleteAction) : data = inputData ?? [];

  @override
  DataRow? getRow(int index) {
    if (data.isEmpty || index >= data.length) return null;
    var item = data[index];
    return DataRow(cells: [
      DataCell(Text("${index + 1}")),
      DataCell(Text(item['nama_unit'] ?? "-")),
      DataCell(SizedBox(width: 300, child: Text(item['deskripsi'] ?? "-", overflow: TextOverflow.ellipsis))),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 0.7,
            child: Switch(value: item['is_activate'] == 1, onChanged: (v) => toggleStatus(item['id_unit'], v ? 1 : 0)),
          ),
          IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 18), onPressed: () => editAction(item)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => deleteAction(item['id_unit'])),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => data.length;
  @override
  int get selectedRowCount => 0;
}