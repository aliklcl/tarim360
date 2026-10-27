# 🌱 Tarım360 — Akıllı Tarla Yönetim Uygulaması

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" />
  <img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android" />
  <img src="https://img.shields.io/badge/Version-1.1.0-brightgreen" />
</p>

> Çiftçilere tarlalarını, işlemlerini ve finanslarını kolayca takip etmelerini sağlayan mobil uygulama.

---

## 📱 Özellikler

### 🗺️ Tarla Yönetimi
- Tarla ekleme, düzenleme, arşivleme
- GPS ile tarla sınırlarını harita üzerinde çizme (flutter_map)
- QR kod ile tarla/ekip paylaşımı

### 📋 İşlem Takibi
- Sulama, gübre, ilaç işlemlerini kaydetme
- Özel işlem tipleri oluşturma
- İşlem geçmişi ve maliyet takibi

### 💰 Finans Modülü
- Gelir/gider takibi
- Tarla bazlı veya genel finansal görünüm
- Net kâr/zarar analizi ve grafik
- PDF finansal rapor oluşturma

### ☁️ Bulut & Senkronizasyon
- Firebase Firestore ile gerçek zamanlı senkronizasyon
- Aile/ekip hesabı — birden fazla kullanıcı aynı hesapta çalışabilir
- Çevrimdışı algılama + bağlantı gelince otomatik sync

### 📄 Raporlar
- Sezonluk PDF analiz raporu
- Finans raporu (tüm tarlalar tek PDF)
- Paylaş butonu ile WhatsApp, e-posta paylaşımı

### 🤖 AI Entegrasyonu
- Google Gemini API ile tarım tavsiyesi
- Hava durumu servisi

---

## 🛠️ Teknolojiler

| Kategori | Teknoloji |
|----------|-----------|
| Framework | Flutter 3.x |
| Dil | Dart |
| Yerel DB | SQLite (sqflite) |
| Bulut DB | Firebase Firestore |
| Auth | Firebase Auth |
| State | Riverpod |
| Harita | flutter_map + OpenStreetMap |
| PDF | pdf package |
| AI | Google Gemini API |

---

## 🚀 Kurulum

> **Not:** Bu proje Firebase kullanmaktadır. Çalıştırmak için kendi Firebase projenizi oluşturmanız gerekir.

```bash
# Depoyu klonlayın
git clone https://github.com/kilicliali/tarim360.git
cd tarim360

# Bağımlılıkları yükleyin
flutter pub get
```

Firebase kurulumu için:
1. [Firebase Console](https://console.firebase.google.com)'dan yeni proje oluşturun
2. `google-services.json` dosyasını `android/app/` klasörüne ekleyin
3. `flutterfire configure` ile `lib/firebase_options.dart` oluşturun

---

## 📁 Proje Yapısı

```
lib/
├── screens/          # Ekranlar
├── services/         # PDF rapor servisi
├── providers/        # Riverpod providers
├── widgets/          # Ortak widgetlar
├── utils/            # Yardımcı fonksiyonlar
├── cloud_sync_service.dart
├── database_helper.dart
└── export_service.dart
```

---

## 👨‍💻 Geliştirici

**Ali Kılıç** — [@kilicliali](https://github.com/kilicliali)
