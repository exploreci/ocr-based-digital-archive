import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.icon,
    required this.onTap,
  });

 @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      // 1. Tambahkan InkWell di sini
      child: InkWell(
        onTap: onTap, // 2. Panggil parameter onTap di sini
        borderRadius: BorderRadius.circular(10), // Biar efek kliknya rapi sesuai sudut card
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Ubah ke center agar icon & teks sejajar
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              const SizedBox(width: 20), // Gunakan width karena ini di dalam Row
              Expanded( // Gunakan Expanded agar teks tidak overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle, // Jangan lupa tampilkan subtitle-nya juga
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey), // Tambahkan panah kecil biar manis
            ],
          ),
        ),
      ),
    );
  }
  }