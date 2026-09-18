import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/user_session.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final bool showHamburger;

  const MainLayout({
    super.key,
    required this.child,
    this.title = "Sistem Informasi Penyimpanan Arsip",
    this.showHamburger = true,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static const _apiUrl = "http://127.0.0.1:8000";
  int _jumlahBaru = 0;

  @override
  void initState() {
    super.initState();
    _fetchBadge();
  }

  Future<void> _fetchBadge() async {
    final role = UserSession.role.toLowerCase();
    if (!role.contains("pimpinan") && !role.contains("operator")) return;
    final unitId = UserSession.unitId;
    if (unitId <= 0) return;
    try {
      final r = await http.get(Uri.parse(
          '$_apiUrl/api/disposisi/masuk/jumlah?id_unit=$unitId'));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['success'] == true && mounted) {
          setState(() => _jumlahBaru = d['jumlah_baru'] ?? 0);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final Color blueHeader = const Color(0xFF194CB6);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: widget.showHamburger ? _buildSidebar(context, blueHeader) : null,
      appBar: AppBar(
        backgroundColor: blueHeader,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: widget.showHamburger,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _buildAppBarTitle(),
        actions: [
          if (UserSession.role.toLowerCase().contains("pimpinan") ||
              UserSession.role.toLowerCase().contains("operator"))
            _buildInboxIcon(context),
          _buildUserDropdown(context),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: widget.child),
          _buildFooter(blueHeader),
        ],
      ),
    );
  }

  // ── Inbox Icon + Badge ───────────────────────────────────
  Widget _buildInboxIcon(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: "Inbox Disposisi",
            icon: const Icon(Icons.inbox_rounded,
                color: Colors.white, size: 26),
            onPressed: () async {
              await Navigator.pushNamed(context, '/inbox-disposisi');
              _fetchBadge();
            },
          ),
          if (_jumlahBaru > 0)
            Positioned(
              top: 8,
              right: 6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                      minWidth: 17, minHeight: 17),
                  child: Text(
                    _jumlahBaru > 99 ? "99+" : "$_jumlahBaru",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // APP BAR
  // ════════════════════════════════════════════════════════════
  Widget _buildAppBarTitle() {
    return Row(
      children: [
        const CircleAvatar(
          backgroundColor: Colors.transparent,
          radius: 16,
          child: Image(
            image: AssetImage("assets/logo.png"),
            width: 35,
            height: 35,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Text(
              "Universitas Prabumulih",
              style: GoogleFonts.nunito(
                  fontSize: 13, color: Colors.white.withOpacity(0.8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserDropdown(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showProfilePopover(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.account_circle,
                  color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    UserSession.name,
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    UserSession.role,
                    style: GoogleFonts.nunito(
                        color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfilePopover(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    showMenu(
      context: context,
      color: Colors.transparent,
      elevation: 0,
      position: RelativeRect.fromLTRB(
        screenSize.width - 320,
        kToolbarHeight,
        20,
        0,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _buildPopoverContent(context),
        ),
      ],
    );
  }

  Widget _buildPopoverContent(BuildContext context) {
    const blueHeader = Color(0xFF194CB6);
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header biru ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              color: blueHeader,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person,
                      size: 38, color: blueHeader),
                ),
                const SizedBox(height: 10),
                Text(
                  UserSession.name,
                  style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  UserSession.role,
                  style: GoogleFonts.nunito(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // ── Info rows ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                _profileRow(Icons.badge_outlined, "Username",
                    UserSession.username),
                _profileRow(
                    Icons.email_outlined, "Email", UserSession.email),
                _profileRow(Icons.account_balance_outlined, "Unit",
                    UserSession.unit),
                _profileRow(
                    Icons.security_outlined, "Role", UserSession.role),
              ],
            ),
          ),

          // ── Tombol ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                const Divider(height: 16),

                // Reset Password — buka dialog yang benar
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // tutup popover dulu
                      // ✅ Pakai showDialog dengan widget terpisah
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            const _ResetPasswordDialog(),
                      );
                    },
                    icon: const Icon(Icons.lock_reset,
                        size: 18, color: blueHeader),
                    label: Text(
                      "Reset Password",
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: blueHeader),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: blueHeader),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Keluar
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      UserSession.clearSession();
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (route) => false);
                    },
                    icon: const Icon(Icons.logout,
                        size: 18, color: Colors.white),
                    label: Text(
                      "Keluar",
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(
      IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.3),
                ),
                Text(
                  value.isEmpty ? '-' : value,
                  style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SIDEBAR
  // ════════════════════════════════════════════════════════════
  Widget _buildSidebar(BuildContext context, Color color) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: color),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person,
                        size: 40, color: Color(0xFF194CB6)),
                  ),
                  const SizedBox(height: 10),
                  Text(UserSession.name,
                      style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(UserSession.email,
                      style: GoogleFonts.nunito(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _getMenusForRole(context),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text("Keluar",
                style: GoogleFonts.nunito(
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
            onTap: () {
              UserSession.clearSession();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/', (route) => false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _getMenusForRole(BuildContext context) {
    final role = UserSession.role.toLowerCase();
    if (role.contains("admin")) {
      return [
        _menuItem(context, Icons.dashboard, "Dashboard Admin",
            "/dashboard_administrator"),
        _menuItem(context, Icons.people, "Manajemen User",
            "/manajemen-user"),
        _menuItem(context, Icons.account_balance, "Manajemen Unit",
            "/daftar-unit"),
        _menuItem(context, Icons.security, "Manajemen Role",
            "/manajemen-role"),
      ];
    } else if (role.contains("pimpinan")) {
      return [
        _menuItem(context, Icons.dashboard, "Dashboard Pimpinan",
            "/dashboard_pimpinan"),
        _menuItem(context, Icons.analytics, "Arsip Surat Masuk",
            "/arsip-surat-masuk"),
        _menuItem(context, Icons.analytics_outlined,
            "Arsip Surat Keluar", "/arsip-surat-keluar"),
        _menuItemBadge(context, Icons.inbox_rounded, "Inbox Disposisi",
            "/inbox-disposisi", _jumlahBaru),
      ];
    } else {
      return [
        _menuItem(context, Icons.dashboard, "Dashboard Operator",
            "/dashboard_operator"),
        _menuItem(context, Icons.upload_file, "Upload Surat Masuk",
            "/upload_masuk"),
        _menuItem(context, Icons.outbox, "Upload Surat Keluar",
            "/upload_keluar"),
        _menuItem(context, Icons.archive, "Arsip Surat Masuk",
            "/arsip-surat-masuk"),
        _menuItem(context, Icons.archive_outlined,
            "Arsip Surat Keluar", "/arsip-surat-keluar"),
        _menuItemBadge(context, Icons.inbox_rounded, "Inbox Disposisi",
            "/inbox-disposisi", _jumlahBaru),
      ];
    }
  }

  Widget _menuItem(BuildContext context, IconData icon,
      String label, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(label,
          style: GoogleFonts.nunito(
              color: Colors.black87,
              fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }

  Widget _menuItemBadge(BuildContext context, IconData icon,
      String label, String route, int badge) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: const Color(0xFF194CB6)),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle),
                constraints: const BoxConstraints(
                    minWidth: 16, minHeight: 16),
                child: Text(
                  badge > 99 ? "99+" : "$badge",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(label,
              style: GoogleFonts.nunito(
                  color: const Color(0xFF194CB6),
                  fontWeight: FontWeight.bold)),
          if (badge > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10)),
              child: Text("$badge",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]
        ],
      ),
      onTap: () async {
        Navigator.pop(context);
        await Navigator.pushNamed(context, route);
        _fetchBadge();
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // FOOTER
  // ════════════════════════════════════════════════════════════
  Widget _buildFooter(Color color) {
    return Container(
      height: 45,
      color: color,
      child: Center(
        child: Text(
          "© 2026 Digital Archive Management System. All Rights Reserved -Eci-.",
          style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// DIALOG RESET PASSWORD — StatefulWidget terpisah
// Ini yang benar: punya state sendiri, context selalu valid,
// loading indicator, dan validasi yang konsisten.
// ════════════════════════════════════════════════════════════
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  static const _kNavy = Color(0xFF194CB6);

  // ── Controllers ──
  final _oldCtrl     = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // ── State ──
  bool _obscureOld     = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  // ── Error per field ──
  String? _errOld;
  String? _errNew;
  String? _errConfirm;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Validasi lokal sebelum kirim ke API ──────────────────
  bool _validate() {
    setState(() {
      _errOld     = _oldCtrl.text.trim().isEmpty
          ? "Password lama tidak boleh kosong" : null;
      _errNew     = _newCtrl.text.trim().isEmpty
          ? "Password baru tidak boleh kosong"
          : _newCtrl.text.length < 8
              ? "Password baru minimal 8 karakter"
              : null;
      _errConfirm = _confirmCtrl.text.trim().isEmpty
          ? "Konfirmasi tidak boleh kosong"
          : _confirmCtrl.text != _newCtrl.text
              ? "Password baru dan konfirmasi tidak cocok"
              : null;
    });
    return _errOld == null && _errNew == null && _errConfirm == null;
  }

  // ── Kirim request reset password ────────────────────────
 Future<void> _submit() async {
  if (!_validate()) return;

  setState(() => _isLoading = true);

  try {
    final response = await http.post(
      Uri.parse("http://127.0.0.1:8000/auth/change-password"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "id_user":             UserSession.userId,
        "password_lama":       _oldCtrl.text.trim(),
        "password_baru":       _newCtrl.text.trim(),
        "konfirmasi_password": _confirmCtrl.text.trim(),
      }),
    );

    final data = json.decode(response.body);

    // ✅ Bedakan format sukses vs error FastAPI
    // Sukses  → {"success": true,  "message": "..."}
    // Error   → {"detail": "..."}  (dari HTTPException FastAPI)
    final bool success = response.statusCode == 200 && data['success'] == true;
    final String message = success
        ? (data['message'] ?? "Password berhasil diubah!")
        : (data['detail'] ?? data['message'] ?? "Gagal mengubah password.");

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message,
              style: GoogleFonts.nunito(fontSize: 13))),
        ]),
        backgroundColor: success
            ? const Color(0xFF16A34A)
            : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Koneksi gagal: $e",
            style: GoogleFonts.nunito(fontSize: 13)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kNavy.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_reset,
                      color: _kNavy, size: 20),
                ),
                const SizedBox(width: 12),
                Text("Reset Password",
                    style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A202C))),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close,
                      color: Colors.grey.shade500),
                  onPressed: _isLoading
                      ? null // nonaktifkan saat loading
                      : () => Navigator.pop(context),
                ),
              ]),

              const SizedBox(height: 4),
              Text(
                "Masukkan password lama dan password baru kamu",
                style: GoogleFonts.nunito(
                    fontSize: 12, color: Colors.grey.shade500),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // ── Field: Password Lama ──
              _passField(
                ctrl: _oldCtrl,
                label: "Password Lama",
                hint: "Masukkan password saat ini",
                obscure: _obscureOld,
                errorText: _errOld,
                onToggle: () =>
                    setState(() => _obscureOld = !_obscureOld),
                onChanged: (_) =>
                    setState(() => _errOld = null),
              ),
              const SizedBox(height: 14),

              // ── Field: Password Baru ──
              _passField(
                ctrl: _newCtrl,
                label: "Password Baru",
                hint: "Minimal 8 karakter",
                obscure: _obscureNew,
                errorText: _errNew,
                onToggle: () =>
                    setState(() => _obscureNew = !_obscureNew),
                onChanged: (_) =>
                    setState(() => _errNew = null),
              ),
              const SizedBox(height: 14),

              // ── Field: Konfirmasi ──
              _passField(
                ctrl: _confirmCtrl,
                label: "Konfirmasi Password Baru",
                hint: "Ulangi password baru",
                obscure: _obscureConfirm,
                errorText: _errConfirm,
                onToggle: () => setState(
                    () => _obscureConfirm = !_obscureConfirm),
                onChanged: (_) =>
                    setState(() => _errConfirm = null),
              ),

              const SizedBox(height: 24),

              // ── Tombol Simpan ──
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    disabledBackgroundColor:
                        _kNavy.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_outlined,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text("Simpan Password",
                                style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Password field dengan error & toggle visibility ──────
  Widget _passField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D3748))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          onChanged: onChanged,
          enabled: !_isLoading,
          style: GoogleFonts.nunito(
              fontSize: 13, color: const Color(0xFF1A202C)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
                fontSize: 12.5, color: Colors.grey.shade400),
            errorText: errorText,
            errorStyle:
                GoogleFonts.nunito(fontSize: 11.5),
            prefixIcon: const Icon(Icons.lock_outline,
                color: Color(0xFF194CB6), size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey.shade500,
              ),
              onPressed: _isLoading ? null : onToggle,
            ),
            filled: true,
            fillColor: errorText != null
                ? Colors.red.shade50
                : const Color(0xFFFAFBFF),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: errorText != null
                        ? Colors.red.shade300
                        : Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: errorText != null
                        ? Colors.red
                        : const Color(0xFF194CB6),
                    width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Colors.red.shade400, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Colors.red, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
