# 🌱 Tarım360 — Akıllı Tarla ve Çiftlik Yönetim Sistemi

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/SQLite-Offline--First-003B57?style=for-the-badge&logo=sqlite&logoColor=white" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
  <img src="https://img.shields.io/badge/Version-1.1.0-brightgreen?style=for-the-badge" />
</p>

> **Tarım360**, modern çiftçilerin tarlalarını, tarımsal faaliyetlerini (sulama, gübreleme, ilaçlama), gelir/gider dengelerini ve sezonluk analizlerini tek bir merkezden kolayca yönetmelerini sağlayan tam kapsamlı bir mobil uygulamadır.

---

## 📱 Öne Çıkan Özellikler

### 🗺️ Akıllı Tarla Yönetimi & Harita
* **GPS & Uydu Destekli Sınır Çizimi:** OpenStreetMap ve flutter_map entegrasyonu ile tarlanın köşe koordinatlarını harita üzerinde işaretleme ve sınırlarını görselleştirme.
* **Detaylı Tarla Kartları:** Ürün cinsi, alan (dönüm/m²), ekim tarihi, toprak tipi ve güncel durum bilgileri.
* **Arşivleme & Geri Yükleme:** Sezonu biten veya pasif tarlaları güvenle arşivleme.

### 🚜 Tarımsal İşlem Takibi
* **Kategorik İşlemler:** Sulama, Gübreleme, İlaçlama, Sürüm ve Hasat gibi standart işlemler.
* **Özel İşlem Tipleri:** Çiftçinin kendi çalışma rutinine göre yeni işlem türü tanımlayabilmesi.
* **Akıllı Uyarı Eşikleri:** Sulama ve bakım zamanlarını takip eden kritik gün eşik uyarıları (sulama takip algoritmaları).

### 💰 Finans & Maliyet Yönetimi
* **Gelir & Gider Kayıtları:** Tarla bazlı veya işletme geneli maliyet ve hasat kazançları.
* **Net Kâr / Zarar Analizi:** Dönemsel kârlılık oranları, harcama dağılım grafikleri.
* **Görsel İstatistikler:** Sezonluk finansal sağlığı özetleyen dinamik grafik bileşenleri.

### ☁️ Hibrit Mimari (Offline-First + Cloud Sync)
* **SQLite Yerel Veritabanı:** İnternet çekmeyen arazilerde kesintisiz, hızlı ve güvenli çalışma.
* **Firebase Firestore Senkronizasyonu:** İnternet bağlantısı sağlandığında yerel verilerin otomatik olarak buluta yedeklenmesi.
* **Aile & Ekip Paylaşımı:** Tek bir aile/ekip kodu veya QR kod ile birden fazla cihazdan aynı çiftlik verilerine anlık erişim.
* **Akıllı Bağlantı Algılama:** Ağ kesintilerini anlık tespit eden ve bağlantı kurulduğunda senkronizasyonu tetikleyen yapı.

### 📄 Profesyonel PDF Raporlama
* **Sezonluk Tarla Analiz Raporu:** Tarlaya ait tüm geçmiş faaliyetleri, maliyetleri ve durum özetini içeren detaylı PDF çıktısı.
* **Konsolide Finans Raporu:** Tüm tarlaların gelir/gider ve kâr dökümünü tek bir kurumsal raporda toplama.
* **Anlık Paylaşım:** Oluşturulan raporları WhatsApp, E-posta ve diğer kanallardan tek dokunuşla paylaşabilme.

### 🤖 Yapay Zekâ Destekli Tarım Danışmanı
* **Google Gemini API Entegrasyonu:** Bitki hastalıkları, gübreleme takvimleri ve tarımsal verimlilik soruları için interaktif yapay zekâ asistanı.
* **Hava Durumu Servisi:** Tarlanın konumuna göre anlık ve tahmini hava durumu bilgileri.

---

## 🛠️ Mimari ve Teknolojiler

| Katman | Teknoloji / Kütüphane | Kullanım Amacı |
|---|---|---|
| **Framework** | Flutter 3.x (Dart 3.x) | Çapraz platform mobil arayüz geliştirme |
| **State Management** | Riverpod | Reaktif, test edilebilir ve ölçeklenebilir durum yönetimi |
| **Yerel Veritabanı** | SQLite (`sqflite`) | Offline-first yerel depolama ve hızlı sorgular |
| **Bulut Veritabanı** | Firebase Firestore | Gerçek zamanlı veri senkronizasyonu ve ekip paylaşımı |
| **Kimlik Doğrulama** | Firebase Auth & Custom Session | Aile/ekip kodu tabanlı güvenli oturum yönetimi |
| **Harita & Konum** | `flutter_map`, `latlong2`, `geolocator` | GPS konum tespiti ve poligon sınır çizimi |
| **Raporlama** | `pdf`, `printing`, `path_provider` | Dinamik vektörel PDF oluşturma ve paylaşma |
| **Yapay Zekâ** | Google Generative AI (Gemini) | Akıllı tarım tavsiyeleri ve danışmanlık |
| **Ağ Takibi** | `connectivity_plus` | Çevrimdışı/çevrimiçi durum izleme ve otomatik sync |

---

## 📂 Proje Dizin Yapısı

```text
lib/
├── main.dart                      # Uygulama başlangıç noktası ve tema yapılandırması
├── app_session_service.dart       # Oturum ve aile kodu yönetim servisi
├── cloud_sync_service.dart        # Firestore çift yönlü veri senkronizasyonu
├── database_helper.dart           # SQLite CRUD ve veritabanı şema yönetimi
├── export_service.dart            # Analiz ve veri dışa aktarma servisi
├── providers/                     # Riverpod state sağlayıcıları
│   ├── auth_provider.dart
│   ├── fields_provider.dart
│   └── language_provider.dart
├── screens/                       # Uygulama ekranları (UI Views)
│   ├── home_screen.dart           # Ana kontrol paneli ve tarla listesi
│   ├── add_field_screen.dart      # Yeni tarla ekleme sihirbazı
│   ├── field_detail_screen.dart   # Tarla işlem detayları ve işlem kaydı
│   ├── field_summary_screen.dart  # Sezonluk özet ve işlem geçmişi
│   ├── financial_dashboard_screen.dart # Finansal kâr/zarar paneli
│   ├── satellite_map_screen.dart  # Harita ve GPS sınır çizim ekranı
│   └── ai_advisor_screen.dart     # Gemini destekli yapay zekâ danışmanı
├── services/                      # Harici servis entegrasyonları
│   ├── gemini_service.dart        # Google Gemini AI servisi
│   ├── pdf_report_service.dart    # Kurumsal PDF üretim motoru
│   └── weather_service.dart       # Hava durumu API servisi
├── widgets/                       # Yeniden kullanılabilir UI bileşenleri
└── utils/                         # Yardımcı fonksiyonlar, loglama ve sabitler
```

---

## 🚀 Yerel Geliştirme ve Kurulum

Projeyi yerel ortamınızda çalıştırmak için aşağıdaki adımları takip edebilirsiniz:

1. **Repoyu Klonlayın:**
   ```bash
   git clone https://github.com/kilicliali/tarim360.git
   cd tarim360
   ```

2. **Bağımlılıkları Yükleyin:**
   ```bash
   flutter pub get
   ```

3. **Firebase Yapılandırması:**
   * Kendi Firebase projenizi oluşturun.
   * `google-services.json` dosyasını `android/app/` dizinine yerleştirin.
   * `flutterfire configure` komutunu çalıştırarak `lib/firebase_options.dart` dosyasını oluşturun.

4. **Uygulamayı Çalıştırın:**
   ```bash
   flutter run
   ```

---

## 👨‍💻 Geliştirici

**Ali Kılıçlı**  
* GitHub: [@kilicliali](https://github.com/kilicliali)  
* Proje: [Tarım360 Repository](https://github.com/kilicliali/tarim360)
