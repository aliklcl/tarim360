class Islem {
  const Islem({
    this.id,
    required this.tarlaId,
    required this.tur,
    this.detay = '',
    this.baslangicZamani,
    this.tarih = '',
    this.kullaniciAdi = '',
    this.fotoBase64 = '',
    this.maliyet,
  });

  final int? id;
  final int tarlaId;
  final String tur;
  final String detay;
  final String? baslangicZamani;
  final String tarih;
  final String kullaniciAdi;
  final String fotoBase64;
  final double? maliyet;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tarlaId': tarlaId,
      'tur': tur,
      'detay': detay,
      'baslangicZamani': baslangicZamani,
      'tarih': tarih,
      'kullaniciAdi': kullaniciAdi,
      'fotoBase64': fotoBase64,
      'maliyet': maliyet,
    };
  }

  factory Islem.fromMap(Map<String, dynamic> map) {
    return Islem(
      id: map['id'] as int?,
      tarlaId: (map['tarlaId'] as int?) ?? 0,
      tur: map['tur'] as String? ?? '',
      detay: (map['detay'] as String?)?.trim().isNotEmpty == true
          ? map['detay'] as String
          : map['saat'] as String? ?? '',
      baslangicZamani: map['baslangicZamani'] as String?,
      tarih: map['tarih'] as String? ?? '',
      kullaniciAdi: map['kullaniciAdi'] as String? ?? '',
      fotoBase64: map['fotoBase64'] as String? ?? '',
      maliyet: (map['maliyet'] as num?)?.toDouble(),
    );
  }

  Islem copyWith({
    int? id,
    int? tarlaId,
    String? tur,
    String? detay,
    String? baslangicZamani,
    String? tarih,
    String? kullaniciAdi,
    String? fotoBase64,
    double? maliyet,
  }) {
    return Islem(
      id: id ?? this.id,
      tarlaId: tarlaId ?? this.tarlaId,
      tur: tur ?? this.tur,
      detay: detay ?? this.detay,
      baslangicZamani: baslangicZamani ?? this.baslangicZamani,
      tarih: tarih ?? this.tarih,
      kullaniciAdi: kullaniciAdi ?? this.kullaniciAdi,
      fotoBase64: fotoBase64 ?? this.fotoBase64,
      maliyet: maliyet ?? this.maliyet,
    );
  }
}
