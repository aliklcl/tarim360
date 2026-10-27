import 'dart:math' as math;
import 'package:flutter/material.dart';

class KonfetiKutlamasi extends StatefulWidget {
  final VoidCallback onAnimasyonBitti;
  const KonfetiKutlamasi({super.key, required this.onAnimasyonBitti});

  @override
  State<KonfetiKutlamasi> createState() => _KonfetiKutlamasiState();
}

class _KonfetiKutlamasiState extends State<KonfetiKutlamasi> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_KonfetiParcacigi> _parcaciklar = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _controller.addListener(() {
      setState(() {
        for (final p in _parcaciklar) {
          p.guncelle(_controller.value);
        }
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimasyonBitti();
      }
    });

    // Generate particles after layout size is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      _parcaciklariUret(size.width, size.height);
      _controller.forward();
    });
  }

  void _parcaciklariUret(double width, double height) {
    for (int i = 0; i < 120; i++) {
      // Start from the top, spread out horizontally
      final x = _random.nextDouble() * width;
      final y = -_random.nextDouble() * 150 - 20;
      
      // Velocities
      final vx = (_random.nextDouble() - 0.5) * 200; // horizontal speed
      final vy = _random.nextDouble() * 300 + 200;  // falling speed
      
      // HSL color presets (vibrant colors)
      final color = HSVColor.fromAHSV(
        1.0,
        _random.nextDouble() * 360, // random hue
        0.85,                       // high saturation
        0.9,                        // bright
      ).toColor();

      _parcaciklar.add(_KonfetiParcacigi(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        color: color,
        size: _random.nextDouble() * 12 + 6,
        rotationSpeed: (_random.nextDouble() - 0.5) * 15,
        swaySpeed: _random.nextDouble() * 4 + 2,
        swayAmount: _random.nextDouble() * 20 + 5,
        type: _KonfetiTipi.values[_random.nextInt(_KonfetiTipi.values.length)],
        screenHeight: height,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _KonfetiPainter(parcaciklar: _parcaciklar),
        size: Size.infinite,
      ),
    );
  }
}

enum _KonfetiTipi { rectangle, circle, ribbon }

class _KonfetiParcacigi {
  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  final double size;
  final double rotationSpeed;
  final double swaySpeed;
  final double swayAmount;
  final _KonfetiTipi type;
  final double screenHeight;

  double angle = 0.0;
  double currentX = 0.0;
  double currentY = 0.0;

  _KonfetiParcacigi({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotationSpeed,
    required this.swaySpeed,
    required this.swayAmount,
    required this.type,
    required this.screenHeight,
  }) {
    currentX = x;
    currentY = y;
  }

  void guncelle(double progress) {
    final time = progress * 2.5; // seconds elapsed
    currentY = y + vy * time;
    currentX = x + vx * time + math.sin(time * swaySpeed) * swayAmount;
    angle = rotationSpeed * time;
  }
}

class _KonfetiPainter extends CustomPainter {
  final List<_KonfetiParcacigi> parcaciklar;
  _KonfetiPainter({required this.parcaciklar});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in parcaciklar) {
      if (p.currentY < -50 || p.currentY > size.height + 50) continue;
      
      canvas.save();
      canvas.translate(p.currentX, p.currentY);
      canvas.rotate(p.angle);
      paint.color = p.color;

      switch (p.type) {
        case _KonfetiTipi.rectangle:
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size * 0.7), paint);
          break;
        case _KonfetiTipi.circle:
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
          break;
        case _KonfetiTipi.ribbon:
          final path = Path()
            ..moveTo(-p.size, -p.size * 0.3)
            ..quadraticBezierTo(0, p.size * 0.5, p.size, -p.size * 0.3)
            ..lineTo(p.size, p.size * 0.3)
            ..quadraticBezierTo(0, -p.size * 0.5, -p.size, p.size * 0.3)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _KonfetiPainter oldDelegate) => true;
}
