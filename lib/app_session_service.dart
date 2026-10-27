import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/app_helpers.dart';
import 'islem_turu_model.dart';

class AppSessionService {
  AppSessionService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const _aileKoduKey = 'aktif_aile_kodu';
  static const _aileAdiKey = 'aktif_aile_adi';
  static const _sonAileKoduKey = 'son_aile_kodu';
  static const _bekleyenSilmelerKey = 'bekleyen_remote_silmeler';
  static const _kullaniciAdiKey = 'aktif_kullanici_adi';
  static const _pdfHatirlatmaKeyPrefix = 'pdf_hatirlatma_tarihi';
  static const _islemTurleriKeyPrefix = 'ozel_islem_turleri';
  static const _otomatikYedekSikligiGunKey = 'otomatik_yedek_sikligi_gun';
  static const _sonBasariliYedekTarihiKey = 'son_basarili_yedek_tarihi';
  static const _sonYedekHataMesajiKey = 'son_yedek_hata_mesaji';
  static const _authModeKey = 'aktif_auth_modu';
  static const _aktifKullaniciKey = 'aktif_kullanici_id';
  static const _kullaniciEmailKey = 'aktif_kullanici_email';
  static const _ortakTarlaKoduKey = 'aktif_ortak_tarla_kodu';
  static const _openAiApiKeyKey = 'openai_api_key';
  static const _geminiApiKeyKey = 'gemini_api_key';
  // ignore: unused_field
  static const _geminiApiKeySharedKey = 'gemini_api_key_shared';
  static const _yedekHmacAnahtariKey = 'yedek_hmac_anahtari';

  static Future<String?> _guvenliOku(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  static Future<void> _guvenliYaz(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      try {
        await _secureStorage.deleteAll();
        await _secureStorage.write(key: key, value: value);
      } catch (_) {}
    }
  }

  static Future<void> _guvenliSil(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}
    }
  }

  static String _silmeAnahtariOlustur(String aileKodu, String remoteId) {
    return '$aileKodu::$remoteId';
  }

  static String _pdfHatirlatmaAnahtari(String aileKodu) {
    return '$_pdfHatirlatmaKeyPrefix::$aileKodu';
  }

  static String _islemTurleriAnahtari(String aileKodu) {
    return '$_islemTurleriKeyPrefix::$aileKodu';
  }

  static Future<User> anonimOturumAc() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) {
      return auth.currentUser!;
    }

    final sonuc = await auth.signInAnonymously();
    return sonuc.user!;
  }

  static Future<String?> kayitliAileKodunuGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aileKoduKey);
  }

  static Future<void> aileKodunuKaydet(String aileKodu) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aileKoduKey, aileKodu);
    await prefs.setString(_sonAileKoduKey, aileKodu);
  }

  static Future<void> aileKodunuTemizle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_aileKoduKey);
  }

  static Future<String?> aileAdiniGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aileAdiKey);
  }

  static Future<void> aileAdiniKaydet(String aileAdi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aileAdiKey, aileAdi);
  }

  static Future<void> aileAdiniTemizle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_aileAdiKey);
  }

  static Future<String?> sonAileKodunuGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sonAileKoduKey);
  }

  static Future<String?> kullaniciAdiniGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kullaniciAdiKey);
  }

  static Future<void> authBilgisiniKaydet({
    required String mode,
    required String userId,
    String? email,
    String? sharedFarmCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _guvenliYaz(_authModeKey, mode);
    await _guvenliYaz(_aktifKullaniciKey, userId);
    if (email != null && email.trim().isNotEmpty) {
      await _guvenliYaz(_kullaniciEmailKey, email.trim());
    } else {
      await _guvenliSil(_kullaniciEmailKey);
    }
    if (sharedFarmCode != null && sharedFarmCode.trim().isNotEmpty) {
      await _guvenliYaz(
        _ortakTarlaKoduKey,
        guvenliKodNormalizeEt(sharedFarmCode),
      );
    } else {
      await _guvenliSil(_ortakTarlaKoduKey);
    }
    // Backward compatibility cleanup.
    await prefs.remove(_authModeKey);
    await prefs.remove(_aktifKullaniciKey);
    await prefs.remove(_kullaniciEmailKey);
    await prefs.remove(_ortakTarlaKoduKey);
  }

  static Future<String?> authModunuGetir() async {
    final secure = await _guvenliOku(_authModeKey);
    if (secure != null && secure.trim().isNotEmpty) return secure;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_authModeKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await _guvenliYaz(_authModeKey, legacy);
      await prefs.remove(_authModeKey);
    }
    return legacy;
  }

  static Future<String?> aktifKullaniciIdGetir() async {
    final secure = await _guvenliOku(_aktifKullaniciKey);
    if (secure != null && secure.trim().isNotEmpty) return secure;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_aktifKullaniciKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await _guvenliYaz(_aktifKullaniciKey, legacy);
      await prefs.remove(_aktifKullaniciKey);
    }
    return legacy;
  }

  static Future<String?> aktifKullaniciEmailGetir() async {
    final secure = await _guvenliOku(_kullaniciEmailKey);
    if (secure != null && secure.trim().isNotEmpty) return secure;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_kullaniciEmailKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await _guvenliYaz(_kullaniciEmailKey, legacy);
      await prefs.remove(_kullaniciEmailKey);
    }
    return legacy;
  }

  static Future<String?> aktifOrtakTarlaKodunuGetir() async {
    final secure = await _guvenliOku(_ortakTarlaKoduKey);
    if (secure != null && secure.trim().isNotEmpty) return secure;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_ortakTarlaKoduKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await _guvenliYaz(_ortakTarlaKoduKey, legacy);
      await prefs.remove(_ortakTarlaKoduKey);
    }
    return legacy;
  }

  static Future<void> authBilgisiniTemizle() async {
    final prefs = await SharedPreferences.getInstance();
    await _guvenliSil(_authModeKey);
    await _guvenliSil(_aktifKullaniciKey);
    await _guvenliSil(_kullaniciEmailKey);
    await _guvenliSil(_ortakTarlaKoduKey);
    await prefs.remove(_authModeKey);
    await prefs.remove(_aktifKullaniciKey);
    await prefs.remove(_kullaniciEmailKey);
    await prefs.remove(_ortakTarlaKoduKey);
  }

  static Future<void> openAiApiAnahtariniKaydet(String apiKey) async {
    final temiz = apiKey.trim();
    if (temiz.isEmpty) {
      await _guvenliSil(_openAiApiKeyKey);
    } else {
      await _guvenliYaz(_openAiApiKeyKey, temiz);
    }
  }

  static Future<String?> openAiApiAnahtariniGetir() async {
    final deger = await _guvenliOku(_openAiApiKeyKey);
    if (deger == null || deger.trim().isEmpty) return null;
    return deger;
  }

  static Future<void> geminiApiAnahtariniKaydet(String apiKey) async {
    final temiz = apiKey.trim();
    if (temiz.isEmpty) {
      await _guvenliSil(_geminiApiKeyKey);
    } else {
      await _guvenliYaz(_geminiApiKeyKey, temiz);
    }
  }

  static Future<String?> geminiApiAnahtariniGetir() async {
    final deger = await _guvenliOku(_geminiApiKeyKey);
    if (deger == null || deger.trim().isEmpty) return null;
    return deger;
  }

  static Future<bool> geminiAktifMi() async {
    final yerel = await geminiApiAnahtariniGetir();
    return yerel != null && yerel.isNotEmpty;
  }

  static Future<String> yedekHmacAnahtariniGetirVeyaOlustur() async {
    final mevcut = await _guvenliOku(_yedekHmacAnahtariKey);
    if (mevcut != null && mevcut.trim().isNotEmpty) {
      return mevcut;
    }
    final yeni = '${DateTime.now().microsecondsSinceEpoch}:${_jsonEncodeMap({
      'seed': DateTime.now().millisecondsSinceEpoch,
      'nonce': DateTime.now().hashCode,
    })}';
    await _guvenliYaz(_yedekHmacAnahtariKey, yeni);
    return yeni;
  }

  static Future<void> eskiAileVerisiniYeniKokKodaTasi({
    required String yeniKokKod,
  }) async {
    final eskiAileKodu = await kayitliAileKodunuGetir();
    if (eskiAileKodu == null || eskiAileKodu.trim().isEmpty) return;
    final eskiKod = eskiAileKodu.trim();
    if (eskiKod == yeniKokKod.trim()) return;

    final prefs = await SharedPreferences.getInstance();
    final eskiIslemTurleri = prefs.getStringList(_islemTurleriAnahtari(eskiKod));
    if (eskiIslemTurleri != null && eskiIslemTurleri.isNotEmpty) {
      await prefs.setStringList(_islemTurleriAnahtari(yeniKokKod), eskiIslemTurleri);
    }

    final eskiPdfHatirlatma = prefs.getString(_pdfHatirlatmaAnahtari(eskiKod));
    if (eskiPdfHatirlatma != null && eskiPdfHatirlatma.trim().isNotEmpty) {
      await prefs.setString(_pdfHatirlatmaAnahtari(yeniKokKod), eskiPdfHatirlatma);
    }

    final mevcutBekleyen = prefs.getStringList(_bekleyenSilmelerKey) ?? <String>[];
    if (mevcutBekleyen.isNotEmpty) {
      final tasinan = <String>[];
      for (final kayit in mevcutBekleyen) {
        if (kayit.startsWith('$eskiKod::')) {
          final remoteId = kayit.split('::').last;
          tasinan.add(_silmeAnahtariOlustur(yeniKokKod, remoteId));
        } else {
          tasinan.add(kayit);
        }
      }
      await prefs.setStringList(_bekleyenSilmelerKey, tasinan.toSet().toList());
    }
  }

  static Future<void> kullaniciAdiniKaydet(String kullaniciAdi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kullaniciAdiKey, kullaniciAdi.trim());
  }

  static Future<DateTime?> sonPdfHatirlatmaTarihiniGetir(String aileKodu) async {
    final prefs = await SharedPreferences.getInstance();
    final deger = prefs.getString(_pdfHatirlatmaAnahtari(aileKodu));
    if (deger == null || deger.trim().isEmpty) return null;
    return DateTime.tryParse(deger);
  }

  static Future<void> pdfHatirlatmaTarihiniKaydet(
    String aileKodu,
    DateTime tarih,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pdfHatirlatmaAnahtari(aileKodu),
      tarih.toIso8601String(),
    );
  }

  static Future<List<IslemTuruTanim>> ozelIslemTurleriniGetir(
    String aileKodu,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final kayitlar = prefs.getStringList(_islemTurleriAnahtari(aileKodu)) ?? [];
    return kayitlar
        .map((deger) {
          try {
            final map = Map<String, dynamic>.from(
              _jsonDecodeMap(deger),
            );
            return IslemTuruTanim.fromMap(map);
          } catch (_) {
            return null;
          }
        })
        .whereType<IslemTuruTanim>()
        .where((tanim) => !tanim.varsayilan && tanim.ad.isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> ozelIslemTurleriniKaydet(
    String aileKodu,
    List<IslemTuruTanim> tipler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _islemTurleriAnahtari(aileKodu),
      tipler
          .where((tanim) => !tanim.varsayilan && tanim.ad.trim().isNotEmpty)
          .map((tanim) => _jsonEncodeMap(tanim.toMap()))
          .toList(growable: false),
    );
  }

  static Future<List<String>> bekleyenSilmeleriGetir(String aileKodu) async {
    final prefs = await SharedPreferences.getInstance();
    final kayitlar = prefs.getStringList(_bekleyenSilmelerKey) ?? [];

    return kayitlar
        .where((kayit) => kayit.startsWith('$aileKodu::'))
        .map((kayit) => kayit.split('::').last)
        .toList();
  }

  static Future<void> bekleyenSilmeEkle(String aileKodu, String remoteId) async {
    final prefs = await SharedPreferences.getInstance();
    final mevcut = prefs.getStringList(_bekleyenSilmelerKey) ?? [];
    final anahtar = _silmeAnahtariOlustur(aileKodu, remoteId);

    if (!mevcut.contains(anahtar)) {
      mevcut.add(anahtar);
      await prefs.setStringList(_bekleyenSilmelerKey, mevcut);
    }
  }

  static Future<void> bekleyenSilmeyiKaldir(String aileKodu, String remoteId) async {
    final prefs = await SharedPreferences.getInstance();
    final mevcut = prefs.getStringList(_bekleyenSilmelerKey) ?? [];
    mevcut.remove(_silmeAnahtariOlustur(aileKodu, remoteId));
    await prefs.setStringList(_bekleyenSilmelerKey, mevcut);
  }

  static dynamic _jsonDecodeMap(String source) {
    return source.isEmpty ? <String, dynamic>{} : jsonDecode(source);
  }

  static Future<int> otomatikYedekSikligiGunGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_otomatikYedekSikligiGunKey) ?? 7;
  }

  static Future<void> otomatikYedekSikligiGunKaydet(int gun) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_otomatikYedekSikligiGunKey, gun.clamp(1, 365));
  }

  static Future<DateTime?> sonBasariliYedekTarihiniGetir() async {
    final prefs = await SharedPreferences.getInstance();
    final deger = prefs.getString(_sonBasariliYedekTarihiKey);
    if (deger == null || deger.trim().isEmpty) return null;
    return DateTime.tryParse(deger)?.toLocal();
  }

  static Future<String?> sonYedekHataMesajiniGetir() async {
    final prefs = await SharedPreferences.getInstance();
    final deger = prefs.getString(_sonYedekHataMesajiKey);
    if (deger == null || deger.trim().isEmpty) return null;
    return deger;
  }

  static Future<void> yedekBasariliKaydet(DateTime tarih) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sonBasariliYedekTarihiKey, tarih.toIso8601String());
    await prefs.remove(_sonYedekHataMesajiKey);
  }

  static Future<void> yedekHatasiKaydet(String mesaj) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sonYedekHataMesajiKey, mesaj.trim());
  }

  static Future<bool> pdfHatirlatmaEtkinGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pdf_hatirlatma_etkin') ?? true;
  }

  static Future<void> pdfHatirlatmaEtkinKaydet(bool deger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pdf_hatirlatma_etkin', deger);
  }

  static Future<int> pdfHatirlatmaSikligiGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('pdf_hatirlatma_sikligi_gun') ?? 14;
  }

  static Future<void> pdfHatirlatmaSikligiKaydet(int deger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pdf_hatirlatma_sikligi_gun', deger);
  }

  static Future<int> arsivSaklamaSuresiGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('arsiv_saklama_suresi_gun') ?? 30;
  }

  static Future<void> arsivSaklamaSuresiKaydet(int deger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('arsiv_saklama_suresi_gun', deger);
  }

  static String _jsonEncodeMap(Map<String, dynamic> map) => jsonEncode(map);
}
