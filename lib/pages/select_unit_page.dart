import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SelectUnitPage extends StatefulWidget {
  final String unitIds; 
  const SelectUnitPage({super.key, required this.unitIds});

  @override
  State<SelectUnitPage> createState() => _SelectUnitPageState();
}

class _SelectUnitPageState extends State<SelectUnitPage> {
  List<dynamic> filteredUnits = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      // Ambil semua unit dari API yang sudah kamu punya
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/auth/units'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> allUnits = data['data'];
        List<String> allowed = widget.unitIds.split(',');

        setState(() {
          filteredUnits = allUnits.where((u) => allowed.contains(u['id_unit'].toString())).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_rounded, size: 60, color: Color(0xFF194CB6)),
              const SizedBox(height: 20),
              Text(
                "Pilih Unit Kerja",
                style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF194CB6)),
              ),
              const SizedBox(height: 10),
              Text(
                "Silakan pilih unit yang ingin Anda kelola",
                style: GoogleFonts.nunito(color: Colors.grey[600]),
              ),
              const SizedBox(height: 30),
              if (isLoading)
                const CircularProgressIndicator(color: Color(0xFF194CB6))
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredUnits.length,
                  itemBuilder: (context, index) {
                    final unit = filteredUnits[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFDDE3F0)),
                      ),
                      child: ListTile(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt('unit_id', unit['id_unit']);
                          await prefs.setString('nama_unit', unit['nama_unit']);
                          if (!mounted) return;
                          Navigator.pushReplacementNamed(context, '/dashboard_operator');
                        },
                        title: Text(unit['nama_unit'], style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF194CB6)),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}