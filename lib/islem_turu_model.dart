import 'package:flutter/material.dart';

class IslemTuruTanim {
  const IslemTuruTanim({
    required this.ad,
    required this.iconKey,
    required this.colorValue,
    this.varsayilan = false,
    this.kategori = '',
  });

  final String ad;
  final String iconKey;
  final int colorValue;
  final bool varsayilan;
  /// Hangi ana kategoriye eslesir: 'Sulama', 'Gubre', 'Ilac', '' (Diger)
  final String kategori;

  Map<String, dynamic> toMap() {
    return {
      'ad': ad,
      'iconKey': iconKey,
      'colorValue': colorValue,
      'varsayilan': varsayilan,
      'kategori': kategori,
    };
  }

  factory IslemTuruTanim.fromMap(Map<String, dynamic> map) {
    return IslemTuruTanim(
      ad: (map['ad'] as String? ?? '').trim(),
      iconKey: (map['iconKey'] as String? ?? 'event_note').trim(),
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF7B5EA7,
      varsayilan: map['varsayilan'] == true,
      kategori: (map['kategori'] as String? ?? '').trim(),
    );
  }
}

const List<IslemTuruTanim> varsayilanIslemTurleri = [
  IslemTuruTanim(
    ad: 'Sulama',
    iconKey: 'water_drop',
    colorValue: 0xFF2F80ED,
    varsayilan: true,
  ),
  IslemTuruTanim(
    ad: 'Gubre',
    iconKey: 'grass',
    colorValue: 0xFF39A94B,
    varsayilan: true,
  ),
  IslemTuruTanim(
    ad: 'Ilac',
    iconKey: 'science',
    colorValue: 0xFFF39C12,
    varsayilan: true,
  ),
];

const List<Map<String, dynamic>> kullanilabilirIslemIkonlari = [
  {'key': 'agriculture', 'label': 'Tarim', 'icon': Icons.agriculture_outlined},
  {'key': 'spa', 'label': 'Yaprak', 'icon': Icons.spa_outlined},
  {'key': 'inventory', 'label': 'Depo', 'icon': Icons.inventory_2_outlined},
  {'key': 'build', 'label': 'Bakim', 'icon': Icons.build_outlined},
  {'key': 'local_shipping', 'label': 'Tasim', 'icon': Icons.local_shipping_outlined},
  {'key': 'paid', 'label': 'Odeme', 'icon': Icons.payments_outlined},
  {'key': 'bug_report', 'label': 'Kontrol', 'icon': Icons.bug_report_outlined},
  {'key': 'edit_note', 'label': 'Not', 'icon': Icons.edit_note_outlined},
];

const List<Map<String, dynamic>> kullanilabilirIslemRenkleri = [
  {'label': 'Mavi', 'value': 0xFF2F80ED},
  {'label': 'Yesil', 'value': 0xFF39A94B},
  {'label': 'Turuncu', 'value': 0xFFF39C12},
  {'label': 'Mor', 'value': 0xFF7B5EA7},
  {'label': 'Kirmizi', 'value': 0xFFD35454},
  {'label': 'Kahve', 'value': 0xFF8D6E63},
  {'label': 'Turkuaz', 'value': 0xFF0F9D94},
  {'label': 'Gri', 'value': 0xFF607D8B},
];

List<IslemTuruTanim> tumIslemTurleriniBirlestir(List<IslemTuruTanim> ozelTipler) {
  final birlesik = <String, IslemTuruTanim>{
    for (final tanim in varsayilanIslemTurleri) tanim.ad: tanim,
  };
  for (final tanim in ozelTipler) {
    if (tanim.ad.trim().isEmpty) continue;
    birlesik[tanim.ad.trim()] = tanim;
  }
  final sonuc = birlesik.values.toList(growable: false);
  sonuc.sort((a, b) {
    if (a.varsayilan != b.varsayilan) return a.varsayilan ? -1 : 1;
    return a.ad.toLowerCase().compareTo(b.ad.toLowerCase());
  });
  return sonuc;
}

IslemTuruTanim islemTuruTaniminiBul(
  String tur,
  List<IslemTuruTanim> ozelTipler,
) {
  return tumIslemTurleriniBirlestir(ozelTipler).firstWhere(
    (tanim) => tanim.ad == tur,
    orElse: () => IslemTuruTanim(
      ad: tur,
      iconKey: 'inventory',
      colorValue: 0xFF607D8B,
    ),
  );
}

IconData islemTuruIkonunuGetir(String iconKey) {
  switch (iconKey) {
    case 'water_drop':
      return Icons.water_drop;
    case 'grass':
      return Icons.grass;
    case 'science':
      return Icons.science;
    case 'agriculture':
      return Icons.agriculture_outlined;
    case 'spa':
      return Icons.spa_outlined;
    case 'inventory':
      return Icons.inventory_2_outlined;
    case 'build':
      return Icons.build_outlined;
    case 'local_shipping':
      return Icons.local_shipping_outlined;
    case 'paid':
      return Icons.payments_outlined;
    case 'bug_report':
      return Icons.bug_report_outlined;
    case 'edit_note':
      return Icons.edit_note_outlined;
    default:
      return Icons.event_note;
  }
}

Color islemTuruRenginiGetir(IslemTuruTanim tanim) => Color(tanim.colorValue);
