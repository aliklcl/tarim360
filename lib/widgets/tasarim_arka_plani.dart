import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundPathNotifier extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('arka_plan_resmi_yolu');
    state = path;
  }

  void updateState(String? path) {
    state = path;
  }
}

final backgroundPathProvider = NotifierProvider<BackgroundPathNotifier, String?>(BackgroundPathNotifier.new);

// Tema geçiş merkezinin koordinatlarını tutacak NotifierProvider
class ThemeTransitionCenterNotifier extends Notifier<Offset?> {
  @override
  Offset? build() => null;

  void updateState(Offset? offset) {
    state = offset;
  }
}

final themeTransitionCenterProvider = NotifierProvider<ThemeTransitionCenterNotifier, Offset?>(ThemeTransitionCenterNotifier.new);

Future<void> setTasarimArkaPlani(WidgetRef ref, String? path) async {
  final prefs = await SharedPreferences.getInstance();
  if (path == null) {
    await prefs.remove('arka_plan_resmi_yolu');
  } else {
    await prefs.setString('arka_plan_resmi_yolu', path);
  }
  ref.read(backgroundPathProvider.notifier).updateState(path);
}

class TasarimArkaPlani extends ConsumerStatefulWidget {
  const TasarimArkaPlani({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<TasarimArkaPlani> createState() => _TasarimArkaPlaniState();
}

class _TasarimArkaPlaniState extends ConsumerState<TasarimArkaPlani> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _previousBgPath;
  String? _currentBgPath;
  Offset? _rippleCenter;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700), // Akıcı ve şık premium geçiş süresi
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
          _previousBgPath = null;
          // Geçiş bittiğinde koordinatları sıfırla
          ref.read(themeTransitionCenterProvider.notifier).updateState(null);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBackgroundLayer(String? bgPath, bool isDark) {
    if (bgPath != null && bgPath.startsWith('preset:')) {
      if (bgPath == 'preset:deep_forest') {
        return Image.asset(
          'assets/backgrounds/green_field.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (bgPath == 'preset:golden_wheat') {
        return Image.asset(
          'assets/backgrounds/wheat_field.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (bgPath == 'preset:lavender_field') {
        return Image.asset(
          'assets/backgrounds/lavender_field.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        List<Color> colors;
        switch (bgPath) {
          case 'preset:morning_dew':
            colors = isDark
                ? const [Color(0xFF0B2B2B), Color(0xFF143D3D), Color(0xFF061818)]
                : const [Color(0xFFE0F2F1), Color(0xFFB2DFDB), Color(0xFF80CBC4)];
            break;
          default:
            colors = isDark
                ? const [Color(0xFF0C241E), Color(0xFF14362E), Color(0xFF071B16)]
                : const [Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFE8F5E9)];
        }
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      }
    } else if (bgPath != null && File(bgPath).existsSync()) {
      return Image.file(
        File(bgPath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0F261C), Color(0xFF07140E), Color(0xFF040A07)]
                : const [Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFE1F5FE)],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      );
    }
  }

  Widget _buildBackgroundWithOverlay(String? bgPath, bool isDark) {
    final hasOverlay = bgPath != null && (
      !bgPath.startsWith('preset:') || 
      bgPath == 'preset:deep_forest' || 
      bgPath == 'preset:golden_wheat' || 
      bgPath == 'preset:lavender_field'
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackgroundLayer(bgPath, isDark),
        if (hasOverlay)
          Positioned.fill(
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.65),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgPath = ref.watch(backgroundPathProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<String?>(backgroundPathProvider, (previous, next) {
      if (previous != next) {
        final center = ref.read(themeTransitionCenterProvider);
        if (center != null) {
          setState(() {
            _previousBgPath = previous;
            _currentBgPath = next;
            _rippleCenter = center;
            _isAnimating = true;
          });
          _controller.forward(from: 0.0);
        }
      }
    });

    final activeCurrentPath = _isAnimating ? _currentBgPath : bgPath;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Geçiş sırasında eski arka planı altta tutar
            if (_isAnimating && _previousBgPath != activeCurrentPath)
              _buildBackgroundWithOverlay(_previousBgPath, isDark),

            // Yeni arka plan dairesel dalga şeklinde büyüyerek üstüne biner
            if (_isAnimating && _previousBgPath != activeCurrentPath)
              ClipPath(
                clipper: CircularRippleClipper(
                  center: _rippleCenter,
                  radiusPercent: _controller.value,
                ),
                child: _buildBackgroundWithOverlay(activeCurrentPath, isDark),
              )
            else
              _buildBackgroundWithOverlay(activeCurrentPath, isDark),

            widget.child,
          ],
        );
      },
    );
  }
}

class CircularRippleClipper extends CustomClipper<Path> {
  final Offset? center;
  final double radiusPercent;

  CircularRippleClipper({required this.center, required this.radiusPercent});

  @override
  Path getClip(Size size) {
    final path = Path();
    final clipCenter = center ?? Offset(size.width / 2, size.height / 2);
    
    // Ekranı tamamen kaplayacak maksimum yarıçapı hesapla (dokunma noktasından en uzak köşeye olan mesafe)
    final maxRadius = _calculateMaxRadius(clipCenter, size);
    final currentRadius = maxRadius * radiusPercent;

    path.addOval(Rect.fromCircle(center: clipCenter, radius: currentRadius));
    return path;
  }

  double _calculateMaxRadius(Offset center, Size size) {
    final dx1 = center.dx;
    final dx2 = size.width - center.dx;
    final dy1 = center.dy;
    final dy2 = size.height - center.dy;

    final d1 = math.sqrt(dx1 * dx1 + dy1 * dy1);
    final d2 = math.sqrt(dx2 * dx2 + dy1 * dy1);
    final d3 = math.sqrt(dx1 * dx1 + dy2 * dy2);
    final d4 = math.sqrt(dx2 * dx2 + dy2 * dy2);

    return [d1, d2, d3, d4].reduce(math.max);
  }

  @override
  bool shouldReclip(covariant CircularRippleClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radiusPercent != radiusPercent;
  }
}
