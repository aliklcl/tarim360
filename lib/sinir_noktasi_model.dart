class SinirNoktasi {
  const SinirNoktasi({
    this.id,
    required this.tarlaId,
    required this.enlem,
    required this.boylam,
  });

  final int? id;
  final int tarlaId;
  final double enlem;
  final double boylam;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tarlaId': tarlaId,
      'enlem': enlem,
      'boylam': boylam,
    };
  }

  factory SinirNoktasi.fromMap(Map<String, dynamic> map) {
    return SinirNoktasi(
      id: map['id'] as int?,
      tarlaId: (map['tarlaId'] as int?) ?? 0,
      enlem: (map['enlem'] as num?)?.toDouble() ?? 0.0,
      boylam: (map['boylam'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
