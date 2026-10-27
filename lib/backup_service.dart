import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_session_service.dart';
import 'database_helper.dart';
import 'islem_model.dart';
import 'islem_turu_model.dart';
import 'sinir_noktasi_model.dart';
import 'tarla_model.dart';

class YedekDosyasiBilgisi {
  const YedekDosyasiBilgisi({
    required this.yol,
    required this.ad,
    required this.boyut,
    required this.duzenlenmeTarihi,
    required this.onizleme,
  });

  final String yol;
  final String ad;
  final int boyut;
  final DateTime duzenlenmeTarihi;
  final YedekOnizleme onizleme;
}

class YedekOnizleme {
  const YedekOnizleme({
    required this.tarlaSayisi,
    required this.islemSayisi,
    required this.silinmisTarlaSayisi,
  });

  final int tarlaSayisi;
  final int islemSayisi;
  final int silinmisTarlaSayisi;
}

class BackupService {
  BackupService._();
  static const int _maksimumArsivYedegi = 40;
  static const int _yedekSurum = 3;
  static const int _desteklenenEnDusukSurum = 2;
  static Future<void> _yedekKilidi = Future.value();

  static Future<String?> _aktifAileKodunuGetir() async {
    return await AppSessionService.kayitliAileKodunuGetir() ??
        await AppSessionService.sonAileKodunuGetir() ??
        'YEREL';
  }

  static Future<Map<String, dynamic>> _anlikYedekVerisiOlustur({
    required String sebep,
  }) async {
    final tarlalar = await DatabaseHelper.instance.tumTarlalar(hepsiniGetir: true);
    final aktifAileKodu = await _aktifAileKodunuGetir();
    final ozelIslemTurleri = aktifAileKodu == null || aktifAileKodu.trim().isEmpty
        ? const <IslemTuruTanim>[]
        : await AppSessionService.ozelIslemTurleriniGetir(aktifAileKodu);
    final icerik = <Map<String, dynamic>>[];

    for (final tarla in tarlalar) {
      final tarlaId = tarla.id;
      final islemler = tarlaId == null
          ? const <Islem>[]
          : await DatabaseHelper.instance.tarlaIslemleri(tarlaId);
      final sinirlar = tarlaId == null
          ? const <SinirNoktasi>[]
          : await DatabaseHelper.instance.tarlaSinirNoktalari(tarlaId);

      icerik.add({
        'tarla': tarla.toMap(),
        'islemler': islemler.map((e) => e.toMap()).toList(),
        'sinirNoktalari': sinirlar.map((e) => e.toMap()).toList(),
      });
    }

    final yedek = {
      'uygulama': 'Tarim360',
      'surum': _yedekSurum,
      'sebep': sebep,
      'olusturulmaTarihi': DateTime.now().toIso8601String(),
      'tarlaSayisi': tarlalar.length,
      'aileKodu': aktifAileKodu,
      'ozelIslemTurleri': ozelIslemTurleri.map((e) => e.toMap()).toList(),
      'veriler': icerik,
      'imzaAlgoritmasi': 'HMAC-SHA256',
    };
    yedek['checksum'] = await _yedekChecksumHesapla(yedek);
    return yedek;
  }

  static Future<String> guvenlikYedegiOlustur({
    String sebep = 'otomatik',
  }) async {
    final onceki = _yedekKilidi;
    final completer = Completer<void>();
    _yedekKilidi = completer.future;
    await onceki;
    try {
      final yedek = await _anlikYedekVerisiOlustur(sebep: sebep);

      final klasor = await hedefKlasoruGetir();
      await klasor.create(recursive: true);

      final zamanDamgasi = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final sonYedek = File(p.join(klasor.path, 'tarla_takip_son_yedek.json'));
      final arsivYedek = File(
        p.join(klasor.path, 'tarla_takip_yedek_$zamanDamgasi.json'),
      );
      final bytes = const JsonEncoder.withIndent('  ').convert(yedek);

      // Yedek dosyalari once .tmp olarak yazilip sonra atomik sekilde adlandirilir.
      final sonTmp = File('${sonYedek.path}.tmp');
      final arsivTmp = File('${arsivYedek.path}.tmp');
      await sonTmp.writeAsString(bytes);
      await arsivTmp.writeAsString(bytes);
      await sonTmp.rename(sonYedek.path);
      await arsivTmp.rename(arsivYedek.path);
      await _eskiArsivleriTemizle(klasor);
      await AppSessionService.yedekBasariliKaydet(DateTime.now());
      return arsivYedek.path;
    } catch (error) {
      await AppSessionService.yedekHatasiKaydet(error.toString());
      rethrow;
    } finally {
      completer.complete();
    }
  }

  static Future<List<YedekDosyasiBilgisi>> yedekleriListele() async {
    final klasor = await hedefKlasoruGetir();
    if (!await klasor.exists()) {
      return const [];
    }

    final dosyalar = await klasor
        .list()
        .where((item) => item is File && item.path.toLowerCase().endsWith('.json'))
        .cast<File>()
        .toList();

    final sonuc = <YedekDosyasiBilgisi>[];
    for (final dosya in dosyalar) {
      final stat = await dosya.stat();
      sonuc.add(
        YedekDosyasiBilgisi(
          yol: dosya.path,
          ad: p.basename(dosya.path),
          boyut: stat.size,
          duzenlenmeTarihi: stat.modified.toLocal(),
          onizleme: await _yedekOnizle(dosya),
        ),
      );
    }

    sonuc.sort((a, b) => b.duzenlenmeTarihi.compareTo(a.duzenlenmeTarihi));
    return sonuc;
  }

  static Future<YedekDosyasiBilgisi?> sonYedegiGetir() async {
    final yedekler = await yedekleriListele();
    if (yedekler.isEmpty) return null;
    return yedekler.first;
  }

  static Future<YedekOnizleme> yedegiDogrula(String dosyaYolu) async {
    final dosya = File(dosyaYolu);
    if (!await dosya.exists()) {
      throw Exception('Yedek dosyasi bulunamadi');
    }
    final ham = await dosya.readAsString();
    final json = jsonDecode(ham);
    if (json is! Map<String, dynamic>) {
      throw Exception('Yedek dosyasi formati gecersiz');
    }
    _yedekSurumunuDogrula(json);
    await _yedekChecksumiDogrula(json);
    final veriler = json['veriler'];
    if (veriler is! List) {
      throw Exception('Yedek dosyasinda veriler alani bulunamadi');
    }
    final onizleme = await _yedekOnizle(dosya);
    if (onizleme.tarlaSayisi == 0 && veriler.isNotEmpty) {
      throw Exception('Yedek dosyasi okunuyor ancak icerik gecersiz');
    }
    return onizleme;
  }

  static Future<void> yedektenGeriYukle(String dosyaYolu) async {
    await _yedektenGeriYukleIc(dosyaYolu, geriYuklemeOncesiYedekAl: true);
  }

  static Future<void> _yedektenGeriYukleIc(
    String dosyaYolu, {
    required bool geriYuklemeOncesiYedekAl,
  }) async {
    final dosya = File(dosyaYolu);
    if (!await dosya.exists()) {
      throw Exception('Yedek dosyasi bulunamadi');
    }

    final ham = await dosya.readAsString();
    final json = jsonDecode(ham);
    if (json is! Map<String, dynamic>) {
      throw Exception('Yedek dosyasi okunamadi');
    }

    final veriler = json['veriler'];
    if (veriler is! List) {
      throw Exception('Yedek icerigi gecersiz');
    }

    Map<String, dynamic>? emniyetAnlikVeri;
    String? emniyetYedegiYolu;
    if (geriYuklemeOncesiYedekAl) {
      emniyetAnlikVeri = await _anlikYedekVerisiOlustur(
        sebep: 'geri_yukleme_oncesi',
      );
      try {
        emniyetYedegiYolu = await guvenlikYedegiOlustur(
          sebep: 'geri_yukleme_oncesi',
        );
      } catch (_) {}
    }

    try {
      await _yedekJsoniniUygula(json);
    } catch (error) {
      var veriGeriGetirildi = false;
      if (emniyetAnlikVeri != null) {
        try {
          await _yedekJsoniniUygula(emniyetAnlikVeri);
          veriGeriGetirildi = true;
        } catch (_) {}
      }
      if (emniyetYedegiYolu != null) {
        try {
          await _yedektenGeriYukleIc(
            emniyetYedegiYolu,
            geriYuklemeOncesiYedekAl: false,
          );
          veriGeriGetirildi = true;
        } catch (_) {}
      }
      if (!veriGeriGetirildi) {
        throw Exception(
          'Geri yukleme sirasinda hata olustu ve emniyet geri yukleme de basarisiz oldu: $error',
        );
      }
      throw Exception(
        'Istenen yedek yuklenemedi. Eski veriler geri getirildi. Hata: $error',
      );
    }
  }

  static Future<void> _yedekJsoniniUygula(Map<String, dynamic> json) async {
    _yedekSurumunuDogrula(json);
    await _yedekChecksumiDogrula(json);
    final veriler = json['veriler'];
    if (veriler is! List) {
      throw Exception('Yedek icerigi gecersiz');
    }

    final aileKodu = (json['aileKodu'] as String?)?.trim();
    final ozelTipler = ((json['ozelIslemTurleri'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => IslemTuruTanim.fromMap(item.cast<String, dynamic>()))
        .where((tanim) => !tanim.varsayilan && tanim.ad.isNotEmpty)
        .toList(growable: false);

    await DatabaseHelper.instance.tumVerileriTemizle();

    for (final kayit in veriler.whereType<Map>()) {
      final tarlaMap = Map<String, dynamic>.from(
        (kayit['tarla'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final tarla = Tarla.fromMap(tarlaMap)..id = null;
      final yeniTarlaId = await DatabaseHelper.instance.tarlaEkle(tarla);

      final islemler = ((kayit['islemler'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Islem.fromMap({
                ...item.cast<String, dynamic>(),
                'tarlaId': yeniTarlaId,
              }).copyWith(id: null, tarlaId: yeniTarlaId))
          .toList();
      await DatabaseHelper.instance.tarlaIslemleriniYenile(yeniTarlaId, islemler);

      final sinirlar = ((kayit['sinirNoktalari'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => SinirNoktasi.fromMap({
                ...item.cast<String, dynamic>(),
                'tarlaId': yeniTarlaId,
              }))
          .toList();
      await DatabaseHelper.instance.tarlaSinirNoktalariYenile(yeniTarlaId, sinirlar);
    }

    final hedefAileKodu =
        (aileKodu != null && aileKodu.isNotEmpty) ? aileKodu : await _aktifAileKodunuGetir();
    if (hedefAileKodu != null && hedefAileKodu.trim().isNotEmpty) {
      await AppSessionService.ozelIslemTurleriniKaydet(
        hedefAileKodu,
        ozelTipler,
      );
    }
  }

  static void _yedekSurumunuDogrula(Map<String, dynamic> json) {
    final surum = (json['surum'] as num?)?.toInt();
    if (surum == null) {
      throw Exception('Yedek surum bilgisi yok');
    }
    if (surum < _desteklenenEnDusukSurum) {
      throw Exception(
        'Bu yedek cok eski bir surumden geliyor (v$surum). Desteklenen en dusuk surum v$_desteklenenEnDusukSurum.',
      );
    }
    if (surum > _yedekSurum) {
      throw Exception(
        'Bu yedek daha yeni bir surumden geliyor (v$surum). Uygulamayi guncelleyip tekrar dene.',
      );
    }
  }

  static Future<void> _yedekChecksumiDogrula(Map<String, dynamic> json) async {
    final kayitli = (json['checksum'] as String?)?.trim();
    if (kayitli == null || kayitli.isEmpty) {
      throw Exception('Yedek checksum bilgisi yok');
    }
    final beklenen = await _yedekChecksumHesapla(json);
    if (beklenen != kayitli) {
      throw Exception('Yedek dosyasi bozuk veya degistirilmis gorunuyor (checksum uyumsuz)');
    }
  }

  static Future<String> _yedekChecksumHesapla(Map<String, dynamic> json) async {
    final map = Map<String, dynamic>.from(json);
    map.remove('checksum');
    final metin = const JsonEncoder.withIndent('  ').convert(map);
    final anahtar = await AppSessionService.yedekHmacAnahtariniGetirVeyaOlustur();
    final imza = Hmac(sha256, utf8.encode(anahtar)).convert(utf8.encode(metin));
    return imza.toString();
  }

  static Future<void> _eskiArsivleriTemizle(Directory klasor) async {
    final dosyalar = await klasor
        .list()
        .where(
          (item) =>
              item is File &&
              p.basename(item.path).startsWith('tarla_takip_yedek_') &&
              item.path.toLowerCase().endsWith('.json'),
        )
        .cast<File>()
        .toList();
    dosyalar.sort(
      (a, b) => b.path.toLowerCase().compareTo(a.path.toLowerCase()),
    );
    if (dosyalar.length <= _maksimumArsivYedegi) return;
    for (final dosya in dosyalar.skip(_maksimumArsivYedegi)) {
      try {
        await dosya.delete();
      } catch (_) {}
    }
  }

  static Future<YedekOnizleme> _yedekOnizle(File dosya) async {
    try {
      final ham = await dosya.readAsString();
      final json = jsonDecode(ham);
      if (json is! Map<String, dynamic>) {
        return const YedekOnizleme(
          tarlaSayisi: 0,
          islemSayisi: 0,
          silinmisTarlaSayisi: 0,
        );
      }

      final veriler = (json['veriler'] as List?) ?? const [];
      var tarlaSayisi = 0;
      var islemSayisi = 0;
      var silinmisTarlaSayisi = 0;
      for (final kayit in veriler.whereType<Map>()) {
        tarlaSayisi++;
        final tarlaMap = (kayit['tarla'] as Map?)?.cast<String, dynamic>() ?? const {};
        if (((tarlaMap['silinmisMi'] as num?)?.toInt() ?? 0) == 1) {
          silinmisTarlaSayisi++;
        }
        islemSayisi += ((kayit['islemler'] as List?) ?? const []).length;
      }

      return YedekOnizleme(
        tarlaSayisi: tarlaSayisi,
        islemSayisi: islemSayisi,
        silinmisTarlaSayisi: silinmisTarlaSayisi,
      );
    } catch (_) {
      return const YedekOnizleme(
        tarlaSayisi: 0,
        islemSayisi: 0,
        silinmisTarlaSayisi: 0,
      );
    }
  }

  static Future<Directory> hedefKlasoruGetir() async {
    final belgeler = await getApplicationDocumentsDirectory();
    return Directory(p.join(belgeler.path, 'Tarim360Yedekleri'));
  }

  static Future<String> hedefKlasorYoluGetir() async {
    final klasor = await hedefKlasoruGetir();
    return klasor.path;
  }
}
