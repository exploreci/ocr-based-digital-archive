import 'package:flutter/material.dart';

class DocumentCornerPainter extends CustomPainter {
  final List<Offset> points;

  DocumentCornerPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Definisikan Paint untuk Garis (Biru agar sesuai tema aplikasi)
    final linePaint = Paint()
      ..color = const Color(0xFF194CB6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // 2. Definisikan Paint untuk Titik Sudut
    final dotPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    // 3. Gambar Garis penghubung antar titik
    if (points.isNotEmpty) {
      for (int i = 0; i < points.length; i++) {
        // Gambar titik di setiap koordinat
        canvas.drawCircle(points[i], 8, dotPaint);
        
        // Tambahkan nomor urut titik (opsional, untuk memudahkan user)
        _drawText(canvas, (i + 1).toString(), points[i]);

        // Gambar garis ke titik berikutnya
        if (i < points.length - 1) {
          canvas.drawLine(points[i], points[i + 1], linePaint);
        } else if (points.length == 4) {
          // Jika sudah ada 4 titik, hubungkan titik terakhir kembali ke titik pertama
          canvas.drawLine(points[i], points[0], linePaint);
        }
      }
    }
  }

  // Helper untuk menggambar teks angka di atas titik
  void _drawText(Canvas canvas, String text, Offset position) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    // Geser teks sedikit agar berada di tengah titik
    textPainter.paint(canvas, Offset(position.dx - (textPainter.width / 2), position.dy - (textPainter.height / 2)));
  }

  @override
  bool shouldRepaint(covariant DocumentCornerPainter oldDelegate) {
    // Return bool: akan menggambar ulang hanya jika jumlah titik berubah
    return oldDelegate.points != points || oldDelegate.points.length != points.length;
  }
}