import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../backup_service.dart';
import '../islem_turu_model.dart';
import '../cloud_sync_service.dart';
import '../database_helper.dart';
import '../islem_model.dart';
import '../sinir_noktasi_model.dart';
import '../tarla_model.dart';

/// Sulama uyarı eşik değerleri — tüm ekranlarda bu sabitler kullanılmalı
const int sulamaDikkatGunSiniri = 3;   // 3+ gün → Dikkat
const int sulamaKritikGunSiniri = 7;   // 7+ gün → Kritik / hatırlatma listesine gir

final Map<String, Uint8List> _base64OnizlemeCache = <String, Uint8List>{};
bool _kameraBilgilendirmesiGosterildi = false;
bool _konumBilgilendirmesiGosterildi = false;
bool _acilistaKonumIstendi = false;

Uint8List base64OnizlemeCoz(String veri) {
  final cache = _base64OnizlemeCache[veri];
  if (cache != null) return cache;
  final cozulmus = base64Decode(veri);
  if (_base64OnizlemeCache.length > 120) {
    _base64OnizlemeCache.remove(_base64OnizlemeCache.keys.first);
  }
  _base64OnizlemeCache[veri] = cozulmus;
  return cozulmus;
}

bool bulutDestegiAktif() {
  if (kIsWeb) return false;
  return defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux;
}

// ─── İsim doğrulama ve formatlama ────────────────────────────────────────────

/// İsim doğrulama: en az 2 karakter, sadece harf ve boşluk.
/// Hata varsa Türkçe mesaj döner, geçerliyse null döner.
String? isimDogrula(String ad) {
  final temiz = ad.trim();
  if (temiz.isEmpty) return 'İsim alanı boş bırakılamaz.';
  if (temiz.length < 2) return 'İsim en az 2 karakter olmalı.';
  // Türkçe karakterler dahil harf + boşluk
  if (!RegExp(r'^[a-zA-ZçÇğĞıİöÖşŞüÜ ]+$').hasMatch(temiz)) {
    return 'İsim sadece harf ve boşluk içerebilir.';
  }
  return null; // geçerli
}

/// Her kelimenin ilk harfini büyük, geri kalanını küçük yapar.
String isimFormatla(String ad) {
  return ad.trim().split(RegExp(r'\s+')).map((kelime) {
    if (kelime.isEmpty) return '';
    return kelime[0].toUpperCase() + kelime.substring(1).toLowerCase();
  }).join(' ');
}

Future<bool> _izinBilgilendirmeDialoguGoster(
  BuildContext context, {
  required String baslik,
  required String aciklama,
  String onayMetni = 'Devam et',
  String iptalMetni = 'Simdilik degil',
}) async {
  if (!context.mounted) return false;
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(baslik),
      content: Text(aciklama),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(iptalMetni),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(onayMetni),
        ),
      ],
    ),
  );
  return sonuc == true;
}

Future<bool> kameraBilgilendirmesiniGoster(
  BuildContext context, {
  String amac = 'tarla fotograflari cekmek ve QR kod okutmak',
}) async {
  if (_kameraBilgilendirmesiGosterildi) return true;
  final onay = await _izinBilgilendirmeDialoguGoster(
    context,
    baslik: 'Kamera izni',
    aciklama:
        'Uygulama kamerayi sadece $amac icin kullanir. Fotograf ve QR verileri sen istemedikce paylasilmaz.',
    onayMetni: 'Kamerayi ac',
  );
  if (onay) {
    _kameraBilgilendirmesiGosterildi = true;
  }
  return onay;
}

Future<bool> konumBilgilendirmesiniGoster(
  BuildContext context, {
  String amac = 'tarla sınırlarınızı harita üzerinde çizebilmek ve konumunuza en uygun hava durumunu sunabilmek',
}) async {
  if (_konumBilgilendirmesiGosterildi) return true;
  final onay = await _izinBilgilendirmeDialoguGoster(
    context,
    baslik: 'Konum İzni Gerekli',
    aciklama:
        'Tarlalarınızın sınırlarını harita üzerinde kolayca çizebilmeniz ve konumunuza en uygun hava durumu tahminlerini sunabilmemiz için konum iznine ihtiyacımız var. Devam etmek için izni onaylayabilirsiniz.',
    onayMetni: 'Devam Et',
    iptalMetni: 'Şimdilik Değil',
  );
  if (onay) {
    _konumBilgilendirmesiGosterildi = true;
  }
  return onay;
}

Future<void> kaliciReddedilenKonumIzniIcinAyarlaraYonlendir(
  BuildContext context,
) async {
  final ayarlaraGit = await _izinBilgilendirmeDialoguGoster(
    context,
    baslik: 'Konum İzni Kapalı',
    aciklama:
        'Konum izni kalıcı olarak kapatıldığı için uygulama tarla konumu alamıyor. Dilerseniz ayarlardan izni tekrar aktif hale getirebilirsiniz.',
    onayMetni: 'Ayarları Aç',
    iptalMetni: 'Vazgeç',
  );
  if (ayarlaraGit) {
    await Geolocator.openAppSettings();
  }
}

Future<bool> konumServisiKapaliysaAyarlaraYonlendir(
  BuildContext context, {
  String? baslik,
  String? aciklama,
}) async {
  if (kIsWeb) return true;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return true;
  }

  final servisAcik = await Geolocator.isLocationServiceEnabled();
  if (servisAcik) return true;
  if (!context.mounted) return false;

  final ayarlaraGit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(baslik ?? 'Konum Servisi Kapalı'),
      content: Text(aciklama ?? 'Tarlalarınızın hava durumunu ve konumunu otomatik belirleyebilmemiz için konum servisinin açık olması işinizi kolaylaştıracaktır. Şimdi açmak ister misiniz?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Daha Sonra'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Konumu Aç'),
        ),
      ],
    ),
  );

  if (ayarlaraGit == true) {
    await Geolocator.openLocationSettings();
  }
  return false;
}

Future<void> acilistaKonumIzniIste(BuildContext context) async {
  if (_acilistaKonumIstendi) return;
  _acilistaKonumIstendi = true;

  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  final servisAcik = await konumServisiKapaliysaAyarlaraYonlendir(
    context,
    baslik: 'Konum Servisi Kapalı',
    aciklama:
        'Tarlalarınızın hava durumunu ve konumunu otomatik belirleyebilmemiz için konum servisinin açık olması işinizi kolaylaştıracaktır. Şimdi açmak ister misiniz?',
  );
  if (!context.mounted) return;
  if (!servisAcik) return;

  var izin = await Geolocator.checkPermission();
  if (!context.mounted) return;
  if (izin == LocationPermission.denied) {
    final izinIstensin = await konumBilgilendirmesiniGoster(
      context,
      amac: 'tarlalarınızın sınırlarını çizebilmek ve size özel doğru hava durumu sunabilmek',
    );
    if (!izinIstensin) return;
    izin = await Geolocator.requestPermission();
  }
  if (izin == LocationPermission.deniedForever) {
    if (!context.mounted) return;
    await kaliciReddedilenKonumIzniIcinAyarlaraYonlendir(context);
  }
}

String bulutHataMetni(Object error) {
  if (error is TimeoutException) {
    return 'Bulut baglantisi zaman asimina ugradi. Interneti ve Firebase servislerini kontrol et.';
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Firebase giris yontemi kapali. Firebase Console > Authentication > Sign-in method altinda ilgili yontemi (Email/Google) ac.';
      case 'network-request-failed':
        return 'Firebase oturumu acilamadi. Telefon internete cikabiliyor mu ve Google Play Services guncel mi kontrol et.';
      case 'invalid-credential':
        return 'Gecersiz kimlik bilgisi. E-posta/sifreyi veya Google hesabini tekrar kontrol et.';
      case 'user-not-found':
        return 'Bu e-posta ile kayitli hesap bulunamadi.';
      case 'wrong-password':
      case 'invalid-password':
        return 'Sifre hatali.';
      case 'invalid-email':
        return 'E-posta formati gecersiz.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kayitli. Giris Yap sekmesini kullan.';
      case 'invalid-phone-number':
        return 'Telefon numarasi gecersiz. Ornek format: +90555... veya 05xx...';
      case 'invalid-verification-code':
        return 'SMS dogrulama kodu hatali.';
      case 'invalid-verification-id':
        return 'SMS oturumu gecersiz, kodu yeniden gonder.';
      case 'too-many-requests':
        return 'Cok fazla deneme yapildi. Biraz bekleyip tekrar dene.';
      default:
        final detay = error.message?.trim();
        if (detay != null && detay.isNotEmpty) {
          return 'Firebase girisi basarisiz (${error.code}): $detay';
        }
        return 'Firebase girisi basarisiz: ${error.code}';
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Cloud Firestore izin vermedi. Firestore kurallarini kontrol et.';
      case 'unavailable':
        return 'Cloud Firestore su anda ulasilamiyor. Interneti veya Firebase durumunu tekrar kontrol et.';
      case 'unauthenticated':
        return 'Cloud Firestore icin Firebase oturumu gecersiz.';
      default:
        return 'Bulut baglantisi hatasi: ${error.code}';
    }
  }

  if (error is PlatformException) {
    final raw = '${error.code} ${error.message}'.toLowerCase();
    if (raw.contains('sign_in_failed') ||
        raw.contains('developer_error') ||
        raw.contains('10')) {
      return 'Google girisi basarisiz. Android SHA ve google-services.json ayarlari tekrar kontrol edilmeli.';
    }
    if (raw.contains('network')) {
      return 'Google/Firebase baglantisi icin internet veya Google Play Services kontrol edilmeli.';
    }
    return 'Platform hatasi: ${error.message ?? error.code}';
  }
  if (error is Exception) {
    final str = error.toString();
    if (str.startsWith('Exception: ')) return str.substring(11);
    return str;
  }

  return 'Bulut baglantisi acilamadi. Firebase ayarlari veya internet baglantisi kontrol edilmeli.';
}

String guvenliKodNormalizeEt(String kod) {
  var temiz = kod.trim();
  // Türkçe I/ı/İ/i dönüştürme ve temizleme
  temiz = temiz.replaceAll('ı', 'i').replaceAll('İ', 'I');
  final sb = StringBuffer();
  for (var i = 0; i < temiz.length; i++) {
    final char = temiz[i];
    if (char == 'i') {
      sb.write('I');
    } else {
      sb.write(char.toUpperCase());
    }
  }
  return sb.toString().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String ortakTarlaKodQrMetniOlustur(String kod) {
  return 'TARIM360|${guvenliKodNormalizeEt(kod)}';
}

String ortakTarlaKodunuQrMetnindenCoz(String raw) {
  final temiz = raw.trim();
  if (temiz.isEmpty) return '';
  if (temiz.toUpperCase().startsWith('TARIM360|')) {
    return guvenliKodNormalizeEt(temiz.substring('TARIM360|'.length));
  }
  return guvenliKodNormalizeEt(temiz);
}

String arsivdenKaliciSilinmeMetni(DateTime? silinmeTarihi) {
  if (silinmeTarihi == null) return '30 gun arsivde tutulur';
  final sonTarih = silinmeTarihi.add(const Duration(days: 30));
  final kalanGun = sonTarih.difference(turkiyeSimdi()).inDays;
  if (kalanGun <= 0) {
    return 'Bugun kalici olarak silinir';
  }
  return '$kalanGun gun sonra kalici silinir';
}

DateTime turkiyeSimdi() {
  return DateTime.now();
}

String formatTarihSaat(DateTime tarih) {
  return DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(tarih);
}

DateTime? parseKayitZamani(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

double parselAlaniMetrekare(List<SinirNoktasi> noktalar) {
  if (noktalar.length < 3) return 0;

  const dunyaYaricapi = 6378137.0;
  var toplam = 0.0;
  for (var i = 0; i < noktalar.length; i++) {
    final mevcut = noktalar[i];
    final sonraki = noktalar[(i + 1) % noktalar.length];
    final enlem1 = mevcut.enlem * math.pi / 180;
    final enlem2 = sonraki.enlem * math.pi / 180;
    final boylam1 = mevcut.boylam * math.pi / 180;
    final boylam2 = sonraki.boylam * math.pi / 180;
    toplam += (boylam2 - boylam1) * (2 + math.sin(enlem1) + math.sin(enlem2));
  }

  return (toplam * dunyaYaricapi * dunyaYaricapi / 2).abs();
}

String formatAlanOzeti({
  double? alanMetrekare,
  double? alanDekar,
  String? varsayilanMetin,
}) {
  if (alanMetrekare != null && alanMetrekare > 0) {
    return '${alanMetrekare.toStringAsFixed(0)} m2';
  }
  if (varsayilanMetin != null && varsayilanMetin.trim().isNotEmpty) {
    final temiz = varsayilanMetin.trim();
    if (temiz.contains('m2 /')) {
      return temiz.split('/').first.trim();
    }
    return temiz;
  }
  return 'Alan bilgisi yok';
}

class TarlaSezonOzeti {
  const TarlaSezonOzeti({
    required this.sulamaSayisi,
    required this.gubreSayisi,
    required this.ilacSayisi,
  });

  final int sulamaSayisi;
  final int gubreSayisi;
  final int ilacSayisi;
}

class AylikIslemYogunlugu {
  const AylikIslemYogunlugu({
    required this.ay,
    required this.sulama,
    required this.gubre,
    required this.ilac,
    required this.diger,
  });

  final DateTime ay;
  final int sulama;
  final int gubre;
  final int ilac;
  final int diger;

  int get toplam => sulama + gubre + ilac + diger;
}

TarlaSezonOzeti tarlaSezonOzetiHesapla(
  Tarla tarla,
  List<Islem> islemler, {
  List<IslemTuruTanim> ozelTipler = const [],
}) {
  var sulama = 0;
  var gubre = 0;
  var ilac = 0;

  // Custom tiplerin kategori haritasini olustur
  final kategoriMap = <String, String>{};
  for (final tip in ozelTipler) {
    if (tip.kategori.isNotEmpty) {
      kategoriMap[tip.ad] = tip.kategori;
    }
  }

  for (final islem in islemler) {
    final efektivTur = kategoriMap[islem.tur] ?? islem.tur;
    if (efektivTur == 'Sulama') sulama++;
    if (efektivTur == 'Gubre') gubre++;
    if (efektivTur == 'Ilac') ilac++;
  }

  return TarlaSezonOzeti(
    sulamaSayisi: sulama,
    gubreSayisi: gubre,
    ilacSayisi: ilac,
  );
}

List<AylikIslemYogunlugu> aylikIslemYogunluguHesapla(
  List<Islem> islemler, {
  int aySayisi = 6,
}) {
  final simdi = turkiyeSimdi();
  final ilkAy = DateTime(simdi.year, simdi.month - (aySayisi - 1));
  final aylikSayac = <String, Map<String, int>>{};

  for (final kayit in islemler) {
    final tarih = parseKayitZamani(kayit.baslangicZamani) ?? turkiyeSimdi();
    final ayTarihi = DateTime(tarih.year, tarih.month);
    if (ayTarihi.isBefore(ilkAy)) continue;

    final anahtar =
        '${ayTarihi.year}-${ayTarihi.month.toString().padLeft(2, '0')}';
    final sayac = aylikSayac.putIfAbsent(
      anahtar,
      () => {'Sulama': 0, 'Gubre': 0, 'Ilac': 0, '_diger': 0},
    );
    if (sayac.containsKey(kayit.tur)) {
      sayac[kayit.tur] = (sayac[kayit.tur] ?? 0) + 1;
    } else {
      sayac['_diger'] = (sayac['_diger'] ?? 0) + 1;
    }
  }

  return List.generate(aySayisi, (index) {
    final ay = DateTime(simdi.year, simdi.month - (aySayisi - 1 - index));
    final anahtar = '${ay.year}-${ay.month.toString().padLeft(2, '0')}';
    final sayac = aylikSayac[anahtar] ??
        const {'Sulama': 0, 'Gubre': 0, 'Ilac': 0, '_diger': 0};
    return AylikIslemYogunlugu(
      ay: ay,
      sulama: sayac['Sulama'] ?? 0,
      gubre: sayac['Gubre'] ?? 0,
      ilac: sayac['Ilac'] ?? 0,
      diger: sayac['_diger'] ?? 0,
    );
  });
}

List<String> fotoListesiCoz(String value) {
  final temiz = value.trim();
  if (temiz.isEmpty) return const [];
  if (temiz.startsWith('[')) {
    try {
      final jsonDegeri = jsonDecode(temiz);
      if (jsonDegeri is List) {
        return jsonDegeri.whereType<String>().where((e) => e.trim().isNotEmpty).toList();
      }
    } catch (_) {}
  }
  return [temiz];
}

String fotoListesiniKaydet(List<String> fotolar) {
  final temiz = fotolar.where((e) => e.trim().isNotEmpty).toList(growable: false);
  if (temiz.isEmpty) return '';
  if (temiz.length == 1) return temiz.first;
  return jsonEncode(temiz);
}

bool get kameraDestekleniyor {
  return !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

Future<List<String>> galeridenFotografSec() async {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    final picker = ImagePicker();
    final secilenler = await picker.pickMultiImage(
      imageQuality: 60,
      maxWidth: 600,
      maxHeight: 600,
    );
    final sonuc = <String>[];
    for (final dosya in secilenler) {
      final bytes = await dosya.readAsBytes();
      if (bytes.isEmpty) continue;
      sonuc.add(base64Encode(bytes));
    }
    return sonuc;
  }

  final secim = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
    allowMultiple: true,
  );
  if (secim == null || secim.files.isEmpty) return const [];

  final sonuc = <String>[];
  for (final dosya in secim.files) {
    final bytes = dosya.bytes;
    if (bytes == null || bytes.isEmpty) continue;
    sonuc.add(base64Encode(bytes));
  }
  return sonuc;
}

Future<String?> kameradanFotografCek({
  BuildContext? context,
}) async {
  if (kameraDestekleniyor) {
    if (context != null) {
      final devam = await kameraBilgilendirmesiniGoster(
        context,
        amac: 'tarla fotograflari cekmek',
      );
      if (!devam) return null;
    }
    final picker = ImagePicker();
    final dosya = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (dosya == null) return null;
    final bytes = await dosya.readAsBytes();
    if (bytes.isEmpty) return null;
    return base64Encode(bytes);
  }

  throw Exception('Bu cihazda kamera ile fotograf cekme desteklenmiyor');
}

DateTime? sonIslemTarihi(Tarla tarla) {
  final tarihler = [
    tarla.sonSulama,
    tarla.sonGubre,
    tarla.sonIlac,
  ].whereType<DateTime>().toList();

  if (tarihler.isEmpty) return null;
  tarihler.sort((a, b) => b.compareTo(a));
  return tarihler.first;
}

String sonIslemEtiketi(Tarla tarla) {
  final sonTarih = sonIslemTarihi(tarla);
  if (sonTarih == null) return 'Kayit yok';
  if (tarla.sonSulama == sonTarih) return 'Sulama';
  if (tarla.sonGubre == sonTarih) return 'Gubre';
  if (tarla.sonIlac == sonTarih) return 'Ilac';
  return 'Kayit yok';
}

bool sulamaHatirlatmasiVar(Tarla tarla) {
  final sonSulama = tarla.sonSulama;
  if (sonSulama == null) return true;
  return turkiyeSimdi().difference(sonSulama).inDays >= 7;
}

Future<void> arsivSuresiDolmusKayitlariTemizle({
  required bool bulutEtkin,
  required String aileKodu,
}) async {
  if (bulutEtkin) {
    await CloudSyncService.instance.suresiDolmusArsivTarlalariTemizle(aileKodu);
    return;
  }

  final esik = DateTime.now().subtract(const Duration(days: 30));
  final silinecekler =
      await DatabaseHelper.instance.suresiDolmusSilinenTarlalar(esik);
  for (final tarla in silinecekler) {
    if (tarla.id != null) {
      await DatabaseHelper.instance.tarlaKaliciSil(tarla.id!);
    }
  }
}

Future<void> guvenlikYedegiAl(String sebep) async {
  try {
    await BackupService.guvenlikYedegiOlustur(sebep: sebep);
  } catch (_) {}
}

String sulamaHatirlatmaMetni(Tarla tarla) {
  final sonSulama = tarla.sonSulama;
  if (sonSulama == null) {
    return '${tarla.ad}: son sulama kaydi yok.';
  }

  final gun = turkiyeSimdi().difference(sonSulama).inDays;
  return '${tarla.ad}: $gun gundur sulanmadi. Son sulama ${formatTarihSaat(sonSulama)}.';
}

Future<void> tarlaAlaniniSinirdanEsitle(Tarla tarla) async {
  final tarlaId = tarla.id;
  if (tarlaId == null) return;

  final sinirNoktalari = await DatabaseHelper.instance.tarlaSinirNoktalari(tarlaId);
  if (sinirNoktalari.length < 3) return;

  final alanMetrekare = parselAlaniMetrekare(sinirNoktalari);
  final guncelAlanYazisi = formatAlanOzeti(
    alanMetrekare: alanMetrekare,
  );

  final farkMetrekare = (tarla.alanMetrekare ?? 0) - alanMetrekare;
  final ayniMi = farkMetrekare.abs() < 0.5 &&
      tarla.alan.trim() == guncelAlanYazisi;

  tarla
    ..alanMetrekare = alanMetrekare
    ..alanDekar = null
    ..alan = guncelAlanYazisi;

  if (!ayniMi) {
    await DatabaseHelper.instance.tarlaGuncelle(tarla);
  }
}

String aciliyetMetni(Tarla tarla) {
  if (tarla.sonSulama == null) return 'Kritik';

  final gun = turkiyeSimdi().difference(tarla.sonSulama!).inDays;
  if (gun >= 7) return 'Kritik';
  if (gun >= 3) return 'Dikkat';
  return 'Normal';
}

Color aciliyetRengi(Tarla tarla) {
  switch (aciliyetMetni(tarla)) {
    case 'Kritik':
      return Colors.red;
    case 'Dikkat':
      return Colors.orange;
    default:
      return Colors.green;
  }
}
