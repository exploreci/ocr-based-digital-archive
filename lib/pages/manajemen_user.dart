import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:arsipdigital_web/main_layout.dart';

class ManajemenUserPage extends StatefulWidget {
  const ManajemenUserPage({super.key});

  @override
  State<ManajemenUserPage> createState() => _ManajemenUserPageState();
}

class _ManajemenUserPageState extends State<ManajemenUserPage> {
  // --- DATA STATE ---
  List<dynamic> _allUsers = [];      // Master data asli dari database
  List<dynamic> _filteredUsers = []; // Data yang sudah difilter (pencarian/role)
  List<dynamic> roles = [];
  List<dynamic> units = [];
  bool isLoading = true;

  // --- FILTER & PAGINATION STATE ---
  final TextEditingController _searchController = TextEditingController();
  String _filterRole = 'Semua Role';
  int _currentPage = 1;
  final int _rowsPerPage = 10;

  // --- FORM CONTROLLERS ---
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  int? _selectedIdRole;
  int? _selectedIdUnit;

  // --- MULTI UNIT STATE ---
  bool _isMultiUnit = false;                  // Toggle aktif/tidak
  List<int> _selectedUnitAkses = [];          // List ID unit yang dicentang

  // Endpoint API (Sesuai dengan backend FastAPI)
  final String apiUrl = "http://127.0.0.1:8000/auth";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Listener untuk pencarian otomatis saat mengetik
    _searchController.addListener(_runFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usernameController.dispose();
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC: FILTERING & SEARCHING
  // ==========================================
  void _runFilter() {
    List<dynamic> results = [];
    String query = _searchController.text.toLowerCase();

    results = _allUsers.where((user) {
      final userName = (user['username'] ?? '').toString().toLowerCase();
      final fullName = (user['nama_lengkap'] ?? '').toString().toLowerCase();
      final userRole = (user['role'] ?? '').toString();

      // Logika: Cocok dengan Nama/User AND Cocok dengan Role
      bool matchesSearch = userName.contains(query) || fullName.contains(query);
      bool matchesRole = (_filterRole == 'Semua Role') || (userRole == _filterRole);

      return matchesSearch && matchesRole;
    }).toList();

    setState(() {
      _filteredUsers = results;
      _currentPage = 1; // Kembali ke halaman 1 setiap kali filter berubah
    });
  }

  // ==========================================
  // LOGIC: API CALLS
  // ==========================================
  Future<void> _loadInitialData() async {
    // Cek mounted sebelum set isLoading
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      await Future.wait([fetchUsers(), fetchRolesAndUnits()]);
    } catch (e) {
      debugPrint("Error Load Data: $e");
    } finally {
      // --- FIX: Cek mounted di finally sebelum setState ---
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> fetchUsers() async {
  try {
    final response = await http.get(Uri.parse('$apiUrl/users'));
    
    // --- FIX: Cek mounted sebelum setState ---
    if (!mounted) return;
    
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      List<dynamic> data = decoded['data'] ?? [];

      data.sort((a, b) {
        var idA = a['id_user'] ?? 0;
        var idB = b['id_user'] ?? 0;
        return int.parse(idA.toString()).compareTo(int.parse(idB.toString()));
      });

      // mounted sudah dicek di atas, aman untuk setState
      setState(() {
        _allUsers = data;
        _filteredUsers = data;
        isLoading = false;
      });
    }
  } catch (e) {
    debugPrint("Error Sort/Fetch: $e");
    if (!mounted) return; // --- FIX: Cek mounted sebelum fallback ---
    fetchUsersTanpaSort();
  }
}

Future<void> fetchUsersTanpaSort() async {
  try {
    final response = await http.get(Uri.parse('$apiUrl/users'));
    
    // --- FIX: Cek mounted sebelum setState ---
    if (!mounted) return;
    
    if (response.statusCode == 200) {
      setState(() {
        _allUsers = json.decode(response.body)['data'] ?? [];
        _filteredUsers = _allUsers;
        isLoading = false;
      });
    }
  } catch (e) {
    debugPrint("Error fetchUsersTanpaSort: $e");
  }
}


  Future<void> fetchRolesAndUnits() async {
    try {
      final resRole = await http.get(Uri.parse('$apiUrl/roles'));
      final resUnit = await http.get(Uri.parse('$apiUrl/units'));
      
      // --- FIX: Cek mounted setelah semua await selesai ---
      if (!mounted) return;
      
      if (resRole.statusCode == 200 && resUnit.statusCode == 200) {
        setState(() {
          roles = json.decode(resRole.body)['data'] ?? [];
          units = json.decode(resUnit.body)['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetchRolesAndUnits: $e");
    }
  }

  Future<void> deleteUser(String username) async {
    bool? confirm = await _showConfirmDialog("Hapus User", "Yakin ingin menghapus user $username?");
    if (confirm == true) {
      final response = await http.delete(Uri.parse('$apiUrl/users/$username'));
      if (response.statusCode == 200) {
        fetchUsers();
        _showNotif("User berhasil dihapus", Colors.blueGrey);
      }
    }
  }

  // ==========================================
  // UI BUILDER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    // Perhitungan Data per Halaman
    // Cari bagian ini di dalam Widget build, lalu ganti jadi begini:

final int startIndex = (_currentPage - 1) * _rowsPerPage;
    
// Pastikan filteredUsers tidak null dan tidak kosong sebelum di-sublist
final List<dynamic> currentDisplayData = (_filteredUsers.isEmpty) 
    ? [] 
    : _filteredUsers.sublist(
        startIndex, 
        (startIndex + _rowsPerPage > _filteredUsers.length) 
            ? _filteredUsers.length 
            : startIndex + _rowsPerPage
      );

    return MainLayout(
      title: "Sistem Informasi Penyimpanan Arsip",
      showHamburger: true,
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      "Manajemen User",
                      style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),
                    
                    Container(
                      width: 1100,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildTopActions(),
                          const SizedBox(height: 25),
                          _buildTableSection(currentDisplayData, startIndex),
                          const SizedBox(height: 25),
                          // Pagination hanya tampil jika total data filter > 10
                          if (_filteredUsers.length > _rowsPerPage) _buildPagination(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Cari username atau nama...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterRole,
                isExpanded: true,
                items: ['Semua Role', 'administrator', 'operator', 'pimpinan']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (val) {
                  setState(() => _filterRole = val!);
                  _runFilter();
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: showAddUserDialog,
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: Text("Tambah User", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B71CA),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildTableSection(List<dynamic> displayData, int offset) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
          dataRowHeight: 60,
          columns: const [
            DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: List.generate(displayData.length, (index) {
            final user = displayData[index];
            return DataRow(cells: [
              DataCell(Text('${offset + index + 1}')),
              DataCell(Text(user['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(user['email'] ?? '')),
              DataCell(Text(user['nama_lengkap'] ?? '')),
              DataCell(_buildRoleBadge(user['role'] ?? '')),
              DataCell(Text(user['unit'] ?? '-')),
              DataCell(Row(
                children: [
                  IconButton(icon: const Icon(Icons.edit_square, color: Color(0xFF194CB6)), onPressed: () => showEditUserDialog(user)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => deleteUser(user['username'])),
                ],
              )),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    int totalPages = (_filteredUsers.length / _rowsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
        ),
        const SizedBox(width: 10),
        // Menghasilkan tombol angka halaman
        ...List.generate(totalPages, (index) {
          int pageNum = index + 1;
          bool isSelected = _currentPage == pageNum;
          return InkWell(
            onTap: () => setState(() => _currentPage = pageNum),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3B71CA) : Colors.transparent,
                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "$pageNum",
                style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            ),
          );
        }),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
        ),
      ],
    );
  }

  // ==========================================
  // DIALOGS & HELPERS
  // ==========================================

  Widget _buildRoleBadge(String role) {
    bool isAdmin = role.toLowerCase().contains("admin");
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(color: isAdmin ? Colors.blue.shade700 : Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  // void showAddUserDialog() {
  //   _clearControllers();
  //   _isMultiUnit = false;
  //   _selectedUnitAkses = [];
  //   _selectedIdRole = null;
  //   _selectedIdUnit = null;
  //   _showFormDialog(title: "Tambah User Baru", isEdit: false);
  // }

  void showEditUserDialog(Map<String, dynamic> user) {
  _usernameController.text = user['username'] ?? '';
  _namaController.text = user['nama_lengkap'] ?? '';
  _emailController.text = user['email'] ?? '';
  _passwordController.text = '';
  _selectedIdRole = user['id_role'];
  _selectedIdUnit = user['id_unit'];

  // --- FIX: Parse id_unit_akses dengan benar ---
  // Database bisa kirim: null, integer tunggal (3), atau string "1,2,3"
  final dynamic rawAkses = user['id_unit_akses'];
  bool initMultiUnit = false;
  List<int> initUnitAkses = [];

  if (rawAkses != null) {
    final String strAkses = rawAkses.toString().trim();
    if (strAkses.isNotEmpty) {
      // Coba parse sebagai list (ada koma atau bisa jadi angka tunggal)
      final parts = strAkses.split(',')
          .map((e) => int.tryParse(e.trim()))
          .where((e) => e != null && e! > 0)
          .cast<int>()
          .toList();
      if (parts.isNotEmpty) {
        initUnitAkses = parts;
        // Multi-unit aktif jika ada lebih dari 1, atau jika memang 
        // field ini sengaja diisi (artinya fitur multi-unit sedang dipakai)
        initMultiUnit = true;
      }
    }
  }

  _showFormDialog(
    title: "Edit Detail User",
    isEdit: true,
    initMultiUnit: initMultiUnit,
    initUnitAkses: initUnitAkses,
  );
}

void showAddUserDialog() {
  _clearControllers();
  _selectedIdRole = null;
  _selectedIdUnit = null;
  _showFormDialog(
    title: "Tambah User Baru",
    isEdit: false,
    initMultiUnit: false,
    initUnitAkses: [],
  );
}

 void _showFormDialog({
  required String title,
  required bool isEdit,
  required bool initMultiUnit,
  required List<int> initUnitAkses,
}) {
  // --- FIX: State lokal di sini, bukan di widget utama ---
  // Dengan begini StatefulBuilder pasti pakai nilai yang benar
  bool localMultiUnit = initMultiUnit;
  List<int> localUnitAkses = List<int>.from(initUnitAkses);

  bool isOperatorRole(int? idRole) {
    if (idRole == null) return false;
    final found = roles.firstWhere(
      (r) => r['id_role'].toString() == idRole.toString(),
      orElse: () => null,
    );
    return found != null &&
        (found['nama_role'] as String).toLowerCase().contains('operator');
  }

  // Juga perlu state lokal untuk role dan unit agar dropdown sync
  int? localIdRole = _selectedIdRole;
  int? localIdUnit = _selectedIdUnit;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_usernameController, "Username", Icons.person,
                    enabled: !isEdit),
                const SizedBox(height: 12),
                _buildTextField(_namaController, "Nama Lengkap", Icons.badge),
                const SizedBox(height: 12),
                _buildTextField(_emailController, "Email", Icons.email),
                const SizedBox(height: 12),
                _buildTextField(
                  _passwordController,
                  isEdit ? "Password Baru (Opsional)" : "Password",
                  Icons.lock,
                  obscure: true,
                ),
                const SizedBox(height: 20),

                // Dropdown Role
                _buildDropdown(
                  "Role", roles, localIdRole, "id_role", "nama_role",
                  (v) {
                    setStateDialog(() {
                      localIdRole = v;
                      _selectedIdRole = v;
                      // Reset multi-unit jika bukan operator
                      if (!isOperatorRole(v)) {
                        localMultiUnit = false;
                        localUnitAkses = [];
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Dropdown Unit Utama
                _buildDropdown(
                  "Unit Utama", units, localIdUnit, "id_unit", "nama_unit",
                  (v) => setStateDialog(() {
                    localIdUnit = v;
                    _selectedIdUnit = v;
                  }),
                ),
                const SizedBox(height: 16),

                // Toggle multi-unit — hanya untuk operator
                if (isOperatorRole(localIdRole)) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: localMultiUnit
                          ? const Color(0xFFEBF0FF)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: localMultiUnit
                            ? const Color(0xFF194CB6)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_tree_outlined,
                            size: 18, color: Color(0xFF194CB6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Kelola Lebih dari 1 Unit",
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              Text(
                                "Aktifkan jika operator ini mengelola beberapa unit",
                                style: GoogleFonts.nunito(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: localMultiUnit,
                          activeColor: const Color(0xFF194CB6),
                          onChanged: (val) => setStateDialog(() {
                            localMultiUnit = val;
                            if (!val) localUnitAkses = [];
                          }),
                        ),
                      ],
                    ),
                  ),

                  // Checkbox list unit
                  if (localMultiUnit) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.checklist_rounded,
                                  size: 16, color: Color(0xFF194CB6)),
                              const SizedBox(width: 6),
                              Text(
                                "Pilih Unit yang Bisa Diakses",
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: const Color(0xFF194CB6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          ...units.map((unit) {
                            final int unitId =
                                int.parse(unit['id_unit'].toString());
                            // --- FIX: Pakai localUnitAkses, bukan _selectedUnitAkses ---
                            final bool isChecked =
                                localUnitAkses.contains(unitId);
                            return InkWell(
                              onTap: () => setStateDialog(() {
                                if (isChecked) {
                                  localUnitAkses.remove(unitId);
                                } else {
                                  localUnitAkses.add(unitId);
                                }
                              }),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 4),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isChecked,
                                      activeColor: const Color(0xFF194CB6),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (val) =>
                                          setStateDialog(() {
                                        if (val == true) {
                                          localUnitAkses.add(unitId);
                                        } else {
                                          localUnitAkses.remove(unitId);
                                        }
                                      }),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        unit['nama_unit'] ?? '-',
                                        style:
                                            GoogleFonts.nunito(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),

                          if (localUnitAkses.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            Text(
                              "Akan disimpan: ${localUnitAkses.join(',')}",
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF194CB6)),
            // --- FIX: Kirim localMultiUnit dan localUnitAkses ke submit ---
            onPressed: () =>
                _handleFormSubmit(isEdit, localMultiUnit, localUnitAkses),
            child: Text(
              isEdit ? "Simpan Perubahan" : "Daftar User",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}   

  void _handleFormSubmit(
  bool isEdit,
  bool localMultiUnit,     // <-- Tambahan parameter
  List<int> localUnitAkses, // <-- Tambahan parameter
) async {
  // Validasi password jika diisi (wajib diisi saat tambah, opsional saat edit)
  final password = _passwordController.text;
  if (!isEdit || password.isNotEmpty) {
    final String? errMsg = _validatePassword(password);
    if (errMsg != null) {
      _showNotif(errMsg, Colors.red);
      return;
    }
  }
  // --- FIX: Pakai parameter lokal, bukan state widget utama ---
  String? idUnitAkses;
  if (localMultiUnit && localUnitAkses.isNotEmpty) {
    idUnitAkses = localUnitAkses.join(',');
  }

  Map<String, dynamic> data = {
    "username": _usernameController.text,
    "nama_lengkap": _namaController.text,
    "email": _emailController.text,
    "password": _passwordController.text,
    "id_role": _selectedIdRole,
    "id_unit": _selectedIdUnit,
    "id_unit_akses": idUnitAkses,
  };

  final url = isEdit
      ? '$apiUrl/users/${_usernameController.text}'
      : '$apiUrl/register';
  final response = isEdit
      ? await http.put(Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: json.encode(data))
      : await http.post(Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: json.encode(data));

  if (response.statusCode == 200) {
    fetchUsers();
    Navigator.pop(context);
    _showNotif(
      isEdit ? "Data berhasil diperbarui" : "User berhasil didaftarkan",
      Colors.green,
    );
  } else {
    _showNotif("Terjadi kesalahan. Silakan cek inputan.", Colors.red);
  }
}

  Widget _buildTextField(TextEditingController c, String l, IconData i, {bool obscure = false, bool enabled = true}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: l,
        prefixIcon: Icon(i, size: 20),
        filled: !enabled,
        fillColor: enabled ? Colors.transparent : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDropdown(String label, List items, int? currentVal, String idKey, String nameKey, Function(int?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        DropdownButtonFormField<int>(
          value: currentVal,
          isExpanded: true,
          items: items.map((item) => DropdownMenuItem<int>(
            value: int.parse(item[idKey].toString()), 
            child: Text(item[nameKey] ?? '-')
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showNotif(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Hapus", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  void _clearControllers() {
    _usernameController.clear();
    _namaController.clear();
    _emailController.clear();
    _passwordController.clear();
  }

  /// Validasi aturan keamanan password.
  /// Mengembalikan pesan error jika tidak valid, null jika valid.
  String? _validatePassword(String password) {
    if (password.isEmpty) return "Password wajib diisi!";
    if (password.length < 8) return "Password minimal 8 karakter!";
    if (!RegExp(r'[A-Z]').hasMatch(password)) return "Password harus mengandung minimal 1 huruf besar!";
    if (!RegExp(r'[a-z]').hasMatch(password)) return "Password harus mengandung minimal 1 huruf kecil!";
    if (!RegExp(r'[0-9]').hasMatch(password)) return "Password harus mengandung minimal 1 angka!";
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return "Password harus mengandung minimal 1 simbol (contoh: @, #, !, _)!";
    return null;
  }
}