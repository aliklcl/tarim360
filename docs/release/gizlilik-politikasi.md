# Tarim360 Gizlilik Politikasi

Son guncelleme: 2026-05-11

Bu metin, Tarim360 uygulamasinin kullanici verilerini nasil isledigini aciklar. Uretime cikmadan once koseli parantezli alanlari kendi bilgilerinizle guncelleyin.

## Toplanan veriler

- Hesap verileri: Yerel hesapta kullanici adi, bulut hesapta e-posta adresi ve kimlik dogrulama bilgileri.
- Tarla verileri: Tarla adi, urun bilgisi, notlar, islem gecmisi, alan bilgisi, silme ve arsiv durumu.
- Konum verileri: Tarla merkezi ve kullanici tarafindan eklenen sinir noktalarinin koordinatlari.
- Medya verileri: Kullanici tarafindan eklenen tarla ve bitki fotograflari.
- Teknik hata verileri: Uygulama hatalari, cihaz modeli, uygulama surumu ve temel tanilama bilgileri. Bu veriler Firebase Crashlytics ile toplanir.

## Verileri neden kullaniyoruz

- Tarlalari kaydetmek, listelemek ve duzenlemek.
- Harita uzerinde tarla konumu ve sinirlarini gostermek.
- QR kod, fotograf ve rapor ozelliklerini calistirmak.
- Bulut modu acikken ayni ekip koduna bagli kullanicilar arasinda veri senkronizasyonu saglamak.
- Uygulama kararliligini izlemek ve hatalari duzeltmek.

## Veriler nerede tutulur

- Yerel modda veriler cihazdaki uygulama veritabani ve uygulama icinde olusturulan yedek dosyalarinda tutulur.
- Bulut modu aciksa veriler Firebase Authentication ve Cloud Firestore uzerinde saklanir.
- Yedek dosyalari cihazda uygulamanin belge klasoru altinda `Tarim360Yedekleri` dizininde tutulur.

## Verilerin paylasimi

- Veriler reklam amacli satilmaz.
- Bulut modunda ayni aile veya ekip kodunu kullanan yetkili kullanicilar ilgili tarla verilerine erisebilir.
- Teknik hata verileri Firebase Crashlytics hizmet saglayicisi ile paylasilir.

## Izinler

- Konum izni: Tarla konumu kaydetmek, guncellemek ve sinir noktasi eklemek icin istenir.
- Kamera izni: QR kod okutmak ve tarla veya bitki fotografi cekmek icin istenir.

Uygulama arka planda surekli konum takibi yapmaz.

## Veri guvenligi

- Yerel hesap oturumu cihazda saklanir.
- Yedek dosyalari butunluk kontrolu icin HMAC-SHA256 checksum ile isaretlenir.
- Uygulama ici kritik hatalar yayin sonrasi izlenebilmesi icin Crashlytics uzerinden raporlanir.

## Kullanici haklari

- Uygulama icinden kayitlarinizi silebilir, arsivden geri yukleyebilir veya yedek alabilirsiniz.
- Bulut hesabinizi kapatmak ya da veri silme talebi icin [ILETISIM_EPOSTASI] adresine ulasin.

## Cocuklarin gizliligi

Uygulama genel tuketici cocuk kitlesini hedeflemez.

## Iletisim

- Gelistirici/kurum: ALI KILICLI
- E-posta: kilicliali96@gmail.com
- Adres: Konya Karapinar
