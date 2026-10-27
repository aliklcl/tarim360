import '../widgets/badges_and_cards.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import '../utils/app_helpers.dart';
// Fallback for globals

class AylikYogunlukGrafigi extends StatelessWidget {
  const AylikYogunlukGrafigi({super.key, 
    required this.veriler,
  });

  final List<AylikIslemYogunlugu> veriler;

  @override
  Widget build(BuildContext context) {
    final maksimum = veriler.fold<int>(0, (enBuyuk, veri) {
      return veri.toplam > enBuyuk ? veri.toplam : enBuyuk;
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final darEkran = constraints.maxWidth < 520;
        final grafikYuksekligi = darEkran ? 78.0 : 92.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < veriler.length; i++) ...[
              Expanded(
                child: AylikYogunlukCubugu(
                  veri: veriler[i],
                  maksimum: maksimum == 0 ? 1 : maksimum,
                  grafikYuksekligi: grafikYuksekligi,
                ),
              ),
              if (i != veriler.length - 1) SizedBox(width: darEkran ? 8 : 10),
            ],
          ],
        );
      },
    );
  }
}

class AylikYogunlukCubugu extends StatelessWidget {
  const AylikYogunlukCubugu({super.key, 
    required this.veri,
    required this.maksimum,
    required this.grafikYuksekligi,
  });

  final AylikIslemYogunlugu veri;
  final int maksimum;
  final double grafikYuksekligi;

  @override
  Widget build(BuildContext context) {
    final toplam = veri.toplam;
    final barYuksekligi = toplam == 0
        ? 6.0
        : (toplam / maksimum).clamp(0.0, 1.0) * grafikYuksekligi;

    double parcaYuksekligi(int sayi) {
      if (toplam == 0 || sayi == 0) return 0;
      return (sayi / toplam) * barYuksekligi;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$toplam',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: toplam == 0 ? Colors.grey.shade500 : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: grafikYuksekligi,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 28,
            height: barYuksekligi,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (veri.ilac > 0)
                  Container(
                    height: parcaYuksekligi(veri.ilac),
                    color: Colors.orange.shade400,
                  ),
                if (veri.gubre > 0)
                  Container(
                    height: parcaYuksekligi(veri.gubre),
                    color: Colors.green.shade400,
                  ),
                if (veri.sulama > 0)
                  Container(
                    height: parcaYuksekligi(veri.sulama),
                    color: Colors.blue.shade400,
                  ),
                if (veri.diger > 0)
                  Container(
                    height: parcaYuksekligi(veri.diger),
                    color: Colors.grey.shade500,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('MMM', 'tr_TR').format(veri.ay),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class AylikIslemTakvimi extends StatelessWidget {
  const AylikIslemTakvimi({
    super.key,
    required this.gosterilenAy,
    required this.seciliTarih,
    required this.islemSayilari,
    required this.islemTurleri,
    required this.turRenkleri,
    required this.onAyDegistir,
    required this.onTarihSec,
  });

  final DateTime gosterilenAy;
  final DateTime seciliTarih;
  final Map<DateTime, int> islemSayilari;
  final Map<DateTime, Set<String>> islemTurleri;
  final Map<String, Color> turRenkleri;
  final ValueChanged<DateTime> onAyDegistir;
  final ValueChanged<DateTime> onTarihSec;

  static const List<String> _haftaGunleri = [
    'Pzt',
    'Sal',
    'Car',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  @override
  Widget build(BuildContext context) {
    final ilkGun = DateTime(gosterilenAy.year, gosterilenAy.month, 1);
    final gunSayisi = DateUtils.getDaysInMonth(gosterilenAy.year, gosterilenAy.month);
    final boslukSayisi = ilkGun.weekday - 1;
    final hucreSayisi = ((boslukSayisi + gunSayisi + 6) ~/ 7) * 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const bosluk = 6.0;
                const hucreYuksekligi = 52.0;

                return Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => onAyDegistir(
                            DateTime(gosterilenAy.year, gosterilenAy.month - 1),
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy', 'tr_TR').format(gosterilenAy),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => onAyDegistir(
                            DateTime(gosterilenAy.year, gosterilenAy.month + 1),
                          ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _haftaGunleri
                          .map(
                            (gun) => Expanded(
                              child: Center(
                                child: Text(
                                  gun,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: hucreSayisi,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: bosluk,
                        crossAxisSpacing: bosluk,
                        mainAxisExtent: hucreYuksekligi,
                      ),
                      itemBuilder: (context, index) {
                        final gunNo = index - boslukSayisi + 1;
                        if (gunNo < 1 || gunNo > gunSayisi) {
                          return const SizedBox.shrink();
                        }

                        final tarih = DateTime(gosterilenAy.year, gosterilenAy.month, gunNo);
                        final anahtar = DateTime(tarih.year, tarih.month, tarih.day);
                        final kayitSayisi = islemSayilari[anahtar] ?? 0;
                        final seciliMi = _ayniGun(tarih, seciliTarih);
                        final bugunMu = _ayniGun(tarih, turkiyeSimdi());

                        final isDark = Theme.of(context).brightness == Brightness.dark;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onTarihSec(tarih),
                          child: Container(
                            decoration: BoxDecoration(
                              color: seciliMi 
                                  ? (isDark ? Colors.green.shade900.withValues(alpha: 0.5) : Colors.green.shade100)
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: seciliMi
                                    ? (isDark ? Colors.green.shade500 : Colors.green.shade700)
                                    : bugunMu
                                        ? (isDark ? Colors.orange.shade500 : Colors.orange.shade300)
                                        : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$gunNo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: seciliMi || bugunMu
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (kayitSayisi > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$kayitSayisi',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  TakvimTurNoktalari(
                                    turler: islemTurleri[anahtar] ?? const <String>{},
                                    turRenkleri: turRenkleri,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool _ayniGun(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
