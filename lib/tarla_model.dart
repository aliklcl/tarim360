class Tarla {
  int? id;
  String? remoteId;
  String ad;
  String urun;
  String alan;
  double? alanMetrekare;
  double? alanDekar;
  double? enlem;
  double? boylam;
  String notlar;
  String fotoBase64;
  bool silinmisMi;
  DateTime? silinmeTarihi;
  DateTime? sonSulama;
  DateTime? sonGubre;
  DateTime? sonIlac;

  Tarla({
    this.id,
    this.remoteId,
    required this.ad,
    this.urun = '',
    this.alan = '',
    this.alanMetrekare,
    this.alanDekar,
    this.enlem,
    this.boylam,
    this.notlar = '',
    this.fotoBase64 = '',
    this.silinmisMi = false,
    this.silinmeTarihi,
    this.sonSulama,
    this.sonGubre,
    this.sonIlac,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'remoteId': remoteId,
      'ad': ad,
      'urun': urun,
      'alan': alan,
      'alanMetrekare': alanMetrekare,
      'alanDekar': alanDekar,
      'enlem': enlem,
      'boylam': boylam,
      'notlar': notlar,
      'fotoBase64': fotoBase64,
      'silinmisMi': silinmisMi ? 1 : 0,
      'silinmeTarihi': silinmeTarihi?.toIso8601String(),
      'sonSulama': sonSulama?.toIso8601String(),
      'sonGubre': sonGubre?.toIso8601String(),
      'sonIlac': sonIlac?.toIso8601String(),
    };
  }

  factory Tarla.fromMap(Map<String, dynamic> map) {
    return Tarla(
      id: map['id'],
      remoteId: map['remoteId'] as String?,
      ad: map['ad'] as String? ?? '',
      urun: map['urun'] ?? '',
      alan: map['alan'] ?? '',
      alanMetrekare: (map['alanMetrekare'] as num?)?.toDouble(),
      alanDekar: (map['alanDekar'] as num?)?.toDouble(),
      enlem: (map['enlem'] as num?)?.toDouble(),
      boylam: (map['boylam'] as num?)?.toDouble(),
      notlar: map['notlar'] ?? '',
      fotoBase64: map['fotoBase64'] ?? '',
      silinmisMi: ((map['silinmisMi'] as num?)?.toInt() ?? 0) == 1,
      silinmeTarihi: map['silinmeTarihi'] != null
          ? DateTime.tryParse(map['silinmeTarihi'])?.toLocal()
          : null,
      sonSulama: map['sonSulama'] != null
          ? DateTime.tryParse(map['sonSulama'])?.toLocal()
          : null,
      sonGubre: map['sonGubre'] != null
          ? DateTime.tryParse(map['sonGubre'])?.toLocal()
          : null,
      sonIlac: map['sonIlac'] != null
          ? DateTime.tryParse(map['sonIlac'])?.toLocal()
          : null,
    );
  }
}
