class FreePlantAdviceService {
  FreePlantAdviceService._();

  static String onAnalizUret({
    required String soru,
    required bool gorselVar,
    required List<String> seciliBelirtiler,
  }) {
    final s = soru.toLowerCase();
    final belirtiler = seciliBelirtiler.map((e) => e.toLowerCase()).toSet();

    final mantarSuphesi = _icerir(s, ['mantar', 'kulleme', 'mildiyo', 'pas']) ||
        belirtiler.contains('mantar');
    final zararliSuphesi = _icerir(
          s,
          ['bocek', 'zararli', 'trip', 'bit', 'yaprak biti', 'kurdu'],
        ) ||
        belirtiler.contains('bocek');
    final besinSuphesi = _icerir(
          s,
          ['sararma', 'solma', 'besin', 'azot', 'potasyum', 'magnezyum'],
        ) ||
        belirtiler.contains('sararma');
    final suStresi = _icerir(s, ['susuz', 'soldu', 'yanik', 'sulama']) ||
        belirtiler.contains('solma');

    String aciliyet = 'Orta';
    if (zararliSuphesi || mantarSuphesi) aciliyet = 'Yuksek';
    if (!zararliSuphesi && !mantarSuphesi && (besinSuphesi || suStresi)) {
      aciliyet = 'Orta';
    }
    if (s.trim().isEmpty) aciliyet = 'Dusuk';

    final olasiDurumlar = <String>[
      if (mantarSuphesi) 'Mantar kaynakli leke / enfeksiyon olasiligi',
      if (zararliSuphesi) 'Bocek/zararli etkisi olasiligi',
      if (besinSuphesi) 'Besin noksanligi kaynakli bozulma olasiligi',
      if (suStresi) 'Sulama-duzensiz su kaynakli stres olasiligi',
      if (!mantarSuphesi && !zararliSuphesi && !besinSuphesi && !suStresi)
        'Genel stres (iklim, sulama, besin dengesi) olasiligi',
    ];

    final hemenYap = <String>[
      'Ayni bolgeden 2-3 yeni foto daha al ve 24 saat sonra karsilastir.',
      'Hasta gorunen yapraklari saglikli bolgeden ayri takip et.',
      if (mantarSuphesi)
        'Yapragi islatan sulama saatlerini azalt, hava akisini artir.',
      if (zararliSuphesi)
        'Yaprak altini kontrol et; canli zararli varsa sayi ve yogunluk not et.',
      if (besinSuphesi)
        'Son gubreleme tarihini kontrol et, ani yuksek dozdan kacin.',
      if (suStresi) 'Toprak nemini sabit tutacak sulama duzeni belirle.',
    ];

    final izleme = <String>[
      '24-48 saatte leke boyutu artiyor mu?',
      'Yeni yapraklarda da ayni belirti var mi?',
      'Belirti belirli bir parselde mi yoksa genelde mi?',
      'Gerekirse bolge ziraat uzmani ile yerinde teyit et.',
    ];

    String imageUrl = 'https://images.unsplash.com/photo-1523348837708-15d4a09cfac2?w=500&q=80';
    String imageAlt = 'Sağlıklı Gelişim (Karşılaştırma Görseli)';
    if (suStresi) {
      imageUrl = 'https://images.unsplash.com/photo-1416339306562-f3d12fefd36f?w=500&q=80';
      imageAlt = 'Sulama Stresi (Karşılaştırma Görseli)';
    } else if (mantarSuphesi) {
      imageUrl = 'https://images.unsplash.com/photo-1589051030485-268562cd53e2?w=500&q=80';
      imageAlt = 'Mantar ve Mildiyö (Karşılaştırma Görseli)';
    } else if (zararliSuphesi) {
      imageUrl = 'https://images.unsplash.com/photo-1473186578172-c141e6798cf4?w=500&q=80';
      imageAlt = 'Zararlı Böcekler (Karşılaştırma Görseli)';
    } else if (s.contains('domates')) {
      imageUrl = 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500&q=80';
      imageAlt = 'Domates Bakımı (Karşılaştırma Görseli)';
    } else if (besinSuphesi) {
      imageUrl = 'https://images.unsplash.com/photo-1593113598332-cd288d649433?w=500&q=80';
      imageAlt = 'Toprak ve Besin (Karşılaştırma Görseli)';
    }

    final gorselNotu = gorselVar
        ? 'Görsel analiz edildi.'
        : 'Görsel eklenmedi, sadece belirtilere göre analiz yapıldı.';

    return '''
* **Filiz'in Teşhisi (Olası Hastalık/Sorun):** ${olasiDurumlar.join(' veya ')} ($gorselNotu)
* **Aciliyet Seviyesi:** $aciliyet - Çevrimdışı kurallarla tespit edildi.
* **İlk Müdahale (Hemen Yapılacaklar):** 
${hemenYap.map((e) => '  - $e').join('\n')}
* **İzleme Listesi (24-48 Saat):** ${izleme.join(' ')}

Kesin teşhis için lütfen bir ziraat uzmanına danışın. Bu çevrimdışı bir ön değerlendirmedir.

![$imageAlt]($imageUrl)
''';
  }

  static bool _icerir(String metin, List<String> anahtarlar) {
    for (final anahtar in anahtarlar) {
      if (metin.contains(anahtar)) return true;
    }
    return false;
  }
}
