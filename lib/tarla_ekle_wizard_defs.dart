enum TarlaEkleAdimi {
  temelBilgi,
  konum,
  sinir,
  fotoNot,
  onay,
}

extension TarlaEkleAdimiExt on TarlaEkleAdimi {
  String get baslik {
    switch (this) {
      case TarlaEkleAdimi.temelBilgi:
        return 'Temel bilgi';
      case TarlaEkleAdimi.konum:
        return 'Konum';
      case TarlaEkleAdimi.sinir:
        return 'Sinir';
      case TarlaEkleAdimi.fotoNot:
        return 'Foto / Not';
      case TarlaEkleAdimi.onay:
        return 'Onay';
    }
  }

  String get aciklama {
    switch (this) {
      case TarlaEkleAdimi.temelBilgi:
        return 'Tarla adi zorunludur. Urun ve alan bilgisi istege baglidir.';
      case TarlaEkleAdimi.konum:
        return 'Konum zorunludur. GPS ile konum alip devam edebilirsin.';
      case TarlaEkleAdimi.sinir:
        return 'Sinir noktasi istege baglidir. Cizersen alan otomatik hesaplanir.';
      case TarlaEkleAdimi.fotoNot:
        return 'Not ve fotograflar istege baglidir.';
      case TarlaEkleAdimi.onay:
        return 'Kaydetmeden once bilgileri son kez kontrol et.';
    }
  }
}

