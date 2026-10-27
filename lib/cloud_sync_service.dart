import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_session_service.dart';
import 'backup_service.dart';
import 'database_helper.dart';
import 'gelir_model.dart';
import 'islem_model.dart';
import 'islem_turu_model.dart';
import 'sinir_noktasi_model.dart';
import 'tarla_model.dart';
import 'utils/app_helpers.dart';
import 'utils/app_logger.dart';

class AileBilgisi {
  const AileBilgisi({
    required this.aileKodu,
    required this.aileAdi,
    required this.erisimKodu,
    this.olusturanKullaniciId,
  });

  final String aileKodu;
  final String aileAdi;
  final String erisimKodu;
  final String? olusturanKullaniciId;
}

class AileUyesi {
  const AileUyesi({
    required this.kullaniciId,
    required this.kullaniciAdi,
    this.katilimTarihi,
    this.sonGorulme,
  });

  final String kullaniciId;
  final String kullaniciAdi;
  final DateTime? katilimTarihi;
  final DateTime? sonGorulme;
}

class CloudSyncService {
  CloudSyncService._();

  static final CloudSyncService instance = CloudSyncService._();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, Future<void>> _dinlemeKuyruklari = {};
  final Set<String> _dogrulanmisAileler = {};

  void temizleCache() {
    _dogrulanmisAileler.clear();
  }

  CollectionReference<Map<String, dynamic>> _tarlaCollection(String aileKodu) {
    return _firestore.collection('aileler').doc(aileKodu).collection('tarlalar');
  }

  DocumentReference<Map<String, dynamic>> _aileRef(String aileKodu) {
    return _firestore.collection('aileler').doc(aileKodu);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> aileBelgesiniDinle(String aileKodu) {
    return _aileRef(aileKodu).snapshots();
  }

  CollectionReference<Map<String, dynamic>> _uyeCollection(String aileKodu) {
    return _aileRef(aileKodu).collection('uyeler');
  }

  Future<AileBilgisi> yeniAileOlustur(
    String kullaniciId,
    String aileAdi,
    String kullaniciAdi,
  ) async {
    final aileRef = _firestore.collection('aileler').doc();
    final temizAileAdi = aileAdi.trim().isEmpty ? 'Ailem' : aileAdi.trim();
    final erisimKodu = await _benzersizErisimKoduUret();

    final basarili = await _guvenliBulutIslemi(() async {
      await aileRef.set({
        'guncellendi': FieldValue.serverTimestamp(),
        'olusturanKullanici': kullaniciId,
        'sonKullanici': kullaniciId,
        'aileAdi': temizAileAdi,
        'aileErisimKodu': erisimKodu,
      }, SetOptions(merge: true));
      await _uyeCollection(aileRef.id).doc(kullaniciId).set({
        'kullaniciAdi': kullaniciAdi.trim(),
        'katilimTarihi': FieldValue.serverTimestamp(),
        'sonGorulme': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    if (!basarili) {
      throw Exception('Aile olusturulamadi');
    }

    return AileBilgisi(
      aileKodu: aileRef.id,
      aileAdi: temizAileAdi,
      erisimKodu: erisimKodu,
      olusturanKullaniciId: kullaniciId,
    );
  }

  Future<AileBilgisi?> erisimKoduIleAileBul(String erisimKodu) async {
    final temizKod = guvenliKodNormalizeEt(erisimKodu);
    final sonuc = await _firestore
        .collection('aileler')
        .where('aileErisimKodu', isEqualTo: temizKod)
        .limit(1)
        .get();

    if (sonuc.docs.isEmpty) {
      return null;
    }

    final doc = sonuc.docs.first;
    final data = doc.data();
    return AileBilgisi(
      aileKodu: doc.id,
      aileAdi: (data['aileAdi'] as String?)?.trim().isNotEmpty == true
          ? (data['aileAdi'] as String).trim()
          : 'Ailem',
      erisimKodu: temizKod,
      olusturanKullaniciId: data['olusturanKullanici'] as String?,
    );
  }

  Future<void> aileyeKatil(
    String aileKodu,
    String kullaniciId,
    String kullaniciAdi,
  ) async {
    try {
      await _guvenliBulutIslemi(() async {
        // Uye kaydini ILK once olustur ki firestore rules'taki exists/isMember kontrolu gecsin.
        await _uyeCollection(aileKodu).doc(kullaniciId).set(
          {
            'kullaniciAdi': kullaniciAdi.trim(),
            'katilimTarihi': FieldValue.serverTimestamp(),
            'sonGorulme': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        await _aileRef(aileKodu).set(
          {
            'guncellendi': FieldValue.serverTimestamp(),
            'sonKullanici': kullaniciId,
          },
          SetOptions(merge: true),
        );
      });
    } catch (_) {
      throw Exception('Aileye katilinamadi');
    }
  }

  Future<List<AileUyesi>> aileUyeleriniGetir(String aileKodu) async {
    final sonuc = await _uyeCollection(aileKodu)
        .orderBy('kullaniciAdi')
        .get();
    return sonuc.docs
        .map((doc) {
          final data = doc.data();
          return AileUyesi(
            kullaniciId: doc.id,
            kullaniciAdi: (data['kullaniciAdi'] as String?)?.trim().isNotEmpty == true
                ? (data['kullaniciAdi'] as String).trim()
                : 'Bilinmeyen',
            katilimTarihi: _parseDate(data['katilimTarihi']),
            sonGorulme: _parseDate(data['sonGorulme']),
          );
        })
        .toList(growable: false);
  }

  Future<AileBilgisi> aileBilgisiGetir(String aileKodu, {String? callerUserId}) async {
    final ref = _firestore.collection('aileler').doc(aileKodu);
    final doc = await ref.get();
    final data = doc.data();
    final mevcutAd = (data?['aileAdi'] as String?)?.trim();
    final mevcutKod = guvenliKodNormalizeEt(data?['aileErisimKodu'] as String? ?? '');
    final aileAdi = (mevcutAd != null && mevcutAd.isNotEmpty) ? mevcutAd : 'Ekibim';
    final ekipSahibiId = data?['olusturanKullanici'] as String?;

    // Yalnızca ekip sahibi erişim kodu üretip kaydedebilir.
    // Üyeler kodu değiştiremez — aksi hâlde QR bağımsız değişiyor.
    String erisimKodu = mevcutKod;
    if (mevcutKod.isEmpty) {
      // Kod hiç yoksa → sadece ekip sahibi yeni kod üretir
      final sahibiMi = callerUserId != null && callerUserId == ekipSahibiId;
      final ilkKayitMi = ekipSahibiId == null; // Henüz ekip oluşturuluyor
      if (sahibiMi || ilkKayitMi) {
        erisimKodu = await _benzersizErisimKoduUret();
      }
    }

    // Güncelleme gerekiyorsa sadece ekip sahibi kaydeder
    if (mevcutAd != aileAdi || (mevcutKod != erisimKodu && erisimKodu.isNotEmpty)) {
      final sahibiMi = callerUserId != null && callerUserId == ekipSahibiId;
      final ilkKayitMi = ekipSahibiId == null;
      if (sahibiMi || ilkKayitMi) {
        final basarili = await _guvenliBulutIslemi(() async {
          await ref.set({
            'guncellendi': FieldValue.serverTimestamp(),
            'aileAdi': aileAdi,
            if (erisimKodu.isNotEmpty) 'aileErisimKodu': erisimKodu,
          }, SetOptions(merge: true));
        });
        if (!basarili) {
          throw Exception('Ekip bilgisi hazirlanamadi');
        }
      }
    }

    return AileBilgisi(
      aileKodu: aileKodu,
      aileAdi: aileAdi,
      erisimKodu: erisimKodu,
      olusturanKullaniciId: ekipSahibiId,
    );
  }

  // Kullanıcının ait olduğu aileyi UID üzerinden Firestore'da bul
  Future<AileBilgisi?> kullaniciAilesiniGetir(String kullaniciId) async {
    try {
      // Üyeler alt koleksiyonunda bu uid'yi ara
      final sonuc = await _firestore
          .collectionGroup('uyeler')
          .where(FieldPath.documentId, isEqualTo: kullaniciId)
          .limit(1)
          .get();
      if (sonuc.docs.isEmpty) return null;
      final uyeDoc = sonuc.docs.first;
      // Üst aile dokümanı: aileler/{aileKodu}/uyeler/{uid}
      final aileKodu = uyeDoc.reference.parent.parent?.id;
      if (aileKodu == null) return null;
      return await aileBilgisiGetir(aileKodu);
    } catch (_) {
      return null;
    }
  }

  Future<List<IslemTuruTanim>> ozelIslemTurleriniGetir(String aileKodu) async {
    final doc = await _aileRef(aileKodu).get();
    final data = doc.data();
    final kayitlar = (data?['ozelIslemTurleri'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((map) => IslemTuruTanim.fromMap(Map<String, dynamic>.from(map)))
        .where((tanim) => !tanim.varsayilan && tanim.ad.isNotEmpty)
        .toList(growable: false);
    await AppSessionService.ozelIslemTurleriniKaydet(aileKodu, kayitlar);
    return kayitlar;
  }

  Future<void> ozelIslemTurleriniKaydet(
    String aileKodu,
    List<IslemTuruTanim> tipler,
  ) async {
    final kayitlar = tipler
        .where((tanim) => !tanim.varsayilan && tanim.ad.trim().isNotEmpty)
        .map((tanim) => tanim.toMap())
        .toList(growable: false);
    await _guvenliBulutIslemi(() async {
      await _aileRef(aileKodu).set({
        'guncellendi': FieldValue.serverTimestamp(),
        'ozelIslemTurleri': kayitlar,
      }, SetOptions(merge: true));
    });
    await AppSessionService.ozelIslemTurleriniKaydet(aileKodu, tipler);
  }

  Future<AileBilgisi> aileBilgisiniGuncelle(
    String aileKodu, {
    required String aileAdi,
    required String erisimKodu,
  }) async {
    final temizAileAdi = aileAdi.trim();
    final temizErisimKodu = guvenliKodNormalizeEt(erisimKodu);

    if (temizAileAdi.length < 2) {
      throw Exception('Aile adi en az 2 karakter olmali');
    }
    if (!RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(temizErisimKodu)) {
      throw Exception('Aile kodu 4-12 karakter olmali ve sadece harf/rakam icermeli');
    }

    final mevcut = await aileBilgisiGetir(aileKodu);
    if (mevcut.erisimKodu != temizErisimKodu) {
      final sonuc = await _firestore
          .collection('aileler')
          .where('aileErisimKodu', isEqualTo: temizErisimKodu)
          .limit(1)
          .get();
      if (sonuc.docs.any((doc) => doc.id != aileKodu)) {
        throw Exception('Bu aile kodu baska bir aile tarafindan kullaniliyor');
      }
    }

    final basarili = await _guvenliBulutIslemi(() async {
      await _firestore.collection('aileler').doc(aileKodu).set({
        'guncellendi': FieldValue.serverTimestamp(),
        'aileAdi': temizAileAdi,
        'aileErisimKodu': temizErisimKodu,
      }, SetOptions(merge: true));
    });
    if (!basarili) {
      throw Exception('Aile bilgisi guncellenemedi');
    }

    return AileBilgisi(
      aileKodu: aileKodu,
      aileAdi: temizAileAdi,
      erisimKodu: temizErisimKodu,
      olusturanKullaniciId: mevcut.olusturanKullaniciId,
    );
  }

  /// Belirli bir kullanicinin uye belgesini gercek zamanli dinler (profil adi vs.)
  Stream<DocumentSnapshot<Map<String, dynamic>>> kullaniciBelgesiniDinle(
    String aileKodu,
    String kullaniciId,
  ) {
    return _uyeCollection(aileKodu).doc(kullaniciId).snapshots();
  }

  Future<void> aileGeminiKeyGuncelle(
    String aileKodu,
    String apiKey,
  ) async {
    final temizKey = apiKey.trim();
    final basarili = await _guvenliBulutIslemi(() async {
      await _firestore.collection('aileler').doc(aileKodu).set({
        'guncellendi': FieldValue.serverTimestamp(),
        'geminiApiKey': temizKey,
      }, SetOptions(merge: true));
    });
    if (!basarili) {
      throw Exception('Yapay Zeka ortak anahtarı güncellenemedi');
    }
  }

  Future<void> aileyiHazirla(String aileKodu, String kullaniciId) async {
    await _guvenliBulutIslemi(() async {
      await _aileRef(aileKodu).set({
        'guncellendi': FieldValue.serverTimestamp(),
        'sonKullanici': kullaniciId,
      }, SetOptions(merge: true));
    });
  }

  Future<void> aileUyesiniGuncelle(
    String aileKodu,
    String kullaniciId,
    String kullaniciAdi,
  ) async {
    await _guvenliBulutIslemi(() async {
      await _uyeCollection(aileKodu).doc(kullaniciId).set(
        {
          'kullaniciAdi': kullaniciAdi.trim(),
          'katilimTarihi': FieldValue.serverTimestamp(),
          'sonGorulme': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> aileyiDinle(
    String aileKodu, {
    required Future<void> Function() senkronSonrasi,
  }) {
    return _tarlaCollection(aileKodu).snapshots().listen((snapshot) {
      final onceki = _dinlemeKuyruklari[aileKodu] ?? Future.value();
      final siradaki = onceki.catchError((_) {}).then((_) async {
        await _uzakDegisiklikleriYereleIsle(snapshot.docChanges);
        await senkronSonrasi();
      });
      _dinlemeKuyruklari[aileKodu] = siradaki;
    }, onDone: () {
      _dinlemeKuyruklari.remove(aileKodu);
    });
  }

  Future<void> buluttanYereleSenkronizeEt(
    String aileKodu, {
    bool tamEslestir = false,
  }) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    final snapshot = await _tarlaCollection(aileKodu).get();
    await _uzaktakiVeriyiYereleYaz(
      snapshot.docs,
      tamEslestir: tamEslestir,
    );
  }

  Future<bool> yereldenBulutaSenkronizeEt(String aileKodu) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    var tumuBasarili = true;
    tumuBasarili = await bekleyenSilmeleriEsitle(aileKodu) && tumuBasarili;

    final tarlalar = await DatabaseHelper.instance.tumTarlalar();
    for (final tarla in tarlalar) {
      final localId = tarla.id;
      if (localId == null) continue;

      tarla.remoteId ??= _remoteIdUret();
      final islemler = await DatabaseHelper.instance.tarlaIslemleri(localId);
      final sinirlar = await DatabaseHelper.instance.tarlaSinirNoktalari(localId);
      final gelirler = await DatabaseHelper.instance.tarlaGelirleri(localId);
      final basarili = await _guvenliBulutIslemi(() async {
        await _tarlaCollection(aileKodu).doc(tarla.remoteId).set(
              _tarlaDokumani(tarla, islemler, sinirlar, gelirler),
            );
      });
      tumuBasarili = tumuBasarili && basarili;
      await DatabaseHelper.instance.tarlaGuncelle(tarla);
    }

    return tumuBasarili;
  }

  Future<void> tarlaEkle(String aileKodu, Tarla tarla) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    tarla.remoteId ??= _remoteIdUret();
    tarla.id = await DatabaseHelper.instance.tarlaKaydetVeyaGuncelle(tarla);
    unawaited(
      _guvenliBulutIslemi(() async {
        await _tarlaCollection(aileKodu).doc(tarla.remoteId).set(
              _tarlaDokumani(tarla, const [], const [], const []),
            );
      }).catchError((e) {
        AppLogger.w('Yeni tarla buluta gonderilemedi', e);
        return false;
      }),
    );
    await _guvenlikYedegiAl('tarla_eklendi');
  }

  Future<void> tarlaSil(String aileKodu, Tarla tarla) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    if (tarla.id != null) {
      await DatabaseHelper.instance.tarlaSil(tarla.id!);
    }
    tarla
      ..silinmisMi = true
      ..silinmeTarihi = DateTime.now();
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('tarla_arsive_alindi');
  }

  Future<void> tarlaGeriYukle(String aileKodu, Tarla tarla) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    if (tarla.id != null) {
      await DatabaseHelper.instance.tarlaGeriYukle(tarla.id!);
    }
    tarla
      ..silinmisMi = false
      ..silinmeTarihi = null;
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('tarla_geri_yuklendi');
  }

  Future<void> suresiDolmusArsivTarlalariTemizle(String aileKodu) async {
    final saklamaSuresi = await AppSessionService.arsivSaklamaSuresiGetir();
    final esik = DateTime.now().subtract(Duration(days: saklamaSuresi));
    final yereldeSilinecekler =
        await DatabaseHelper.instance.suresiDolmusSilinenTarlalar(esik);

    for (final tarla in yereldeSilinecekler) {
      final remoteId = tarla.remoteId;
      if (remoteId != null) {
        await _guvenliBulutIslemi(() async {
          await _tarlaCollection(aileKodu).doc(remoteId).delete();
        });
      }
      if (tarla.id != null) {
        await DatabaseHelper.instance.tarlaKaliciSil(tarla.id!);
      }
    }
  }

  Future<void> islemEkle(
    String aileKodu,
    Tarla tarla,
    Islem islem,
  ) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    final localId = tarla.id;
    if (localId == null) return;

    await DatabaseHelper.instance.islemEkle(
      Islem(
        tarlaId: localId,
        tur: islem.tur,
        detay: islem.detay,
        baslangicZamani: islem.baslangicZamani,
        tarih: islem.tarih,
        kullaniciAdi: islem.kullaniciAdi,
        fotoBase64: islem.fotoBase64,
        maliyet: islem.maliyet,
      ),
    );
    await DatabaseHelper.instance.sonIslemTarihiGuncelle(
      localId,
      sonSulama: islem.tur == 'Sulama' ? DateTime.tryParse(islem.baslangicZamani ?? '') : null,
      sonGubre: islem.tur == 'Gubre' ? DateTime.tryParse(islem.baslangicZamani ?? '') : null,
      sonIlac: islem.tur == 'Ilac' ? DateTime.tryParse(islem.baslangicZamani ?? '') : null,
    );
    tarla.remoteId ??= await DatabaseHelper.instance.tarlaRemoteIdGetir(localId) ?? _remoteIdUret();
    await DatabaseHelper.instance.tarlaGuncelle(tarla);
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('islem_eklendi');
  }

  Future<void> islemGuncelle(
    String aileKodu,
    Tarla tarla,
    Islem islem,
  ) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    final localId = tarla.id;
    if (localId == null || islem.id == null) return;

    await DatabaseHelper.instance.islemGuncelle(islem);
    await _tarlaSonIslemleriniYenile(tarla);
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('islem_guncellendi');
  }

  Future<void> islemSil(
    String aileKodu,
    Tarla tarla,
    int islemId,
  ) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    final localId = tarla.id;
    if (localId == null) return;

    await DatabaseHelper.instance.islemSil(islemId);
    await _tarlaSonIslemleriniYenile(tarla);
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('islem_silindi');
  }

  Future<void> gelirEkle(
    String aileKodu,
    Tarla tarla,
    Gelir gelir,
  ) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    final localId = tarla.id;
    if (localId == null) return;

    await DatabaseHelper.instance.gelirEkle(gelir);
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('gelir_eklendi');
  }

  Future<void> gelirGuncelle(
    String aileKodu,
    Tarla tarla,
    Gelir gelir,
  ) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    if (gelir.id == null) return;

    await DatabaseHelper.instance.gelirGuncelle(gelir);
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('gelir_guncellendi');
  }

  Future<void> gelirSil(
    String aileKodu,
    Tarla tarla,
    int gelirId,
  ) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    await DatabaseHelper.instance.gelirSil(gelirId);
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('gelir_silindi');
  }

  Future<void> tarlaKonumunuGuncelle(String aileKodu, Tarla tarla) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    if (tarla.id != null) {
      await DatabaseHelper.instance.tarlaGuncelle(tarla);
    }
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('tarla_konumu_guncellendi');
  }

  Future<void> tarlaGuncelle(String aileKodu, Tarla tarla) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    if (tarla.id != null) {
      await DatabaseHelper.instance.tarlaGuncelle(tarla);
    }
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('tarla_guncellendi');
  }

  Future<void> sinirNoktasiEkle(
    String aileKodu,
    Tarla tarla,
    SinirNoktasi nokta,
  ) async {
    final localId = tarla.id;
    if (localId == null) return;

    await DatabaseHelper.instance.sinirNoktasiEkle(
      SinirNoktasi(
        tarlaId: localId,
        enlem: nokta.enlem,
        boylam: nokta.boylam,
      ),
    );
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
  }

  Future<void> sinirNoktalariniTemizle(String aileKodu, Tarla tarla) async {
    if (tarla.id != null) {
      await DatabaseHelper.instance.sinirNoktalariSil(tarla.id!);
    }
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
  }

  Future<void> sinirNoktalariGuncelle(
    String aileKodu,
    Tarla tarla,
    List<SinirNoktasi> noktalar,
  ) async {
    await _aileUyeliginiDogrulaOrHazirla(aileKodu);
    final localId = tarla.id;
    if (localId == null) return;

    await DatabaseHelper.instance.tarlaSinirNoktalariYenile(
      localId,
      noktalar
          .map(
            (nokta) => SinirNoktasi(
              tarlaId: localId,
              enlem: nokta.enlem,
              boylam: nokta.boylam,
            ),
          )
          .toList(),
    );
    await _tekTarlayiBulutaGonder(aileKodu, tarla);
    await _guvenlikYedegiAl('sinir_noktalari_guncellendi');
  }

  Future<void> _tekTarlayiBulutaGonder(String aileKodu, Tarla tarla) async {
    final localId = tarla.id;
    if (localId == null) return;

    tarla.remoteId ??=
        await DatabaseHelper.instance.tarlaRemoteIdGetir(localId) ?? _remoteIdUret();
    final islemler = await DatabaseHelper.instance.tarlaIslemleri(localId);
    final sinirlar = await DatabaseHelper.instance.tarlaSinirNoktalari(localId);
    final gelirler = await DatabaseHelper.instance.tarlaGelirleri(localId);
    
    await DatabaseHelper.instance.tarlaGuncelle(tarla);

    unawaited(
      _guvenliBulutIslemi(() async {
        await _tarlaCollection(aileKodu).doc(tarla.remoteId).set(
              _tarlaDokumani(tarla, islemler, sinirlar, gelirler),
            );
      }).catchError((e) {
        AppLogger.w('Tarla degisiklikleri buluta gonderilemedi', e);
        return false;
      }),
    );
  }



  Future<void> _tarlaSonIslemleriniYenile(Tarla tarla) async {
    final localId = tarla.id;
    if (localId == null) return;

    final islemler = await DatabaseHelper.instance.tarlaIslemleri(localId);

    DateTime? sonSulama;
    DateTime? sonGubre;
    DateTime? sonIlac;

    for (final islem in islemler) {
      final zaman = DateTime.tryParse(islem.baslangicZamani ?? '');
      if (zaman == null) continue;

      if (islem.tur == 'Sulama' &&
          (sonSulama == null || zaman.isAfter(sonSulama))) {
        sonSulama = zaman;
      }
      if (islem.tur == 'Gubre' &&
          (sonGubre == null || zaman.isAfter(sonGubre))) {
        sonGubre = zaman;
      }
      if (islem.tur == 'Ilac' &&
          (sonIlac == null || zaman.isAfter(sonIlac))) {
        sonIlac = zaman;
      }
    }

    tarla
      ..sonSulama = sonSulama
      ..sonGubre = sonGubre
      ..sonIlac = sonIlac;

    await DatabaseHelper.instance.tarlaGuncelle(tarla);
  }

  Future<bool> bekleyenSilmeleriEsitle(String aileKodu) async {
    var tumuBasarili = true;
    final bekleyenRemoteIdler =
        await AppSessionService.bekleyenSilmeleriGetir(aileKodu);

    for (final remoteId in bekleyenRemoteIdler) {
      final basarili = await _guvenliBulutIslemi(() async {
        await _tarlaCollection(aileKodu).doc(remoteId).delete();
      });
      if (basarili) {
        await AppSessionService.bekleyenSilmeyiKaldir(aileKodu, remoteId);
      } else {
        tumuBasarili = false;
      }
    }

    return tumuBasarili;
  }

  Future<bool> _guvenliBulutIslemi(
    Future<void> Function() action, {
    int maxDeneme = 3,
  }) async {
    Object? sonHata;
    for (var deneme = 1; deneme <= maxDeneme; deneme++) {
      try {
        await action().timeout(const Duration(seconds: 4));
        return true;
      } catch (error) {
        sonHata = error;
        if (deneme < maxDeneme) {
          await Future<void>.delayed(Duration(milliseconds: 250 * deneme));
        }
      }
    }
    if (sonHata != null) {
      AppLogger.w('CloudSyncService: güvenli işlem başarısız', sonHata);
    }
    return false;
  }

  Future<void> _uzaktakiVeriyiYereleYaz(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    {
    bool tamEslestir = false,
  }) async {
    final mevcutTarlalar = await DatabaseHelper.instance.tumTarlalar();
    final uzakRemoteIdler = <String>{};

    for (final doc in docs) {
      uzakRemoteIdler.add(doc.id);
      final data = doc.data();
      await _tekDokumaniYereleYaz(doc.id, data);
    }

    if (!tamEslestir) return;

    for (final tarla in mevcutTarlalar) {
      final remoteId = tarla.remoteId;
      if (remoteId == null || uzakRemoteIdler.contains(remoteId)) continue;
      if (tarla.id == null) continue;
      await DatabaseHelper.instance.tarlaKaliciSil(tarla.id!);
    }
  }

  Future<void> _uzakDegisiklikleriYereleIsle(
    List<DocumentChange<Map<String, dynamic>>> degisiklikler,
  ) async {
    for (final degisiklik in degisiklikler) {
      if (degisiklik.type == DocumentChangeType.removed) {
        final localId =
            await DatabaseHelper.instance.tarlaIdGetirRemoteId(degisiklik.doc.id);
        if (localId != null) {
          await DatabaseHelper.instance.tarlaKaliciSil(localId);
        }
        continue;
      }

      final data = degisiklik.doc.data();
      if (data == null) continue;
      await _tekDokumaniYereleYaz(degisiklik.doc.id, data);
    }
  }

  Future<void> _tekDokumaniYereleYaz(
    String remoteId,
    Map<String, dynamic> data,
  ) async {
    // Mevcut yerel kaydi bul (foto/not kaybolmasin diye yerel fallback)
    final mevcutYerel = await DatabaseHelper.instance.remoteIdIleTarlaGetir(remoteId);
    final bulutFoto = data['fotoBase64'] as String? ?? '';
    final korunanFoto = bulutFoto.isNotEmpty ? bulutFoto : (mevcutYerel?.fotoBase64 ?? '');
    final bulutNot = data['notlar'] as String? ?? '';
    final korunanNot = bulutNot.isNotEmpty ? bulutNot : (mevcutYerel?.notlar ?? '');

    final tarla = Tarla(
      remoteId: remoteId,
      ad: data['ad'] as String? ?? '',
      urun: data['urun'] as String? ?? '',
      alan: data['alan'] as String? ?? '',
      alanMetrekare: (data['alanMetrekare'] as num?)?.toDouble(),
      alanDekar: (data['alanDekar'] as num?)?.toDouble(),
      enlem: (data['enlem'] as num?)?.toDouble(),
      boylam: (data['boylam'] as num?)?.toDouble(),
      notlar: korunanNot,
      fotoBase64: korunanFoto,
      silinmisMi: (data['silinmisMi'] as bool?) ?? false,
      silinmeTarihi: _parseDate(data['silinmeTarihi']),
      sonSulama: _parseDate(data['sonSulama']),
      sonGubre: _parseDate(data['sonGubre']),
      sonIlac: _parseDate(data['sonIlac']),
    );

    final localId = await DatabaseHelper.instance.tarlaKaydetVeyaGuncelle(tarla);

    final islemler = ((data['islemler'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (item) => Islem(
            tarlaId: localId,
            tur: item['tur'] as String? ?? '',
            detay: item['detay'] as String? ?? '',
            baslangicZamani: item['baslangicZamani'] as String?,
            tarih: item['tarih'] as String? ?? '',
            kullaniciAdi: item['kullaniciAdi'] as String? ?? '',
            fotoBase64: item['fotoBase64'] as String? ?? '',
            maliyet: (item['maliyet'] as num?)?.toDouble(),
          ),
        )
        .toList();
    await DatabaseHelper.instance.tarlaIslemleriniYenile(localId, islemler);

    final sinirlar = ((data['sinirNoktalari'] as List?) ?? [])
        .whereType<Map>()
        .map((item) {
          final enlem = (item['enlem'] as num?)?.toDouble();
          final boylam = (item['boylam'] as num?)?.toDouble();
          if (enlem == null || boylam == null) return null;
          return SinirNoktasi(
            tarlaId: localId,
            enlem: enlem,
            boylam: boylam,
          );
        })
        .whereType<SinirNoktasi>()
        .toList();
    await DatabaseHelper.instance.tarlaSinirNoktalariYenile(localId, sinirlar);

    final gelirler = ((data['gelirler'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (item) => Gelir(
            tarlaId: localId,
            tarih: item['tarih'] as String? ?? '',
            miktar: (item['miktar'] as num?)?.toDouble() ?? 0.0,
            aciklama: item['aciklama'] as String? ?? '',
          ),
        )
        .toList();
    await DatabaseHelper.instance.tarlaGelirleriniYenile(localId, gelirler);
  }

  Future<void> _aileUyeliginiDogrulaOrHazirla(String aileKodu) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw Exception('Bulut islemi icin oturum acik olmali');
    }
    if (_dogrulanmisAileler.contains(aileKodu)) {
      return;
    }
    try {
      // Uye kaydini ILK once olustur ki firestore rules'taki exists/isMember kontrolu gecsin.
      await _uyeCollection(aileKodu).doc(uid).set(
        {
          'kullaniciAdi': _auth.currentUser?.email?.split('@').first ?? 'Kullanici',
          'katilimTarihi': FieldValue.serverTimestamp(),
          'sonGorulme': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 4));
      
      await _aileRef(aileKodu).set(
        {
          'guncellendi': FieldValue.serverTimestamp(),
          'sonKullanici': uid,
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 4));
      
      _dogrulanmisAileler.add(aileKodu);
    } catch (e) {
      AppLogger.w('Aile üye doğrulaması yapılamadı (muhtemelen çevrimdışı), işleme devam ediliyor: $e');
    }
  }

  String _remoteIdUret() {
    return _firestore.collection('_').doc().id;
  }

  String _rastgeleKodUret() {
    const karakterler = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rastgele = Random.secure();
    return List.generate(
      8,
      (_) => karakterler[rastgele.nextInt(karakterler.length)],
    ).join();
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  Future<String> _benzersizErisimKoduUret() async {
    for (var i = 0; i < 12; i++) {
      final kod = _rastgeleKodUret();
      final sonuc = await _firestore
          .collection('aileler')
          .where('aileErisimKodu', isEqualTo: kod)
          .limit(1)
          .get();
      if (sonuc.docs.isEmpty) {
        return kod;
      }
    }
    return '${_rastgeleKodUret().substring(0, 4)}${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  Future<void> _guvenlikYedegiAl(String sebep) async {
    try {
      await BackupService.guvenlikYedegiOlustur(sebep: sebep);
    } catch (_) {}
  }

  Map<String, dynamic> _tarlaDokumani(
    Tarla tarla,
    List<Islem> islemler,
    List<SinirNoktasi> sinirlar,
    List<Gelir> gelirler,
  ) {
    return {
      'ad': tarla.ad,
      'urun': tarla.urun,
      'alan': tarla.alan,
      'alanMetrekare': tarla.alanMetrekare,
      'alanDekar': tarla.alanDekar,
      'enlem': tarla.enlem,
      'boylam': tarla.boylam,
      'notlar': tarla.notlar,
      'fotoBase64': tarla.fotoBase64,
      'silinmisMi': tarla.silinmisMi,
      'silinmeTarihi': tarla.silinmeTarihi?.toIso8601String(),
      'sonSulama': tarla.sonSulama?.toIso8601String(),
      'sonGubre': tarla.sonGubre?.toIso8601String(),
      'sonIlac': tarla.sonIlac?.toIso8601String(),
      'guncellendi': FieldValue.serverTimestamp(),
      'islemler': islemler
          .map(
            (islem) => {
              'tur': islem.tur,
              'detay': islem.detay,
              'baslangicZamani': islem.baslangicZamani,
              'tarih': islem.tarih,
              'kullaniciAdi': islem.kullaniciAdi,
              'fotoBase64': islem.fotoBase64,
              'maliyet': islem.maliyet,
            },
          )
          .toList(),
      'sinirNoktalari': sinirlar
          .map(
            (nokta) => {
              'enlem': nokta.enlem,
              'boylam': nokta.boylam,
            },
          )
          .toList(),
      'gelirler': gelirler
          .map(
            (gelir) => {
              'tarih': gelir.tarih,
              'miktar': gelir.miktar,
              'aciklama': gelir.aciklama,
            },
          )
          .toList(),
    };
  }
}
