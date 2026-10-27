class Gelir {
  const Gelir({
    this.id,
    required this.tarlaId,
    required this.tarih,
    required this.miktar,
    this.aciklama = '',
  });

  final int? id;
  final int tarlaId;
  final String tarih;
  final double miktar;
  final String aciklama;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tarlaId': tarlaId,
      'tarih': tarih,
      'miktar': miktar,
      'aciklama': aciklama,
    };
  }

  factory Gelir.fromMap(Map<String, dynamic> map) {
    return Gelir(
      id: map['id'] as int?,
      tarlaId: (map['tarlaId'] as int?) ?? 0,
      tarih: map['tarih'] as String? ?? '',
      miktar: (map['miktar'] as num?)?.toDouble() ?? 0.0,
      aciklama: map['aciklama'] as String? ?? '',
    );
  }

  Gelir copyWith({
    int? id,
    int? tarlaId,
    String? tarih,
    double? miktar,
    String? aciklama,
  }) {
    return Gelir(
      id: id ?? this.id,
      tarlaId: tarlaId ?? this.tarlaId,
      tarih: tarih ?? this.tarih,
      miktar: miktar ?? this.miktar,
      aciklama: aciklama ?? this.aciklama,
    );
  }
}
