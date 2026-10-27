
import 'package:flutter/material.dart';
import '../weather_service.dart';


// Fallback for globals

class DurumRozeti extends StatelessWidget {
  const DurumRozeti({super.key, 
    required this.renk,
    required this.metin,
  });

  final Color renk;
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: renk.withValues(alpha: 0.25)),
      ),
      child: Text(
        metin,
        style: TextStyle(
          color: renk.withValues(alpha: 0.95),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class GirisBilgiRozeti extends StatelessWidget {
  const GirisBilgiRozeti({super.key, 
    required this.ikon,
    required this.metin,
  });

  final IconData ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF476F3A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF476F3A).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 16, color: const Color(0xFF476F3A)),
          const SizedBox(width: 6),
          Text(
            metin,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2F4D28),
            ),
          ),
        ],
      ),
    );
  }
}

class MiniBilgiRozeti extends StatelessWidget {
  const MiniBilgiRozeti({super.key, 
    required this.ikon,
    required this.renk,
    required this.metin,
    required this.altMetin,
  });

  final IconData ikon;
  final Color renk;
  final String metin;
  final String altMetin;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Theme.of(context).colorScheme.surfaceContainerHighest 
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(ikon, size: 14, color: renk),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  altMetin,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListeOzetBandi extends StatelessWidget {
  const ListeOzetBandi({super.key, 
    required this.toplamTarla,
    required this.sulamaBekleyen,
    required this.bulutEtkin,
    required this.hatirlatmalar,
    this.havaDurumu,
    this.havaYukleniyor = false,
    this.onHavaYenile,
  });

  final int toplamTarla;
  final int sulamaBekleyen;
  final bool bulutEtkin;
  final List<String> hatirlatmalar;
  final TarlaHavaDurumu? havaDurumu;
  final bool havaYukleniyor;
  final VoidCallback? onHavaYenile;

  // ignore: unused_element
  IconData _havaIkonuSec(String aciklama) {
    final ac = aciklama.toLowerCase();
    if (ac.contains('açık') || ac.contains('güneş')) return Icons.wb_sunny_rounded;
    if (ac.contains('bulut') || ac.contains('kapalı')) return Icons.wb_cloudy_rounded;
    if (ac.contains('yağmur') || ac.contains('sağanak') || ac.contains('çisenti')) return Icons.umbrella_rounded;
    if (ac.contains('kar')) return Icons.ac_unit_rounded;
    if (ac.contains('sis')) return Icons.cloud_queue_rounded;
    if (ac.contains('fırtına')) return Icons.thunderstorm_rounded;
    return Icons.wb_sunny_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final darEkran = MediaQuery.sizeOf(context).width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        
        // Summary Band
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2D7A4F),
                Color(0xFF1B4332),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D7A4F).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(darEkran ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bugünün Özeti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bulutEtkin
                      ? 'Bulut modu açık. Kayıtlar cihazlar arasında senkronize.'
                      : 'Yerel mod açık. Kayıtlar bu cihazda saklanıyor.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: darEkran ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassBox(
                        deger: '$toplamTarla',
                        etiket: 'Toplam Tarla',
                        darEkran: darEkran,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildGlassBox(
                        deger: '$sulamaBekleyen',
                        etiket: 'Sulama Bekleyen',
                        darEkran: darEkran,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassBox({required String deger, required String etiket, required bool darEkran}) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: darEkran ? 12 : 16,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deger,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            etiket,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class OzetKutusu extends StatelessWidget {
  const OzetKutusu({super.key, 
    required this.deger,
    required this.etiket,
    required this.darEkran,
  });

  final String deger;
  final String etiket;
  final bool darEkran;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: darEkran ? (MediaQuery.sizeOf(context).width - 58) / 2 : 200,
      padding: EdgeInsets.symmetric(
        horizontal: darEkran ? 12 : 14,
        vertical: darEkran ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiket,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: darEkran ? 11 : 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deger,
            style: TextStyle(
              color: Colors.white,
              fontSize: darEkran ? 18 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns a large illustrative emoji/icon widget for each operation type
Widget islemIllustrasyon(String baslik, Color renk) {
  // Map of operation name -> emoji for rich visual display
  final Map<String, String> islemEmoji = {
    'Sulama': '💧',
    'Gubre': '🌱',
    'Ilac': '🧪',
    'Hasat': '🌾',
    'Ekim': '🌰',
    'Nadas': '🌍',
    'Budama': '✂️',
    'Ilaclama': '🧴',
    'Toprak': '🪱',
    'Makine': '🚜',
    'Gelir': '💰',
    'Gider': '📋',
    'Not ekle': '📸',
  };

  String? emoji;
  for (final entry in islemEmoji.entries) {
    if (baslik.toLowerCase().contains(entry.key.toLowerCase())) {
      emoji = entry.value;
      break;
    }
  }

  if (emoji != null) {
    return Text(emoji, style: const TextStyle(fontSize: 36));
  }
  return Icon(Icons.agriculture_rounded, color: renk, size: 36);
}

class HizliIslemKarti extends StatelessWidget {
  const HizliIslemKarti({super.key,
    required this.width,
    required this.ikon,
    required this.renk,
    required this.baslik,
    required this.aciklama,
    required this.onTap,
  });

  final double width;
  final IconData ikon;
  final Color renk;
  final String baslik;
  final String aciklama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [renk.withValues(alpha: 0.22), renk.withValues(alpha: 0.10)]
                    : [Colors.white.withValues(alpha: 0.92), renk.withValues(alpha: 0.07)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: renk.withValues(alpha: isDark ? 0.30 : 0.18),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: renk.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Large illustration area
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: renk.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: islemIllustrasyon(baslik, renk),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    baslik,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1B3A28),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    aciklama,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TakvimTurNoktalari extends StatelessWidget {
  const TakvimTurNoktalari({super.key, 
    required this.turler,
    required this.turRenkleri,
  });

  final Set<String> turler;
  final Map<String, Color> turRenkleri;

  @override
  Widget build(BuildContext context) {
    if (turler.isEmpty) {
      return const SizedBox(height: 4);
    }

    final gosterilecekler = turler.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final tur in gosterilecekler)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: turRenkleri[tur] ?? Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class TakvimLejandesi extends StatelessWidget {
  const TakvimLejandesi({super.key, 
    required this.renk,
    required this.etiket,
  });

  final Color renk;
  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: renk,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(etiket),
      ],
    );
  }
}
