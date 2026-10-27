# Play Console Izin Aciklamalari

Son guncelleme: 2026-05-11

## Konum izni

Kisa aciklama:
Tarla merkezini GPS ile kaydetmek, haritada gostermek ve sinir noktasi eklemek icin yalnizca uygulama kullanilirken konum izni istenir.

Politika notu:
- Yalnizca `ACCESS_COARSE_LOCATION` ve `ACCESS_FINE_LOCATION` kullaniliyor.
- `ACCESS_BACKGROUND_LOCATION` kullanilmiyor.
- Konum verisi kullanici bir tarla uzerinde islem yaptiginda aliniyor.

## Kamera izni

Kisa aciklama:
Kamera izni, tarla veya bitki fotografi cekmek ve ekip QR kodunu okutmak icin kullanilir.

Politika notu:
- Kamera ozelligi istege baglidir.
- Kullanici kamerayi acmadikca bu izin talep edilmez.

## Data safety formu icin hatirlatici

- Yerel mod ile bulut modu farkli beyanlar gerektirebilir; formu doldurmadan once son veri akisini tekrar kontrol edin.
- Firebase Authentication, Cloud Firestore ve Crashlytics kullanimini Play Console Data safety formunda ayri ayri beyan edin.
- Internal test asamasinda teknik zorunluluklar production kadar kati olmayabilir; production oncesi formu tamamlayin.
