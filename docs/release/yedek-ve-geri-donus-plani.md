# Yedek ve Geri Donus Plani

Son guncelleme: 2026-05-11

## Mevcut teknik temel

- Uygulama JSON formatinda guvenlik yedegi uretiyor.
- Yedekler cihazda `Tarim360Yedekleri` klasorune yaziliyor.
- Yedek dosyalari checksum ile dogrulaniyor.
- Geri yukleme oncesinde emniyet yedegi alinip sorun olursa eski veri geri getirilmeye calisiliyor.

## Canliya cikmadan once

1. Son release adayinda cihazdan manuel yedek alin.
2. Bulut kullaniyorsan Firestore verisinin ayri bir disa aktarimini yap.
3. Uretime verecegin AAB dosyasini ve surum notunu ayri bir arsiv klasorunde sakla.
4. `pubspec.yaml` ve yayinlanan `versionCode` bilgisini kayda al.

## Yayin sirasinda

1. Ilk production guncellemesini dogrudan yuzde 100 acma.
2. Ilk yayin yeni uygulamaysa once internal veya closed test ile dogrula.
3. Sonraki guncellemelerde staged rollout kullan:
   - %10
   - %25
   - %50
   - %100
4. Crashlytics panelini ve tester geri bildirimlerini ayni gun takip et.

## Acil durum geri donus plani

1. Ciddi hata varsa Play Console uzerinden rollout'u durdur.
2. Sorunlu surum yeni kullanicilara gitmesin diye yayini durdurduktan sonra duzeltilmis yeni bir build hazirla.
3. Veri bozulmasi varsa:
   - Bulut yazmalarini gecici olarak kisitla.
   - Son saglam yedekleri dogrula.
   - Gerekirse cihaz veya bulut yedeklerinden geri yukle.
4. Kullaniciya yayin notu veya destek kanali uzerinden acik bilgi ver.

## Operasyon notu

Google Play'de bir onceki surume `versionCode` dusurerek donulemez. Geri donus pratikte ya rollout'u durdurmak ya da daha yuksek `versionCode` ile hizli hotfix yayimlamaktir.
