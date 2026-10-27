import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pdf_report_service.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

import '../app_session_service.dart';
import '../backup_service.dart';
import '../cloud_sync_service.dart';
import '../database_helper.dart';
import '../gelir_model.dart';
import '../islem_turu_model.dart';
import '../islem_model.dart';
import '../export_service.dart';
import '../sinir_noktasi_model.dart';
import '../tarla_model.dart';
import '../weather_service.dart';

import '../utils/app_helpers.dart';
import '../screens/screens.dart';
import '../widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fields_provider.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';

class TarlaListesi extends ConsumerStatefulWidget {
  const TarlaListesi({
    super.key,
    required this.aileKodu,
    required this.ortakTarlaKodu,
    this.aileAdi,
    this.aileErisimKodu,
    required this.bulutEtkin,
    required this.onAileDegistir,
    required this.onOrtakTarlaKodunuDegistir,
    this.onAileBilgisiniDegistir,
    required this.kullaniciAdi,
    required this.aileSahibiMi,
    this.currentKullaniciId,
    this.yerelModBilgisi,
    this.onBulutuTekrarDene,
  });

  final String aileKodu;
  final String ortakTarlaKodu;
  final String? aileAdi;
  final String? aileErisimKodu;
  final bool bulutEtkin;
  final Future<void> Function() onAileDegistir;
  final Future<void> Function(String yeniKod) onOrtakTarlaKodunuDegistir;
  final Future<void> Function({
    required String yeniAileAdi,
    required String yeniKod,
  })? onAileBilgisiniDegistir;
  final String kullaniciAdi;
  final bool aileSahibiMi;
  final String? currentKullaniciId;
  final String? yerelModBilgisi;
  final Future<void> Function()? onBulutuTekrarDene;

  @override
  ConsumerState<TarlaListesi> createState() => _TarlaListesiState();
}

class _TarlaListesiState extends ConsumerState<TarlaListesi> {
  StreamSubscription? aileDinleyici;
  StreamSubscription? _baglantiDinleyici;
  bool _cevrimici = true;
  int _toplamIslemSayisi = 0;
  double _toplamMaliyetTL = 0.0;
  StreamSubscription? aileBelgeDinleyici;
  StreamSubscription? kullaniciBelgeDinleyici;
  final TextEditingController aramaController = TextEditingController();
  String aramaMetni = '';
  String seciliSiralama = 'Son guncellenen';
  bool pdfHatirlatmaAcik = false;
  int altMenuIndex = 0;
  bool _konfetiGoster = false;
  bool pdfReminderEnabled = true;
  int pdfReminderIntervalDays = 14;
  int archiveRetentionDays = 30;

  TarlaHavaDurumu? _havaDurumu;
  bool _havaYukleniyor = false;

  Future<void> _havaDurumuYukle() async {
    if (_havaYukleniyor) return;
    setState(() {
      _havaYukleniyor = true;
    });

    try {
      double? enlem;
      double? boylam;

      final fields = ref.read(fieldsProvider).value ?? [];
      final fieldsWithLocation = fields.where((f) => f.enlem != null && f.boylam != null).toList();
      
      if (fieldsWithLocation.isNotEmpty) {
        enlem = fieldsWithLocation.first.enlem;
        boylam = fieldsWithLocation.first.boylam;
      } else {
        try {
          final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
          if (isLocationEnabled) {
            var permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
              final position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.low,
                ),
              );
              enlem = position.latitude;
              boylam = position.longitude;
            }
          }
        } catch (_) {}
      }

      enlem ??= 37.8560;
      boylam ??= 27.8420;

      final sonuc = await WeatherService.havaDurumuGetir(
        enlem: enlem,
        boylam: boylam,
      );

      if (!mounted) return;
      setState(() {
        _havaDurumu = sonuc;
        _havaYukleniyor = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _havaYukleniyor = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _ayarlariYukle();
      await _ilkYuklemeyiYap();
    });
  }

  Future<void> _ayarlariYukle() async {
    final enabled = await AppSessionService.pdfHatirlatmaEtkinGetir();
    final interval = await AppSessionService.pdfHatirlatmaSikligiGetir();
    final retention = await AppSessionService.arsivSaklamaSuresiGetir();
    if (!mounted) return;
    setState(() {
      pdfReminderEnabled = enabled;
      pdfReminderIntervalDays = interval;
      archiveRetentionDays = retention;
    });
  }

  Future<void> _ilkYuklemeyiYap() async {
    try {
      await tarlalariYukle();
      _havaDurumuYukle();
      await otomatikYedekGerekirseAl();
      // Hatirlatma kontrolu build icinde veya liste geldikten sonra yapilmali
      if (!widget.bulutEtkin) return;
      
      final bulutaYazimBasarili =
          await CloudSyncService.instance.yereldenBulutaSenkronizeEt(
        widget.aileKodu,
      );
      try {
        await CloudSyncService.instance.buluttanYereleSenkronizeEt(
          widget.aileKodu,
          tamEslestir: bulutaYazimBasarili,
        );
      } catch (_) {}
      
      if (!mounted) return;
      await tarlalariYukle();
      aileDinlemeyiBaslat();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ana ekran verileri yüklenemedi: $error'),
        ),
      );
    }
  }

  void aileDinlemeyiBaslat() {
    if (!widget.bulutEtkin) return;
    aileDinleyici?.cancel();
    aileDinleyici = CloudSyncService.instance.aileyiDinle(
      widget.aileKodu,
      senkronSonrasi: tarlalariYukle,
    );

    aileBelgeDinleyici?.cancel();
    aileBelgeDinleyici = CloudSyncService.instance.aileBelgesiniDinle(widget.aileKodu).listen((snapshot) async {
      if (!mounted) return;
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final yeniErisimKodu = data['aileErisimKodu'] as String?;
        final yeniAileAdi = data['aileAdi'] as String?;
        bool oturumGuncellensinMi = false;

        if (yeniErisimKodu != null || yeniAileAdi != null) {
          if (!mounted) return;
          final session = ref.read(authProvider).value;
          if (session != null) {
            final guncelErisimKodu = yeniErisimKodu ?? session.familyAccessCode ?? session.sharedFarmCode ?? '';
            final guncelAileAdi = yeniAileAdi ?? session.familyName ?? '';
            final mevcutErisimKodu = session.familyAccessCode ?? session.sharedFarmCode ?? '';
            final mevcutAileAdi = session.familyName ?? '';
            if (guncelErisimKodu != mevcutErisimKodu || guncelAileAdi != mevcutAileAdi) {
              await AppSessionService.aileAdiniKaydet(guncelAileAdi);
              await AppSessionService.authBilgisiniKaydet(
                mode: session.mode.name,
                userId: session.userId,
                email: session.email,
                sharedFarmCode: guvenliKodNormalizeEt(guncelErisimKodu),
              );
              oturumGuncellensinMi = true;
            }
          }
        }

        if (oturumGuncellensinMi) {
          if (!mounted) return;
          await ref.read(authProvider.notifier).refreshSession();
        }

        // Ozel islem turlerini de gercek zamanli sync et
        final rawTipler = data['ozelIslemTurleri'];
        if (rawTipler is List && rawTipler.isNotEmpty) {
          final yeniTipler = rawTipler
              .whereType<Map<String, dynamic>>()
              .map((m) => IslemTuruTanim.fromMap(m))
              .toList();
          await AppSessionService.ozelIslemTurleriniKaydet(widget.aileKodu, yeniTipler);
        }
      }
    });

    // Baglanti durumu dinleyici
    _baglantiDinleyici?.cancel();
    _baglantiDinleyici = Connectivity().onConnectivityChanged.listen((results) {
      final yeniCevrimici = results.any((r) => r != ConnectivityResult.none);
      if (!mounted) return;
      final oncekiCevrimici = _cevrimici;
      setState(() => _cevrimici = yeniCevrimici);
      // Yeniden baglandi ve bulut aktif -> otomatik sync
      if (yeniCevrimici && !oncekiCevrimici && widget.bulutEtkin) {
        senkronizeEt();
      }
    });

    // Kullanici profil adini gercek zamanli dinle
    final session0 = ref.read(authProvider).value;
    if (session0 != null && session0.cloudEnabled && session0.familyId != null && session0.userId.isNotEmpty) {
      kullaniciBelgeDinleyici?.cancel();
      kullaniciBelgeDinleyici = CloudSyncService.instance
          .kullaniciBelgesiniDinle(session0.familyId!, session0.userId)
          .listen((snap) async {
        if (!mounted || !snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final yeniAd = (data['kullaniciAdi'] as String?)?.trim() ?? '';
        if (yeniAd.isEmpty) return;
        final prefs = await SharedPreferences.getInstance();
        final mevcutAd = prefs.getString('profil_ad_soyad') ?? '';
        if (yeniAd != mevcutAd) {
          await AppSessionService.kullaniciAdiniKaydet(yeniAd);
          await prefs.setString('profil_ad_soyad', yeniAd);
          if (!mounted) return;
          final sess = ref.read(authProvider).value;
          if (sess != null) {
            await ref.read(authProvider.notifier).setSession(sess.copyWith(displayName: yeniAd));
          }
        }
      });
    }
  }

  @override
  void dispose() {
    aileDinleyici?.cancel();
    aileBelgeDinleyici?.cancel();
    kullaniciBelgeDinleyici?.cancel();
    aramaController.dispose();
    super.dispose();
  }

  Future<void> tarlalariYukle() async {
    if (!mounted) return;
    await ref.read(fieldsProvider.notifier).refreshFields();
    if (!mounted) return;
    _havaDurumuYukle();
  }

  Future<void> guvenlikYedegiAl(String sebep) async {
    try {
      await BackupService.guvenlikYedegiOlustur(sebep: sebep);
    } catch (_) {}
  }

  String tarihSaatiGoster(DateTime? tarih) {
    if (tarih == null) return 'Kayıt yok';
    return formatTarihSaat(tarih);
  }

  void filtreleriTemizle() {
    aramaController.clear();
    setState(() {
      aramaMetni = '';
      seciliSiralama = 'Son guncellenen';
    });
  }

  Color tarlaRenk(BuildContext context, DateTime? sonSulama) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (sonSulama == null) {
      return isDark ? Colors.red.shade900.withValues(alpha: 0.4) : Colors.red.shade50;
    }

    final fark = turkiyeSimdi().difference(sonSulama).inDays;
    if (fark <= 1) return isDark ? Colors.green.shade900.withValues(alpha: 0.4) : Colors.green.shade50;
    if (fark <= 3) return isDark ? Colors.lightGreen.shade900.withValues(alpha: 0.4) : Colors.lightGreen.shade50;
    if (fark <= 6) return isDark ? Colors.amber.shade900.withValues(alpha: 0.4) : Colors.amber.shade50;
    if (fark <= 9) return isDark ? Colors.orange.shade900.withValues(alpha: 0.4) : Colors.orange.shade50;
    if (fark <= 13) return isDark ? Colors.deepOrange.shade900.withValues(alpha: 0.4) : Colors.deepOrange.shade50;
    return isDark ? Colors.red.shade900.withValues(alpha: 0.6) : Colors.red.shade100;
  }

  Future<void> tarlaSil(Tarla tarla) async {
    if (widget.bulutEtkin && !widget.aileSahibiMi) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarla silme yetkisi yonetici hesapta'),
        ),
      );
      return;
    }
    
    await ref.read(fieldsProvider.notifier).deleteField(tarla);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${tarla.ad} arşive alındı. $archiveRetentionDays gün içinde Silinen Tarlalar ekranından geri yükleyebilirsin.',
        ),
      ),
    );
  }

  Future<void> silinenTarlalariAc() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SilinenTarlalarSayfasi(
          aileKodu: widget.aileKodu,
          bulutEtkin: widget.bulutEtkin,
        ),
      ),
    );
    await tarlalariYukle();
  }

  Future<void> tarlaEkle(
    Tarla tarla, {
    List<SinirNoktasi> sinirNoktalari = const [],
  }) async {
    final alanMetrekare = parselAlaniMetrekare(sinirNoktalari);
    if (sinirNoktalari.length >= 3) {
      tarla
        ..alanMetrekare = alanMetrekare
        ..alan = tarla.alan.trim().isEmpty
            ? formatAlanOzeti(alanMetrekare: alanMetrekare)
            : tarla.alan;
    }
    if (widget.bulutEtkin) {
      await CloudSyncService.instance.tarlaEkle(widget.aileKodu, tarla);
    } else {
      final id = await DatabaseHelper.instance.tarlaEkle(tarla);
      tarla.id = id;
      await guvenlikYedegiAl('tarla_eklendi');
    }
    if (sinirNoktalari.isNotEmpty) {
      final localId = tarla.id ??
          (tarla.remoteId == null
              ? null
              : await DatabaseHelper.instance.tarlaIdGetirRemoteId(
                  tarla.remoteId!,
                ));
      if (localId != null) {
        tarla.id = localId;
        final duzenlenmis = sinirNoktalari
            .map(
              (nokta) => SinirNoktasi(
                tarlaId: localId,
                enlem: nokta.enlem,
                boylam: nokta.boylam,
              ),
            )
            .toList();
        if (widget.bulutEtkin) {
          await CloudSyncService.instance.sinirNoktalariGuncelle(
            widget.aileKodu,
            tarla,
            duzenlenmis,
          );
        } else {
          await DatabaseHelper.instance.tarlaSinirNoktalariYenile(
            localId,
            duzenlenmis,
          );
          await guvenlikYedegiAl('sinir_noktalari_eklendi');
        }
      }
    }
    await tarlalariYukle();
  }

  Future<void> tarlaGuncelle(
    Tarla tarla, {
    List<SinirNoktasi> sinirNoktalari = const [],
  }) async {
    final alanMetrekare = parselAlaniMetrekare(sinirNoktalari);
    if (sinirNoktalari.length >= 3) {
      tarla
        ..alanMetrekare = alanMetrekare
        ..alan = tarla.alan.trim().isEmpty
            ? formatAlanOzeti(alanMetrekare: alanMetrekare)
            : tarla.alan;
    }
    if (widget.bulutEtkin) {
      await CloudSyncService.instance.tarlaGuncelle(widget.aileKodu, tarla);
    } else {
      await DatabaseHelper.instance.tarlaGuncelle(tarla);
      await guvenlikYedegiAl('tarla_guncellendi');
    }
    if (sinirNoktalari.isNotEmpty) {
      final localId = tarla.id ??
          (tarla.remoteId == null
              ? null
              : await DatabaseHelper.instance.tarlaIdGetirRemoteId(
                  tarla.remoteId!,
                ));
      if (localId != null) {
        tarla.id = localId;
        final duzenlenmis = sinirNoktalari
            .map(
              (nokta) => SinirNoktasi(
                tarlaId: localId,
                enlem: nokta.enlem,
                boylam: nokta.boylam,
              ),
            )
            .toList();
        if (widget.bulutEtkin) {
          await CloudSyncService.instance.sinirNoktalariGuncelle(
            widget.aileKodu,
            tarla,
            duzenlenmis,
          );
        } else {
          await DatabaseHelper.instance.tarlaSinirNoktalariYenile(
            localId,
            duzenlenmis,
          );
          await guvenlikYedegiAl('sinir_noktalari_guncellendi');
        }
      }
    }
    await tarlalariYukle();
  }

  Future<void> pdfRaporuIndir({bool onayla = true}) async {
    if (onayla) {
      final eminMi = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Analiz Raporu'),
          content: const Text('Tüm tarlaların analiz raporu PDF olarak açılacak.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aç'),
            ),
          ],
        ),
      );
      if (eminMi != true) return;
    }
    try {
      final dosyaYolu = await ExportService.pdfRaporuOlustur();
      await AppSessionService.pdfHatirlatmaTarihiniKaydet(widget.aileKodu, turkiyeSimdi());
      if (!mounted) return;
      await OpenFile.open(dosyaYolu);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Analiz Raporu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Paylaş'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Share.shareXFiles([XFile(dosyaYolu)], text: 'Tarım360 Analiz Raporu');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF raporu olusturulamadi: $error')));
    }
  }
  Future<void> finansRaporuIndir() async {
    try {
      final tarlalar = await DatabaseHelper.instance.tumTarlalar();
      if (tarlalar.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Henüz tarla eklenmemiş.')),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finans raporu hazırlanıyor...'), duration: Duration(seconds: 2)),
      );

      final prefs = await SharedPreferences.getInstance();
      final aileAdi = prefs.getString('profil_ad_soyad') ?? '';

      final tarlaIslemleriMap = <int, List<Islem>>{};
      final tarlaGelirleriMap = <int, List<Gelir>>{};
      for (final tarla in tarlalar) {
        if (tarla.id == null) continue;
        tarlaIslemleriMap[tarla.id!] = await DatabaseHelper.instance.tarlaIslemleri(tarla.id!);
        tarlaGelirleriMap[tarla.id!] = await DatabaseHelper.instance.tarlaGelirleri(tarla.id!);
      }

      final dosya = await PdfReportService.tumTarlaFinansRaporuOlustur(
        tarlalar: tarlalar,
        tarlaIslemleriMap: tarlaIslemleriMap,
        tarlaGelirleriMap: tarlaGelirleriMap,
        aileAdi: aileAdi,
      );

      if (!mounted) return;

      // Önce PDF'i aç
      await OpenFile.open(dosya.path);

      // Sonra indir/paylaş seçeneği sun
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Finans Raporu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Paylaş'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Share.shareXFiles([XFile(dosya.path)], text: 'Tarım360 Finans Raporu');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Finans raporu oluşturulamadı: $e')),
      );
    }
  }

  Future<void> tarlaEkleSayfasiniAc() async {
    final sonuc = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => TarlaEkleSayfasi(
          onTarlaKaydet: (tarla, sinirNoktalari) =>
              tarlaEkle(tarla, sinirNoktalari: sinirNoktalari),
        ),
      ),
    );
    if (!mounted) return;
    await tarlalariYukle();
    if (sonuc == true) {
      setState(() {
        _konfetiGoster = true;
      });
    }
  }

  Future<void> ayarlariAc() async {
    final sonuc = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => AyarlarSayfasi(
          aileKodu: widget.aileKodu,
          ortakTarlaKodu: widget.ortakTarlaKodu,
          aileAdi: widget.aileAdi,
          aileErisimKodu: widget.aileErisimKodu,
          bulutEtkin: widget.bulutEtkin,
          kullaniciAdi: widget.kullaniciAdi,
          aileSahibiMi: widget.aileSahibiMi,
          onAileBilgisiniDegistir: widget.onAileBilgisiniDegistir,
          currentKullaniciId: widget.currentKullaniciId,
          onSenkronizeEt: senkronizeEt,
          onBulutuTekrarDene: widget.onBulutuTekrarDene,
          onSilinenTarlalariAc: silinenTarlalariAc,
          onAiledenCik: widget.onAileDegistir,
          onOrtakTarlaKodunuDegistir: widget.onOrtakTarlaKodunuDegistir,
          onAylikVeriIndir: pdfRaporuIndir,
          onVeriyiYenile: tarlalariYukle,
        ),
      ),
    );
    if (sonuc == 'git_rapor_sayfasi') {
      setState(() {
        altMenuIndex = 1;
      });
    } else {
      if (!mounted) return;
      await tarlalariYukle();
    }
  }

  Future<void> altMenuTiklandi(int index) async {
    if (!mounted) return;
    // index 4 = Ayarlar
    if (index == 4) {
      await ayarlariAc();
      return;
    }
    // index 3 = Finans
    if (index == 3) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => const FinancialDashboardScreen(),
        ),
      );
      // Geri dönünce index'i sıfırla
      if (mounted) setState(() => altMenuIndex = 0);
      return;
    }
    setState(() {
      altMenuIndex = index;
    });
  }

  Future<void> otomatikYedekGerekirseAl() async {
    try {
      final siklik = await AppSessionService.otomatikYedekSikligiGunGetir();
      final sonBasarili = await AppSessionService.sonBasariliYedekTarihiniGetir();
      final simdi = turkiyeSimdi();
      if (sonBasarili != null && simdi.difference(sonBasarili).inDays < siklik) {
        return;
      }
      await BackupService.guvenlikYedegiOlustur(sebep: 'zamanli_otomatik');
    } catch (_) {}
  }

  Future<void> _istatistikleriHesapla(List<Tarla> tarlalar) async {
    var count = 0;
    var maliyet = 0.0;
    for (final tarla in tarlalar) {
      if (tarla.id == null) continue;
      final islemler = await DatabaseHelper.instance.tarlaIslemleri(tarla.id!);
      count += islemler.length;
      maliyet += islemler.fold(0.0, (s, i) => s + (i.maliyet ?? 0.0));
    }
    if (!mounted) return;
    setState(() {
      _toplamIslemSayisi = count;
      _toplamMaliyetTL = maliyet;
    });

    // Kullanici profil adini gercek zamanli dinle
    final session0 = ref.read(authProvider).value;
    if (session0 != null && session0.cloudEnabled && session0.familyId != null && session0.userId.isNotEmpty) {
      kullaniciBelgeDinleyici?.cancel();
      kullaniciBelgeDinleyici = CloudSyncService.instance
          .kullaniciBelgesiniDinle(session0.familyId!, session0.userId)
          .listen((snap) async {
        if (!mounted || !snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final yeniAd = (data['kullaniciAdi'] as String?)?.trim() ?? '';
        if (yeniAd.isEmpty) return;
        final mevcutAd = (await SharedPreferences.getInstance()).getString('profil_ad_soyad') ?? '';
        if (yeniAd != mevcutAd) {
          await AppSessionService.kullaniciAdiniKaydet(yeniAd);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profil_ad_soyad', yeniAd);
          if (!mounted) return;
          final sess = ref.read(authProvider).value;
          if (sess != null) {
            await ref.read(authProvider.notifier).setSession(sess.copyWith(displayName: yeniAd));
          }
        }
      });
    }
  }

  Future<void> aylikPdfHatirlatmasiniKontrolEt(List<Tarla> tarlalar) async {
    if (!mounted || pdfHatirlatmaAcik || tarlalar.isEmpty) return;

    final etkin = await AppSessionService.pdfHatirlatmaEtkinGetir();
    if (!etkin) return;

    final simdi = turkiyeSimdi();
    final sonHatirlatma =
        await AppSessionService.sonPdfHatirlatmaTarihiniGetir(widget.aileKodu);
    final siklikGun = await AppSessionService.pdfHatirlatmaSikligiGetir();

    if (sonHatirlatma != null && simdi.difference(sonHatirlatma).inDays < siklikGun) {
      return;
    }
    if (!mounted) return;

    pdfHatirlatmaAcik = true;
    final indirilsinMi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$siklikGun Günlük PDF Hatırlatması'),
        content: const Text(
          'Tüm tarlalarınızın PDF özetini indirip telefonunuzdaki İndirilenler klasöründe saklamak ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('$siklikGun gün sorma'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('PDF indir'),
          ),
        ],
      ),
    );
    pdfHatirlatmaAcik = false;
    if (!mounted) return;

    await AppSessionService.pdfHatirlatmaTarihiniKaydet(
      widget.aileKodu,
      simdi,
    );

    if (indirilsinMi == true) {
      await pdfRaporuIndir(onayla: false);
    }
  }

  Future<void> senkronizeEt() async {
    if (!widget.bulutEtkin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu cihaz yerel modda calisiyor')),
      );
      return;
    }

    final bulutaYazimBasarili =
        await CloudSyncService.instance.yereldenBulutaSenkronizeEt(
      widget.aileKodu,
    );
    try {
      await CloudSyncService.instance.buluttanYereleSenkronizeEt(
        widget.aileKodu,
        tamEslestir: bulutaYazimBasarili,
      );
    } catch (_) {}
    await tarlalariYukle();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bulutaYazimBasarili
              ? 'Senkronizasyon tamamlandi'
              : 'Yerel kayitlar korunarak kismi senkron yapildi',
        ),
      ),
    );
  }

  String konumMetni(Tarla tarla) {
    if (tarla.enlem == null || tarla.boylam == null) {
      return 'Konum kaydi yok';
    }
    return '${tarla.enlem!.toStringAsFixed(5)}, ${tarla.boylam!.toStringAsFixed(5)}';
  }

  Widget tarlaKarti(Tarla tarla) {
    final alanOzeti = formatAlanOzeti(
      alanMetrekare: tarla.alanMetrekare,
      alanDekar: tarla.alanDekar,
      varsayilanMetin: tarla.alan,
    );
    final darEkran = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ekBilgi = <String>[
      if (tarla.urun.trim().isNotEmpty) tarla.urun.trim(),
    ].join(' - ');
    final tema = Theme.of(context);

    // Dynamic gradient based on status
    final statusColor = tarlaRenk(context, tarla.sonSulama);
    final baseColor = isDark ? const Color(0xFF1B3B2B) : const Color(0xFFE8F5E9);
    final gradientColors = [
      Color.lerp(baseColor, statusColor, 0.3)!,
      Color.lerp(baseColor, statusColor, 0.1)!,
    ];

    return Dismissible(
      key: Key('tarla-${tarla.id ?? tarla.ad}'),
      direction: widget.aileSahibiMi
          ? DismissDirection.endToStart
          : DismissDirection.none,
      confirmDismiss: (_) async {
        return showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tarlayı arşive al'),
            content: Text(
              '${tarla.ad} ve tüm işlem geçmişi arşive alınsın mı? Bu kaydı 30 gün içinde Silinen Tarlalar ekranından geri yükleyebilirsin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Arşive al'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => tarlaSil(tarla),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.96, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        ),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: statusColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () async {
              await aileDinleyici?.cancel();
              aileDinleyici = null;
              await aileBelgeDinleyici?.cancel();
              aileBelgeDinleyici = null;
              if (!mounted) return;
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (context) => TarlaDetaySayfasi(
                    tarla: tarla,
                    aileKodu: widget.aileKodu,
                    bulutEtkin: widget.bulutEtkin,
                    kullaniciAdi: widget.kullaniciAdi,
                    aileSahibiMi: widget.aileSahibiMi,
                  ),
                ),
              );
              if (!mounted) return;
              if (widget.bulutEtkin) {
                aileDinlemeyiBaslat();
              }
              await tarlalariYukle();
            },
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Decorative background icon
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.eco_rounded,
                      size: 140,
                      color: statusColor.withValues(alpha: 0.05),
                    ),
                  ),
                  Padding(
                    padding: darEkran
                        ? const EdgeInsets.all(18)
                        : const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tarla.ad,
                                          style: tema.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 22,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (ekBilgi.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black26 : Colors.white60,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.grass_rounded, size: 14, color: statusColor.withValues(alpha: 0.8)),
                                          const SizedBox(width: 6),
                                          Text(
                                            ekBilgi,
                                            style: tema.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (alanOzeti != 'Alan bilgisi yok') ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.straighten, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Text(
                                          alanOzeti,
                                          style: tema.textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                DurumRozeti(
                                  renk: aciliyetRengi(tarla),
                                  metin: aciliyetMetni(tarla),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.bulutEtkin && !widget.aileSahibiMi)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Tooltip(
                                          message: 'Silme yetkisi yönetici hesapta',
                                          child: Icon(
                                            Icons.lock_outline,
                                            size: 20,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black12 : Colors.white54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          await Navigator.push<void>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TarlaEkleSayfasi(
                                                mevcutTarla: tarla,
                                                onTarlaKaydet: (guncelTarla, sinirNoktalari) =>
                                                    tarlaGuncelle(
                                                  guncelTarla,
                                                  sinirNoktalari: sinirNoktalari,
                                                ),
                                              ),
                                            ),
                                          );
                                          if (!mounted) return;
                                          await tarlalariYukle();
                                        },
                                        icon: const Icon(Icons.edit_outlined, size: 22),
                                        tooltip: 'Tarlayı düzenle',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, thickness: 1, color: Colors.black12),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            MiniBilgiRozeti(
                              ikon: Icons.water_drop_rounded,
                              renk: Colors.blue.shade600,
                              metin: 'Sulama',
                              altMetin: tarihSaatiGoster(tarla.sonSulama),
                            ),
                            MiniBilgiRozeti(
                              ikon: Icons.compost_rounded,
                              renk: Colors.green.shade600,
                              metin: 'Gübre',
                              altMetin: tarihSaatiGoster(tarla.sonGubre),
                            ),
                            MiniBilgiRozeti(
                              ikon: Icons.science_rounded,
                              renk: Colors.deepOrange.shade500,
                              metin: 'İlaç',
                              altMetin: tarihSaatiGoster(tarla.sonIlac),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Tarla> getGorunenTarlalar(List<Tarla> tumTarlalar) {
    final arama = aramaMetni.trim().toLowerCase();
    var filtreli = tumTarlalar.where((tarla) {
      if (arama.isEmpty) return true;
      return tarla.ad.toLowerCase().contains(arama) ||
          tarla.urun.toLowerCase().contains(arama) ||
          tarla.alan.toLowerCase().contains(arama);
    }).toList();

    int siralamaKarsilastir(Tarla a, Tarla b) {
      switch (seciliSiralama) {
        case 'Ada gore (A-Z)':
          return a.ad.toLowerCase().compareTo(b.ad.toLowerCase());
        case 'Ada gore (Z-A)':
          return b.ad.toLowerCase().compareTo(a.ad.toLowerCase());
        case 'En kritik sulama':
          final aFark = a.sonSulama == null ? 9999 : turkiyeSimdi().difference(a.sonSulama!).inDays;
          final bFark = b.sonSulama == null ? 9999 : turkiyeSimdi().difference(b.sonSulama!).inDays;
          return bFark.compareTo(aFark);
        case 'Son isleme gore':
          final aTarih = sonIslemTarihi(a);
          final bTarih = sonIslemTarihi(b);
          if (aTarih == null && bTarih == null) return 0;
          if (aTarih == null) return 1;
          if (bTarih == null) return -1;
          return bTarih.compareTo(aTarih);
        case 'Son guncellenen':
        default:
          return (b.id ?? 0).compareTo(a.id ?? 0);
      }
    }

    filtreli.sort(siralamaKarsilastir);
    return filtreli;
  }

  Widget _bolumBasligi({
    required String baslik,
    required String aciklama,
    Widget? eylem,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final darEkran = constraints.maxWidth < 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!darEkran && eylem != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: BolumBaslikMetni(baslik: baslik, aciklama: aciklama)),
                  const SizedBox(width: 12),
                  eylem,
                ],
              )
            else ...[
              BolumBaslikMetni(baslik: baslik, aciklama: aciklama),
              if (eylem != null) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: eylem),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _uyariKarti({
    required Color vurgu,
    required IconData ikon,
    required String baslik,
    required Widget icerik,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: vurgu.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: vurgu.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(ikon, color: vurgu),
                ),
                const SizedBox(width: 12),
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            icerik,
          ],
        ),
      ),
    );
  }

  Widget _anaKisayolKarti({
    required IconData ikon,
    required Color renk,
    required String baslik,
    required String aciklama,
    required VoidCallback onTap,
  }) {
    final darEkran = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final l10n = ref.read(languageProvider.notifier);
    String t(String key) => l10n.translate(key);

    String emoji;
    if (baslik == t('add_field') || baslik.toLowerCase().contains('ekle') || baslik.toLowerCase().contains('add')) {
      emoji = '🌿';
    } else if (baslik == t('field_summary') || baslik.toLowerCase().contains('ozet') || baslik.toLowerCase().contains('summary')) {
      emoji = '📊';
    } else if (baslik == t('finance_status') || baslik.toLowerCase().contains('finans') || baslik.toLowerCase().contains('finance')) {
      emoji = '💰';
    } else {
      emoji = '📁';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [renk.withValues(alpha: 0.20), renk.withValues(alpha: 0.08)]
                  : [Colors.white.withValues(alpha: 0.95), renk.withValues(alpha: 0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: renk.withValues(alpha: isDark ? 0.25 : 0.14),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: renk.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(darEkran ? 14 : 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: darEkran ? 120 : 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: darEkran ? 48 : 54,
                        height: darEkran ? 48 : 54,
                        decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(emoji, style: TextStyle(fontSize: darEkran ? 26 : 30)),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded, 
                        size: 16, color: renk.withValues(alpha: 0.5)),
                    ],
                  ),
                  SizedBox(height: darEkran ? 12 : 16),
                  Text(
                    baslik,
                    style: TextStyle(
                      fontSize: darEkran ? 14.5 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aciklama,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      height: 1.3,
                      fontSize: darEkran ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _istatistikKarti({
    required IconData ikon,
    required String baslik,
    required String deger,
    required Color renk,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A1F) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(ikon, color: renk, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              deger,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              baslik,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(fieldsProvider);
    final darEkran = MediaQuery.sizeOf(context).width < 600;
    final currentLang = ref.watch(languageProvider);
    final l10n = ref.read(languageProvider.notifier);
    String t(String key) => l10n.translate(key);
    
    return fieldsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hata olustu: $error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: tarlalariYukle, child: const Text('Tekrar Dene')),
            ],
          ),
        ),
      ),
      data: (tarlalar) {
        final sulamaBekleyenler = tarlalar.where(sulamaHatirlatmasiVar).toList();
        final filtreliTarlalar = getGorunenTarlalar(tarlalar);
        
        // Hatirlatma kontrolunu build sonrasi yap
        WidgetsBinding.instance.addPostFrameCallback((_) {
          aylikPdfHatirlatmasiniKontrolEt(tarlalar);
          _istatistikleriHesapla(tarlalar);
        });

    return TasarimArkaPlani(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        title: Row(
          children: [
            // Mini logo - uygulama simgesiyle aynı
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1D3B14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/icons/app_icon_foreground.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.agriculture_rounded,
                    size: 18,
                    color: Color(0xFF1B5E35),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Tarım',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF1B4332),
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextSpan(
                        text: '360',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFA8E6BB)
                              : const Color(0xFF2D7A4F),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.bulutEtkin ? const Color(0xFF4CAF50) : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.bulutEtkin ? t('cloud_sync_on') : t('local_mode'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: altMenuIndex,
        onDestinationSelected: (index) => altMenuTiklandi(index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: currentLang == 'en' ? 'Home' : 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: const Icon(Icons.picture_as_pdf),
            label: currentLang == 'en' ? 'Report' : 'Rapor',
          ),
          const NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: currentLang == 'en' ? 'Finance' : 'Finans',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: currentLang == 'en' ? 'Settings' : 'Ayarlar',
          ),
        ],
      ),
      body: IndexedStack(
              index: altMenuIndex,
              children: [
                AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: tarlalar.isEmpty
                  ? Padding(
                      key: const ValueKey('bos'),
                        padding: EdgeInsets.all(darEkran ? 18 : 24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              Card(
                                child: Padding(
                                  padding: EdgeInsets.all(darEkran ? 22 : 28),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Tarım360\'a Hoş Geldin!',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'İlk tarlanı ekleyerek sulama takibi, hava durumu, uydu görüntüsü ve işlem kaydı gibi tüm özellikleri kullanmaya başla.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: tarlaEkleSayfasiniAc,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF2D7A4F),
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          icon: const Icon(Icons.add_circle_outline, size: 22),
                                          label: const Text(
                                            'Tarla Ekle',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Feature highlights
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          _OzellikRozeti(ikon: Icons.water_drop_outlined, metin: 'Sulama'),
                                          _OzellikRozeti(ikon: Icons.satellite_alt_outlined, metin: 'Uydu'),
                                          _OzellikRozeti(ikon: Icons.analytics_outlined, metin: 'Rapor'),
                                          _OzellikRozeti(ikon: Icons.smart_toy_outlined, metin: 'AI'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    )
                  : RefreshIndicator(
                      key: const ValueKey('liste'),
                      onRefresh: tarlalariYukle,
                      child: ListView(
                        padding: darEkran
                            ? const EdgeInsets.fromLTRB(12, 12, 12, 28)
                            : const EdgeInsets.fromLTRB(16, 14, 16, 36),
                        children: [
                          ListeOzetBandi(
                            toplamTarla: tarlalar.length,
                            sulamaBekleyen: sulamaBekleyenler.length,
                            bulutEtkin: widget.bulutEtkin,
                            hatirlatmalar: sulamaBekleyenler
                                .take(3)
                                .map(sulamaHatirlatmaMetni)
                                .toList(),
                            havaDurumu: _havaDurumu,
                            havaYukleniyor: _havaYukleniyor,
                            onHavaYenile: _havaDurumuYukle,
                          ),
                          SizedBox(height: darEkran ? 12 : 18),
                          _bolumBasligi(
                            baslik: t('quick_actions'),
                            aciklama: currentLang == 'en'
                                ? 'Access your most used operations in one tap.'
                                : 'En sık kullanılan işlemleri tek dokunuşla aç.',
                          ),
                          SizedBox(height: darEkran ? 8 : 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final tekKolon = constraints.maxWidth < 760;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: tekKolon
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth - 12) / 2,
                                    child: _anaKisayolKarti(
                                      ikon: Icons.add_circle_outline,
                                      renk: const Color(0xFF3D8C40),
                                      baslik: t('add_field'),
                                      aciklama: t('add_field_desc'),
                                      onTap: tarlaEkleSayfasiniAc,
                                    ),
                                  ),
                                  SizedBox(
                                    width: tekKolon
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth - 12) / 2,
                                    child: _anaKisayolKarti(
                                      ikon: Icons.dashboard_customize_outlined,
                                      renk: const Color(0xFF4D7FC6),
                                      baslik: t('field_summary'),
                                      aciklama: t('field_summary_desc'),
                                      onTap: () async {
                                        await Navigator.push<void>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TarlaOzetSayfasi(
                                              baslangicTarlalari: tarlalar,
                                              aileKodu: widget.aileKodu,
                                            ),
                                          ),
                                        );
                                        await tarlalariYukle();
                                      },
                                    ),
                                  ),
                                   SizedBox(
                                     width: tekKolon
                                         ? constraints.maxWidth
                                         : (constraints.maxWidth - 12) / 2,
                                     child: _anaKisayolKarti(
                                       ikon: Icons.account_balance_wallet_outlined,
                                       renk: const Color(0xFF4D7FC6),
                                       baslik: t('finance_status'),
                                       aciklama: t('finance_status_desc'),
                                       onTap: () async {
                                         await Navigator.push<void>(context, MaterialPageRoute(builder: (c) => const FinancialDashboardScreen()));
                                       },
                                     ),
                                   ),
                                  SizedBox(
                                    width: tekKolon
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth - 12) / 2,
                                    child: _anaKisayolKarti(
                                      ikon: Icons.restore_from_trash_outlined,
                                      renk: const Color(0xFF6A4BBC),
                                      baslik: t('archive'),
                                      aciklama: t('archive_desc'),
                                      onTap: silinenTarlalariAc,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: darEkran ? 12 : 18),
                          if (!widget.bulutEtkin && widget.yerelModBilgisi != null) ...[
                            _uyariKarti(
                              vurgu: Colors.orange,
                              ikon: Icons.cloud_off,
                              baslik: t('local_mode'),
                              icerik: Text(widget.yerelModBilgisi!),
                            ),
                            SizedBox(height: darEkran ? 10 : 14),
                          ],
                          SizedBox(height: darEkran ? 12 : 18),
                          _bolumBasligi(
                            baslik: 'Tarlalarım',
                            aciklama:
                                'En guncel durumu buradan takip et. Kartlara dokunarak detay ekranina gec.',
                            eylem: widget.bulutEtkin
                                ? FilledButton.tonalIcon(
                                    onPressed: senkronizeEt,
                                    icon: const Icon(Icons.sync),
                                    label: const Text('Senkronize et'),
                                  )
                                : null,
                          ),
                          SizedBox(height: darEkran ? 8 : 12),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.surfaceContainer
                                  : Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: const Color(0xFF476F3A).withValues(alpha: 0.10),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(darEkran ? 12 : 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final darEkran = constraints.maxWidth < 760;
                                      return Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          SizedBox(
                                            width: darEkran
                                                ? constraints.maxWidth
                                                : constraints.maxWidth * 0.58,
                                            child: TextField(
                                              controller: aramaController,
                                              onChanged: (value) {
                                                setState(() {
                                                  aramaMetni = value;
                                                });
                                              },
                                              decoration: const InputDecoration(
                                                hintText: 'Tarla ara',
                                                prefixIcon: Icon(Icons.search),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: darEkran
                                                ? constraints.maxWidth
                                                : constraints.maxWidth * 0.32,
                                            child: DropdownButtonFormField<String>(
                                              initialValue: seciliSiralama,
                                              decoration: const InputDecoration(
                                                labelText: 'Sıralama',
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'Son guncellenen',
                                                  child: Text('Son guncellenen'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Ada gore (A-Z)',
                                                  child: Text('Ada gore (A-Z)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Ada gore (Z-A)',
                                                  child: Text('Ada gore (Z-A)'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'En kritik sulama',
                                                  child: Text('En kritik sulama'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Son isleme gore',
                                                  child: Text('Son isleme gore'),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                if (value == null) return;
                                                setState(() {
                                                  seciliSiralama = value;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      GirisBilgiRozeti(
                                        ikon: Icons.agriculture_outlined,
                                        metin: '${tarlalar.length} tarla',
                                      ),
                                      GirisBilgiRozeti(
                                        ikon: Icons.warning_amber_rounded,
                                        metin:
                                            '${sulamaBekleyenler.length} sulama bekleyen',
                                      ),
                                      if (aramaMetni.trim().isNotEmpty)
                                        GirisBilgiRozeti(
                                          ikon: Icons.filter_alt_outlined,
                                          metin: '${filtreliTarlalar.length} sonuc',
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: darEkran ? 10 : 14),
                                  if (filtreliTarlalar.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: darEkran ? 18 : 24),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Text(
                                              'Aramana uygun tarla bulunamadi.',
                                              style: TextStyle(color: Colors.grey.shade700),
                                            ),
                                            const SizedBox(height: 10),
                                            OutlinedButton.icon(
                                              onPressed: filtreleriTemizle,
                                              icon: const Icon(Icons.filter_alt_off_outlined),
                                              label: const Text('Aramayi temizle'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  for (var i = 0; i < filtreliTarlalar.length; i++) ...[
                                    tarlaKarti(filtreliTarlalar[i]),
                                    if (i != filtreliTarlalar.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    
                // Toplam Alan Hesaplama
                    double toplamMetrekare = tarlalar.fold(0.0, (sum, t) => sum + (t.alanMetrekare ?? 0.0));
                    String toplamAlanMetni = formatAlanOzeti(alanMetrekare: toplamMetrekare);

                    // Ürün Dağılımı
                    final urunGruplari = <String, double>{};
                    for (final t in tarlalar) {
                      final urun = t.urun.trim().isEmpty ? (currentLang == 'en' ? 'Unspecified' : 'Belirtilmemiş') : t.urun.trim();
                      urunGruplari[urun] = (urunGruplari[urun] ?? 0.0) + (t.alanMetrekare ?? 0.0);
                    }
                    final siraliUrunler = urunGruplari.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                    // Benzersiz Ürün Sayısı
                    final benzersizUrunSayisi = urunGruplari.keys.where((k) => k != 'Belirtilmemiş' && k != 'Unspecified').length;


                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                          children: [
                            // ─── İSTATİSTİKLER PANELİ ──────────────────────────────
                            _bolumBasligi(
                              baslik: currentLang == 'en' ? 'Farm Analytics' : 'Çiftlik İstatistikleri',
                              aciklama: currentLang == 'en'
                                  ? 'Real-time overview and health statistics of your farm.'
                                  : 'Çiftliğinizin gerçek zamanlı verileri ve sağlık özeti.',
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.45,
                              children: [
                                _istatistikKarti(
                                  ikon: Icons.landscape_rounded,
                                  baslik: currentLang == 'en' ? 'Total Fields' : 'Toplam Tarla',
                                  deger: '${tarlalar.length} ${currentLang == 'en' ? 'fields' : 'adet'}',
                                  renk: const Color(0xFF2D6A4F),
                                  isDark: isDark,
                                ),
                                _istatistikKarti(
                                  ikon: Icons.straighten_rounded,
                                  baslik: currentLang == 'en' ? 'Total Area' : 'Toplam Alan',
                                  deger: toplamAlanMetni,
                                  renk: Colors.blue.shade700,
                                  isDark: isDark,
                                ),
                                _istatistikKarti(
                                  ikon: Icons.water_drop_rounded,
                                  baslik: currentLang == 'en' ? 'Irrigation Need' : 'Sulama Bekleyen',
                                  deger: '${sulamaBekleyenler.length} ${currentLang == 'en' ? 'fields' : 'tarla'}',
                                  renk: Colors.orange.shade700,
                                  isDark: isDark,
                                ),
                                _istatistikKarti(
                                  ikon: Icons.agriculture_rounded,
                                  baslik: currentLang == 'en' ? 'Crop Variety' : 'Ürün Çeşidi',
                                  deger: '$benzersizUrunSayisi ${currentLang == 'en' ? 'varieties' : 'cesit'}',
                                  renk: Colors.amber.shade700,
                                  isDark: isDark,
                                ),
                                _istatistikKarti(
                                  ikon: Icons.assignment_rounded,
                                  baslik: currentLang == 'en' ? 'Total Operations' : 'Toplam İşlem',
                                  deger: '$_toplamIslemSayisi ${currentLang == 'en' ? 'ops' : 'islem'}',
                                  renk: Colors.purple.shade600,
                                  isDark: isDark,
                                ),
                                _istatistikKarti(
                                  ikon: Icons.account_balance_wallet_rounded,
                                  baslik: currentLang == 'en' ? 'Total Cost' : 'Toplam Maliyet',
                                  deger: NumberFormat.currency(locale: 'tr_TR', symbol: 'TL ').format(_toplamMaliyetTL),
                                  renk: Colors.teal.shade600,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            
                            // ─── ÜRÜN ALAN DAĞILIMI ──────────────────────────────────
                            if (tarlalar.isNotEmpty) ...[
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                ),
                                color: isDark ? const Color(0xFF162A1F) : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentLang == 'en' ? 'Crop Distribution (Area)' : 'Ürün Alan Dağılımı',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 14),
                                      for (final entry in siraliUrunler) ...[
                                        Builder(builder: (context) {
                                          final pct = toplamMetrekare > 0 ? (entry.value / toplamMetrekare) : 0.0;
                                          final dekarDeger = entry.value / 1000.0;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      entry.key,
                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                    ),
                                                    Text(
                                                      '${dekarDeger.toStringAsFixed(1)} dekar (${(pct * 100).toStringAsFixed(0)}%)',
                                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: LinearProgressIndicator(
                                                    value: pct,
                                                    minHeight: 8,
                                                    color: const Color(0xFF2D6A4F),
                                                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                                // ─── RAPORLAR BÖLÜM BAŞLIĞI ─────────────────────────────
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                currentLang == 'en' ? 'Export Reports' : 'PDF Raporları',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                            // ─── TARLA ANALİZ RAPORU KARTI ─────────────────────────
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              ),
                              color: isDark ? const Color(0xFF162A1F) : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFCC8C2E).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                            color: Color(0xFFCC8C2E),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            currentLang == 'en' ? 'Field Analysis Report' : 'Tarla Analiz Raporu',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      currentLang == 'en'
                                          ? 'Detailed PDF of all fields — operations, irrigation, notes and season summary.'
                                          : 'Tüm tarlaların işlem geçmişini, sulama özetini ve sezon verilerini içeren kapsamlı PDF raporu.',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(46),
                                        backgroundColor: const Color(0xFFCC8C2E),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => pdfRaporuIndir(onayla: false),
                                      icon: const Icon(Icons.picture_as_pdf_rounded),
                                      label: Text(currentLang == 'en' ? 'Open Field Report (PDF)' : 'Analiz Raporunu Ac (PDF)'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ─── FİNANS RAPORU KARTI ──────────────────────────────────
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              ),
                              color: isDark ? const Color(0xFF162A1F) : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.account_balance_wallet_outlined,
                                            color: Color(0xFF1565C0),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            currentLang == 'en' ? 'Finance Report' : 'Finans Raporu',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      currentLang == 'en'
                                          ? 'View income, expense and net profit analysis. Download detailed financial PDF per field.'
                                          : 'Gelir, gider ve net kâr analizini görüntüleyin. Tarla bazlı ayrıntılı finans PDF raporu indirin.',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(46),
                                        backgroundColor: const Color(0xFF1565C0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => finansRaporuIndir(),
                                       icon: const Icon(Icons.picture_as_pdf_rounded),
                                       label: Text(currentLang == 'en' ? 'Open Finance Report (PDF)' : 'Finans Raporunu Ac (PDF)'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ─── RAPOR VE ARŞİV AYARLARI KARTI ────────────────────────
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              ),
                              color: isDark ? const Color(0xFF162A1F) : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF476F3A).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.tune_rounded,
                                            color: Color(0xFF476F3A),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          currentLang == 'en' ? 'Report & Archive Settings' : 'Rapor ve Arşiv Ayarları',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    
                                    // Switch for PDF Reminder
                                    SwitchListTile(
                                      title: Text(currentLang == 'en' ? 'PDF Download Reminder' : 'PDF Raporu Hatırlatıcısı'),
                                      subtitle: Text(
                                        currentLang == 'en'
                                            ? 'Reminds you to download a status report periodically.'
                                            : 'Düzenli aralıklarla çiftlik raporunu indirmeyi hatırlatır.',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      value: pdfReminderEnabled,
                                      activeThumbColor: const Color(0xFF2D6A4F),
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (val) async {
                                        await AppSessionService.pdfHatirlatmaEtkinKaydet(val);
                                        setState(() {
                                          pdfReminderEnabled = val;
                                        });
                                      },
                                    ),
                                    
                                    if (pdfReminderEnabled) ...[
                                      const SizedBox(height: 10),
                                      DropdownButtonFormField<int>(
                                        // ignore: deprecated_member_use
                                        value: pdfReminderIntervalDays,
                                        decoration: InputDecoration(
                                          labelText: currentLang == 'en' ? 'Reminder Frequency' : 'Hatırlatma Sıklığı',
                                          prefixIcon: const Icon(Icons.notifications_active_outlined),
                                        ),
                                        items: [
                                          DropdownMenuItem(value: 7, child: Text(currentLang == 'en' ? 'Weekly (7 Days)' : 'Haftalık (7 Gün)')),
                                          DropdownMenuItem(value: 14, child: Text(currentLang == 'en' ? 'Every 2 Weeks (14 Days)' : '2 Haftada Bir (14 Gün)')),
                                          DropdownMenuItem(value: 30, child: Text(currentLang == 'en' ? 'Monthly (30 Days)' : 'Aylık (30 Gün)')),
                                        ],
                                        onChanged: (val) async {
                                          if (val != null) {
                                            await AppSessionService.pdfHatirlatmaSikligiKaydet(val);
                                            setState(() {
                                              pdfReminderIntervalDays = val;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<int>(
                                      // ignore: deprecated_member_use
                                      value: archiveRetentionDays,
                                      decoration: InputDecoration(
                                        labelText: currentLang == 'en' ? 'Archive Retention Time' : 'Arşiv Saklama Süresi',
                                        prefixIcon: const Icon(Icons.auto_delete_outlined),
                                      ),
                                      items: [
                                        DropdownMenuItem(value: 15, child: Text(currentLang == 'en' ? '15 Days' : '15 Gün')),
                                        DropdownMenuItem(value: 30, child: Text(currentLang == 'en' ? '30 Days (Default)' : '30 Gün (Varsayılan)')),
                                        DropdownMenuItem(value: 90, child: Text(currentLang == 'en' ? '90 Days (3 Months)' : '90 Gün (3 Ay)')),
                                        DropdownMenuItem(value: 180, child: Text(currentLang == 'en' ? '180 Days (6 Months)' : '180 Gün (6 Ay)')),
                                      ],
                                      onChanged: (val) async {
                                        if (val != null) {
                                          await AppSessionService.arsivSaklamaSuresiKaydet(val);
                                          setState(() {
                                            archiveRetentionDays = val;
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentLang == 'en'
                                          ? 'Archived fields will be permanently deleted after this duration.'
                                          : 'Arşive gönderdiğiniz tarlalar bu süre sonunda kalıcı olarak temizlenir.',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                ),
                const AiDanismanSayfasi(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Ayarlar',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ekip kodu, senkronizasyon, QR paylasimi ve arsiv ayarlarini yonet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: ayarlariAc,
                            icon: const Icon(Icons.settings),
                            label: const Text('Ayarlari ac'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_konfetiGoster)
            Positioned.fill(
              child: KonfetiKutlamasi(
                onAnimasyonBitti: () {
                  setState(() {
                    _konfetiGoster = false;
                  });
                },
              ),
            ),
          // ── ÇEVRİMDIŞI BANNER ─────────────────────────────────
          if (!_cevrimici)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: Colors.red.shade700,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 4,
                    bottom: 6,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Çevrimdışı — bağlantı sağlanınca otomatik sync yapılacak',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
      },
    );
  }
}

class _OzellikRozeti extends StatelessWidget {
  const _OzellikRozeti({required this.ikon, required this.metin});
  final IconData ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2D7A4F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(0xFF2D7A4F).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: const Color(0xFF2D7A4F)),
          const SizedBox(width: 5),
          Text(
            metin,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D7A4F),
            ),
          ),
        ],
      ),
    );
  }
}
