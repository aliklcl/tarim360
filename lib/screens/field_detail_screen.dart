import '../widgets/chart_widgets.dart';
import '../widgets/badges_and_cards.dart';
import '../widgets/tasarim_arka_plani.dart';
import '../widgets/konfeti_kutlamasi.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_session_service.dart';
import '../cloud_sync_service.dart';
import '../database_helper.dart';
import '../utils/app_logger.dart';
import '../islem_model.dart';
import '../islem_turu_model.dart';
import '../sinir_noktasi_model.dart';
import '../tarla_model.dart';
import '../weather_service.dart';
import '../utils/app_helpers.dart';
import 'add_field_screen.dart';
import 'field_extra_info_screen.dart';
import 'satellite_map_screen.dart';
import 'settings_screen.dart';
import 'financial_dashboard_screen.dart';
// Fallback for globals

class TarlaDetaySayfasi extends StatefulWidget {
  const TarlaDetaySayfasi({
    super.key,
    required this.tarla,
    required this.aileKodu,
    required this.bulutEtkin,
    required this.kullaniciAdi,
    required this.aileSahibiMi,
  });

  final Tarla tarla;
  final String aileKodu;
  final bool bulutEtkin;
  final String kullaniciAdi;
  final bool aileSahibiMi;

  @override
  State<TarlaDetaySayfasi> createState() => _TarlaDetaySayfasiState();
}

class _TarlaDetaySayfasiState extends State<TarlaDetaySayfasi> {
  List<Islem> gecmis = [];
  List<SinirNoktasi> sinirNoktalari = [];
  List<IslemTuruTanim> ozelIslemTurleri = [];
  bool yukleniyor = true;
  bool havaYukleniyor = false;
  bool islemTurleriYukleniyor = false;
  bool _konfetiGoster = false;
  TarlaHavaDurumu? havaDurumu;
  String? havaHatasi;
  String seciliIslemFiltresi = 'Tum';
  String seciliKullaniciFiltresi = 'Tum kullanicilar';
  String seciliGecmisGorunumu = 'Liste';
  DateTime seciliTakvimTarihi = DateTime(
    turkiyeSimdi().year,
    turkiyeSimdi().month,
    turkiyeSimdi().day,
  );
  DateTime gosterilenTakvimAyi = DateTime(
    turkiyeSimdi().year,
    turkiyeSimdi().month,
  );

  @override
  void initState() {
    super.initState();
    verileriYukle();
    islemTurleriniYukle();
    havaDurumuYukle();
  }

  Future<void> islemTurleriniYukle() async {
    setState(() {
      islemTurleriYukleniyor = true;
    });
    try {
      final tipler = widget.bulutEtkin
          ? await CloudSyncService.instance.ozelIslemTurleriniGetir(widget.aileKodu)
          : await AppSessionService.ozelIslemTurleriniGetir(widget.aileKodu);
      if (!mounted) return;
      final tumTipler = tumIslemTurleriniBirlestir(tipler);
      setState(() {
        ozelIslemTurleri = tipler;
        if (seciliIslemFiltresi != 'Tum' &&
            !tumTipler.any((tanim) => tanim.ad == seciliIslemFiltresi)) {
          seciliIslemFiltresi = 'Tum';
        }
      });
    } catch (e, st) {
      AppLogger.w('İşlem türleri yüklenemedi', e, st);
    } finally {
      if (mounted) {
        setState(() {
          islemTurleriYukleniyor = false;
        });
      }
    }
  }

  Future<void> verileriYukle() async {
    if (widget.tarla.id == null) {
      setState(() {
        gecmis = [];
        sinirNoktalari = [];
        yukleniyor = false;
      });
      return;
    }

    final tarlaId = widget.tarla.id!;
    final islemVerileri = await DatabaseHelper.instance.tarlaIslemleri(tarlaId);
    islemVerileri.sort((a, b) {
      final dateA = islemTarihiGetir(a);
      final dateB = islemTarihiGetir(b);
      return dateB.compareTo(dateA); // En yeni üstte, en eski altta
    });
    final sinirVerileri = await DatabaseHelper.instance.tarlaSinirNoktalari(tarlaId);
    
    // verileriYukle icinde islem turlerini sadece local cache'den al.
    // islemTurleriniYukle() cloud'dan cekip gunceller; buradan tekrar cekersek
    // yeni eklenen tipler cloud yazilmadan once override edilebilir.
    List<IslemTuruTanim> tipler = ozelIslemTurleri.isNotEmpty
        ? ozelIslemTurleri
        : await AppSessionService.ozelIslemTurleriniGetir(widget.aileKodu);
    final tumTipler = tumIslemTurleriniBirlestir(tipler);

    if (sinirVerileri.length >= 3) {
      final alanMetrekare = parselAlaniMetrekare(sinirVerileri);
      widget.tarla
        ..alanMetrekare = alanMetrekare
        ..alanDekar = null
        ..alan = formatAlanOzeti(
          alanMetrekare: alanMetrekare,
        );
    }

    if (!mounted) return;
    setState(() {
      ozelIslemTurleri = tipler;
      if (seciliIslemFiltresi != 'Tum' &&
          !tumTipler.any((tanim) => tanim.ad == seciliIslemFiltresi)) {
        seciliIslemFiltresi = 'Tum';
      }
      gecmis = islemVerileri;
      sinirNoktalari = sinirVerileri;
      _tarlayaSonIslemTarihleriniUygula(islemVerileri);
      if (islemVerileri.isNotEmpty) {
        final sonKayitTarihi = tarihAnahtari(islemTarihiGetir(islemVerileri.first));
        seciliTakvimTarihi = sonKayitTarihi;
        gosterilenTakvimAyi = DateTime(sonKayitTarihi.year, sonKayitTarihi.month);
      }
      yukleniyor = false;
    });
  }

  Future<void> tarlaBilgileriniDuzenle() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => TarlaEkleSayfasi(
          mevcutTarla: widget.tarla,
          onTarlaKaydet: (tarla, sinirNoktalari) async {
            widget.tarla
              ..ad = tarla.ad
              ..urun = tarla.urun
              ..alan = tarla.alan
              ..alanMetrekare = tarla.alanMetrekare
              ..alanDekar = tarla.alanDekar
              ..enlem = tarla.enlem
              ..boylam = tarla.boylam
              ..notlar = tarla.notlar
              ..fotoBase64 = tarla.fotoBase64;

            if (widget.bulutEtkin) {
              await CloudSyncService.instance.tarlaGuncelle(
                widget.aileKodu,
                widget.tarla,
              );
            } else {
              await DatabaseHelper.instance.tarlaGuncelle(widget.tarla);
              await guvenlikYedegiAl('tarla_bilgileri_duzenlendi');
            }
            if (sinirNoktalari.isNotEmpty && widget.tarla.id != null) {
              final duzenlenmis = sinirNoktalari
                  .map(
                    (nokta) => SinirNoktasi(
                      tarlaId: widget.tarla.id!,
                      enlem: nokta.enlem,
                      boylam: nokta.boylam,
                    ),
                  )
                  .toList(growable: false);
              if (widget.bulutEtkin) {
                await CloudSyncService.instance.sinirNoktalariGuncelle(
                  widget.aileKodu,
                  widget.tarla,
                  duzenlenmis,
                );
              } else {
                await DatabaseHelper.instance.tarlaSinirNoktalariYenile(
                  widget.tarla.id!,
                  duzenlenmis,
                );
              }
            }
          },
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
    await verileriYukle();
    await havaDurumuYukle();
  }

  Future<void> ekBilgileriDuzenle() async {
    final sonuc = await Navigator.push<TarlaEkBilgiSonucu>(
      context,
      MaterialPageRoute(
        builder: (context) => TarlaEkBilgiSayfasi(
          baslangicNot: widget.tarla.notlar,
          baslangicFotolar: fotoListesiCoz(widget.tarla.fotoBase64),
        ),
      ),
    );

    if (sonuc == null) return;

    widget.tarla
      ..notlar = sonuc.notlar
      ..fotoBase64 = fotoListesiniKaydet(sonuc.fotolar);

    if (widget.bulutEtkin) {
      await CloudSyncService.instance.tarlaGuncelle(widget.aileKodu, widget.tarla);
    } else {
      await DatabaseHelper.instance.tarlaGuncelle(widget.tarla);
      await guvenlikYedegiAl('tarla_ek_bilgileri_duzenlendi');
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> havaDurumuYukle() async {
    final enlem = widget.tarla.enlem;
    final boylam = widget.tarla.boylam;

    if (enlem == null || boylam == null) {
      if (!mounted) return;
      setState(() {
        havaDurumu = null;
        havaHatasi = 'Hava durumu icin once tarla konumu gerekli';
        havaYukleniyor = false;
      });
      return;
    }

    setState(() {
      havaYukleniyor = true;
      havaHatasi = null;
    });

    try {
      final sonuc = await WeatherService.havaDurumuGetir(
        enlem: enlem,
        boylam: boylam,
      );

      if (!mounted) return;
      setState(() {
        havaDurumu = sonuc;
        havaYukleniyor = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        havaHatasi = 'Hava durumu alinamadi';
        havaYukleniyor = false;
      });
    }
  }

  Future<void> yeniIslemEkle(String tur) async {
    final sonuc = await _islemFormunuAc(baslangicTuru: tur);
    if (sonuc == null) return;

    final isCritical = (sonuc.tur == 'Sulama' || sonuc.tur == 'Gubre' || sonuc.tur == 'Ilac');
    final isFirstOfSeason = isCritical && !gecmis.any((item) {
      try {
        final itemDate = islemTarihiGetir(item);
        return item.tur == sonuc.tur && itemDate.year == DateTime.now().year;
      } catch (_) {
        return false;
      }
    });

    await _islemKaydetVeyaGuncelle(
      tur: sonuc.tur,
      detay: sonuc.detay,
      baslangic: sonuc.baslangic,
      fotolar: sonuc.fotolar,
      maliyet: sonuc.maliyet,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${sonuc.tur} kaydi eklendi')),
    );

    if (isFirstOfSeason) {
      setState(() {
        _konfetiGoster = true;
      });
    }
  }

  Future<void> gecmisKaydiniDuzenle(Islem kayit) async {
    final sonuc = await _islemFormunuAc(
      baslangicTuru: kayit.tur,
      mevcutKayit: kayit,
    );
    if (sonuc == null) return;

    await _islemKaydetVeyaGuncelle(
      mevcutKayit: kayit,
      tur: sonuc.tur,
      detay: sonuc.detay,
      baslangic: sonuc.baslangic,
      fotolar: sonuc.fotolar,
      maliyet: sonuc.maliyet,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('İşlem kaydı güncellendi')),
    );
  }

  Future<void> gecmisKaydiniSil(Islem kayit) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: Text('${kayit.tur} kaydı silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (onay != true) return;

    final tarlaId = widget.tarla.id;
    final islemId = kayit.id;
    if (tarlaId == null || islemId == null) return;

    if (widget.bulutEtkin) {
      await CloudSyncService.instance.islemSil(
        widget.aileKodu,
        widget.tarla,
        islemId,
      );
    } else {
      await DatabaseHelper.instance.islemSil(islemId);
      await DatabaseHelper.instance.tarlaSonIslemTarihleriniYenidenHesapla(tarlaId);
      final guncelKayitlar = await DatabaseHelper.instance.tarlaIslemleri(tarlaId);
      _tarlayaSonIslemTarihleriniUygula(guncelKayitlar);
      await guvenlikYedegiAl('islem_silindi');
    }

    await verileriYukle();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('İşlem kaydı silindi')),
    );
  }

  Future<void> _islemKaydetVeyaGuncelle({
    Islem? mevcutKayit,
    required String tur,
    required String detay,
    required DateTime baslangic,
    required List<String> fotolar,
    double? maliyet,
  }) async {
    final tarlaId = widget.tarla.id;
    if (tarlaId == null) return;

    final islem = Islem(
      id: mevcutKayit?.id,
      tarlaId: tarlaId,
      tur: tur,
      detay: detay.trim(),
      baslangicZamani: baslangic.toIso8601String(),
      tarih: formatTarihSaat(baslangic),
      kullaniciAdi: widget.kullaniciAdi,
      fotoBase64: fotoListesiniKaydet(fotolar),
      maliyet: maliyet,
    );

    if (widget.bulutEtkin) {
      if (mevcutKayit == null) {
        await CloudSyncService.instance.islemEkle(
          widget.aileKodu,
          widget.tarla,
          islem,
        );
      } else {
        await CloudSyncService.instance.islemGuncelle(
          widget.aileKodu,
          widget.tarla,
          islem,
        );
      }
    } else {
      if (mevcutKayit == null) {
        await DatabaseHelper.instance.islemEkle(islem);
      } else {
        await DatabaseHelper.instance.islemGuncelle(islem);
      }
      await DatabaseHelper.instance.tarlaSonIslemTarihleriniYenidenHesapla(tarlaId);
      final guncelKayitlar = await DatabaseHelper.instance.tarlaIslemleri(tarlaId);
      _tarlayaSonIslemTarihleriniUygula(guncelKayitlar);
      await DatabaseHelper.instance.tarlaGuncelle(widget.tarla);
      await guvenlikYedegiAl(
        mevcutKayit == null ? 'islem_eklendi' : 'islem_guncellendi',
      );
    }

    await verileriYukle();
  }

  Future<IslemFormSonucu?> _islemFormunuAc({
    required String baslangicTuru,
    Islem? mevcutKayit,
  }) async {
    final detayController = TextEditingController(text: mevcutKayit?.detay ?? '');
    final maliyetController = TextEditingController(text: mevcutKayit?.maliyet?.toString() ?? '');
    var seciliTur = mevcutKayit?.tur ?? baslangicTuru;
    var seciliTarih =
        parseKayitZamani(mevcutKayit?.baslangicZamani) ?? turkiyeSimdi();
    var fotolar = fotoListesiCoz(mevcutKayit?.fotoBase64 ?? '');
    final darEkran = MediaQuery.sizeOf(context).width < 600;
    final formIslemTurleri = [
      ...tumIslemTurleri,
      if (!tumIslemTurleri.any((tanim) => tanim.ad == seciliTur))
        islemTuruTanimGetir(seciliTur),
    ];
    final hazirSulamaSureleri = ['3 saat', '5 saat', '6 saat', '30 saat'];

    final sonuc = await showDialog<IslemFormSonucu>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: darEkran ? 12 : 40,
            vertical: darEkran ? 16 : 24,
          ),
          title: Text(mevcutKayit == null ? 'Islem ekle' : 'Islemi duzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İşlem tipi, detay, tarih ve varsa fotoğrafları tek ekranda düzeleyebilirsin.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: seciliTur,
                  decoration: const InputDecoration(labelText: 'İşlem tipi'),
                  items: formIslemTurleri
                      .map(
                        (tanim) => DropdownMenuItem(
                          value: tanim.ad,
                          child: Row(
                            children: [
                              Icon(
                                islemTuruIkonunuGetir(tanim.iconKey),
                                size: 18,
                                color: islemTuruRenginiGetir(tanim),
                              ),
                              const SizedBox(width: 8),
                              Text(tanim.ad),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      seciliTur = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detayController,
                  decoration: InputDecoration(
                    labelText: _islemDetayEtiketi(seciliTur),
                    hintText: _islemDetayOrnegi(seciliTur),
                  ),
                ),
                if (seciliTur == 'Sulama') ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sure in hazirSulamaSureleri)
                        ChoiceChip(
                          label: Text(sure),
                          selected: detayController.text.trim() == sure,
                          onSelected: (_) {
                            setDialogState(() {
                              detayController.text = sure;
                            });
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: maliyetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Maliyet (TL)',
                    hintText: 'Opsiyonel islem maliyeti',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final secilen = await _tarihSaatSec(seciliTarih);
                    if (secilen == null) return;
                    setDialogState(() {
                      seciliTarih = secilen;
                    });
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(formatTarihSaat(seciliTarih)),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İşlem fotoğrafları',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        if (fotolar.isEmpty)
                          Container(
                            height: 90,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white24
                                    : Colors.black12,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'Henüz fotoğraf eklenmedi',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white60
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: fotolar.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 8),
                              itemBuilder: (context, index) => Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(
                                      base64OnizlemeCoz(fotolar[index]),
                                      width: 108,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 108,
                                        height: 90,
                                        alignment: Alignment.center,
                                        color: Colors.grey.shade200,
                                        child: const Text('Açılamadı'),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Material(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(999),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(999),
                                        onTap: () {
                                          setDialogState(() {
                                            fotolar = List<String>.from(fotolar)
                                              ..removeAt(index);
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (kameraDestekleniyor)
                              FilledButton.tonalIcon(
                                onPressed: () async {
                                  try {
                                    final yeniFoto = await kameradanFotografCek(
                                      context: context,
                                    );
                                    if (yeniFoto == null || yeniFoto.isEmpty) return;
                                    setDialogState(() {
                                      fotolar = [...fotolar, yeniFoto];
                                    });
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Fotograf cekilemedi: $error'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: const Text('Foto çek'),
                              ),
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                final yeniFotolar = await galeridenFotografSec();
                                if (yeniFotolar.isEmpty) return;
                                setDialogState(() {
                                  fotolar = [...fotolar, ...yeniFotolar];
                                });
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(
                                fotolar.isEmpty ? 'Galeriden seç' : 'Daha fazla ekle',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final detay = detayController.text.trim();
                if (detay.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_islemDetayEtiketi(seciliTur)} bos olamaz'),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(
                  IslemFormSonucu(
                    tur: seciliTur,
                    detay: detay,
                    baslangic: seciliTarih,
                    fotolar: fotolar,
                    maliyet: double.tryParse(maliyetController.text.trim().replaceAll(',', '.')),
                  ),
                );
              },
              child: Text(mevcutKayit == null ? 'Kaydet' : 'Guncelle'),
            ),
          ],
        ),
      ),
    );

    detayController.dispose();
    maliyetController.dispose();
    return sonuc;
  }

  List<IslemTuruTanim> get tumIslemTurleri =>
      tumIslemTurleriniBirlestir(ozelIslemTurleri);

  IslemTuruTanim islemTuruTanimGetir(String tur) =>
      islemTuruTaniminiBul(tur, ozelIslemTurleri);

  Future<Position> _mevcutKonumuGetir() async {
    final serviceEnabled = await konumServisiKapaliysaAyarlaraYonlendir(
      context,
      baslik: 'Konum hizmeti kapalı',
      aciklama:
          'Tarla merkez konumunu güncellemek için konum hizmetini açman gerekiyor.',
    );
    if (!mounted) {
      throw Exception('Ekran kapandi');
    }
    if (!serviceEnabled) {
      throw Exception('Cihazda konum servisi kapali');
    }

    var permission = await Geolocator.checkPermission();
    if (!mounted) {
      throw Exception('Ekran kapandi');
    }
    if (permission == LocationPermission.denied) {
      final izinIstensin = await konumBilgilendirmesiniGoster(
        context,
        amac: 'tarla merkez konumunu guncellemek',
      );
      if (!izinIstensin) {
        throw Exception('Konum izni istegi iptal edildi');
      }
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          throw Exception('Ekran kapandi');
        }
        await kaliciReddedilenKonumIzniIcinAyarlaraYonlendir(context);
      }
      throw Exception('Konum izni verilmedi');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> konumuGuncelle() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final position = await _mevcutKonumuGetir();
      widget.tarla.enlem = position.latitude;
      widget.tarla.boylam = position.longitude;
      if (widget.bulutEtkin) {
        await CloudSyncService.instance.tarlaKonumunuGuncelle(
          widget.aileKodu,
          widget.tarla,
        );
      } else {
        await DatabaseHelper.instance.tarlaGuncelle(widget.tarla);
        await guvenlikYedegiAl('tarla_konumu_guncellendi');
      }
      await havaDurumuYukle();

      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(content: Text('Tarla merkez konumu güncellendi')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('GPS konumu alinamadi: $error'),
        ),
      );
    }
  }

  Future<void> haritadaAc() async {
    final enlem = widget.tarla.enlem;
    final boylam = widget.tarla.boylam;
    if (enlem == null || boylam == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarla merkez konumu boş')),
      );
      return;
    }

    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$enlem,$boylam');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> konumuPaylas() async {
    final enlem = widget.tarla.enlem;
    final boylam = widget.tarla.boylam;
    if (enlem == null || boylam == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylasmak icin once tarla konumu gerekli')),
      );
      return;
    }

    final link =
        'https://maps.google.com/?q=${enlem.toStringAsFixed(6)},${boylam.toStringAsFixed(6)}&t=h&z=18';
    final metin = '${widget.tarla.ad} tarlası konumu\n\n'
        '📌 Haritada görmek için tıklayın:\n'
        '$link\n\n'
        'Koordinat: ${enlem.toStringAsFixed(6)}, ${boylam.toStringAsFixed(6)}';

    await Share.share(
      metin,
      subject: '${widget.tarla.ad} uydu konumu',
    );
  }

  Future<void> uyduHaritasiniAc() async {
    final guncelNoktalar = await Navigator.push<List<SinirNoktasi>>(
      context,
      MaterialPageRoute(
        builder: (context) => TarlaUyduParselSayfasi(
          tarlaAdi: widget.tarla.ad,
          merkezEnlem: widget.tarla.enlem,
          merkezBoylam: widget.tarla.boylam,
          baslangicNoktalari: sinirNoktalari,
        ),
      ),
    );

    if (guncelNoktalar == null) return;
    await sinirNoktalariKaydet(guncelNoktalar);
  }

  Future<void> sinirNoktalariKaydet(List<SinirNoktasi> noktalar) async {
    final tarlaId = widget.tarla.id;
    if (tarlaId == null) return;

    final duzenlenmis = noktalar
        .map(
          (nokta) => SinirNoktasi(
            tarlaId: tarlaId,
            enlem: nokta.enlem,
            boylam: nokta.boylam,
          ),
        )
        .toList();

    final alanMetrekare = parselAlaniMetrekare(duzenlenmis);
    widget.tarla
      ..alanMetrekare = duzenlenmis.length >= 3 ? alanMetrekare : null
      ..alanDekar = null
      ..alan = duzenlenmis.length >= 3
          ? formatAlanOzeti(
              alanMetrekare: alanMetrekare,
            )
          : '';

    if (widget.bulutEtkin) {
      await CloudSyncService.instance.sinirNoktalariGuncelle(
        widget.aileKodu,
        widget.tarla,
        duzenlenmis,
      );
    } else {
      await DatabaseHelper.instance.tarlaSinirNoktalariYenile(
        tarlaId,
        duzenlenmis,
      );
      await DatabaseHelper.instance.tarlaGuncelle(widget.tarla);
      await guvenlikYedegiAl('sinir_noktalari_guncellendi');
    }

    await verileriYukle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          duzenlenmis.length >= 3
              ? 'Alan kaydedildi: ${formatAlanOzeti(alanMetrekare: alanMetrekare)}'
              : 'Parsel sınırı güncellendi (${duzenlenmis.length} nokta)',
        ),
      ),
    );
  }

  String konumMetni() {
    final enlem = widget.tarla.enlem;
    final boylam = widget.tarla.boylam;
    if (enlem == null || boylam == null) return 'Konum eklenmedi';
    return '${enlem.toStringAsFixed(6)}, ${boylam.toStringAsFixed(6)}';
  }

  String _islemDetayEtiketi(String tur) {
    switch (tur) {
      case 'Sulama':
        return 'Sulama süresi';
      case 'Gubre':
        return 'Gübre markası veya not';
      case 'Ilac':
        return 'Ilac markasi veya not';
      default:
        return '$tur notu veya aciklamasi';
    }
  }

  String _islemDetayOrnegi(String tur) {
    switch (tur) {
      case 'Sulama':
        return 'Ornek: 6 saat';
      case 'Gubre':
        return 'Ornek: 20-20 kompoze';
      case 'Ilac':
        return 'Ornek: yabanci ot ilaci';
      default:
        return 'Ornek: yapilan isleme dair kisa not';
    }
  }

  Future<DateTime?> _tarihSaatSec(DateTime ilkDeger) async {
    final tarih = await showDatePicker(
      context: context,
      initialDate: ilkDeger,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (tarih == null || !mounted) return null;

    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ilkDeger),
    );
    if (saat == null) return null;

    return DateTime(
      tarih.year,
      tarih.month,
      tarih.day,
      saat.hour,
      saat.minute,
    );
  }

  String gecmisAltMetin(Islem kayit) {
    final baslangic = parseKayitZamani(kayit.baslangicZamani);
    final tarihMetni = baslangic != null ? formatTarihSaat(baslangic) : kayit.tarih;
    final fotoMetni = fotoListesiCoz(kayit.fotoBase64).isEmpty
        ? null
        : 'Foto: ${fotoListesiCoz(kayit.fotoBase64).length}';
    if (kayit.tur == 'Sulama') {
      final satirlar = <String>[];
      if (kayit.detay.isEmpty) {
        satirlar.add('Başlangıç: $tarihMetni');
      } else {
        satirlar
          ..add('Süre: ${kayit.detay}')
          ..add('Başlangıç: $tarihMetni');
      }
      if (fotoMetni != null) {
        satirlar.add(fotoMetni);
      }
      return satirlar.join('\n');
    }

    final satirlar = <String>[];
    if (kayit.detay.isEmpty) {
      satirlar.add('Baslangic: $tarihMetni');
    } else {
      satirlar
        ..add(kayit.detay)
        ..add('Baslangic: $tarihMetni');
    }
    if (fotoMetni != null) {
      satirlar.add(fotoMetni);
    }
    return satirlar.join('\n');
  }

  String gecmisBaslikMetni(Islem kayit) {
    final kullanici = kayit.kullaniciAdi.trim();
    if (kullanici.isEmpty) {
      return '${kayit.tur} • Ekleyen bilinmiyor';
    }
    return '${kayit.tur} • $kullanici yaptı';
  }

  DateTime islemTarihiGetir(Islem kayit) {
    final baslangic = parseKayitZamani(kayit.baslangicZamani);
    if (baslangic != null) {
      return baslangic;
    }

    try {
      return DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').parse(kayit.tarih);
    } catch (_) {
      return turkiyeSimdi();
    }
  }

  DateTime tarihAnahtari(DateTime tarih) {
    return DateTime(tarih.year, tarih.month, tarih.day);
  }

  bool ayniGun(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Islem> get filtrelenmisGecmis {
    var filtreli = gecmis;
    if (seciliIslemFiltresi != 'Tum') {
      filtreli =
          filtreli.where((kayit) => kayit.tur == seciliIslemFiltresi).toList();
    }
    if (seciliKullaniciFiltresi != 'Tum kullanicilar') {
      filtreli = filtreli
          .where(
            (kayit) =>
                (kayit.kullaniciAdi.trim().isEmpty
                    ? 'Bilinmeyen'
                    : kayit.kullaniciAdi.trim()) ==
                seciliKullaniciFiltresi,
          )
          .toList();
    }
    return filtreli;
  }

  List<String> get kullaniciFiltreleri {
    final kullanicilar = gecmis
        .map((kayit) => kayit.kullaniciAdi.trim().isEmpty ? 'Bilinmeyen' : kayit.kullaniciAdi.trim())
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Tum kullanicilar', ...kullanicilar];
  }

  List<String> get islemFiltreleri {
    return ['Tum', ...tumIslemTurleri.map((tanim) => tanim.ad)];
  }

  List<Islem> get seciliGundekiKayitlar {
    return filtrelenmisGecmis
        .where((kayit) => ayniGun(islemTarihiGetir(kayit), seciliTakvimTarihi))
        .toList();
  }

  Map<DateTime, int> get takvimIslemSayilari {
    final sonuc = <DateTime, int>{};
    for (final kayit in filtrelenmisGecmis) {
      final anahtar = tarihAnahtari(islemTarihiGetir(kayit));
      sonuc[anahtar] = (sonuc[anahtar] ?? 0) + 1;
    }
    return sonuc;
  }

  Map<DateTime, Set<String>> get takvimIslemTurleri {
    final sonuc = <DateTime, Set<String>>{};
    for (final kayit in filtrelenmisGecmis) {
      final anahtar = tarihAnahtari(islemTarihiGetir(kayit));
      sonuc.putIfAbsent(anahtar, () => <String>{}).add(kayit.tur);
    }
    return sonuc;
  }

  List<String> get takvimLejandesiTurleri {
    final turler = takvimIslemTurleri.values
        .expand((eleman) => eleman)
        .toSet()
        .toList(growable: false);
    turler.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return turler;
  }

  void _tarlayaSonIslemTarihleriniUygula(List<Islem> kayitlar) {
    DateTime? sonSulama;
    DateTime? sonGubre;
    DateTime? sonIlac;

    // Custom tiplerin kategori haritasini kullan
    final kategoriMap = <String, String>{};
    for (final tip in ozelIslemTurleri) {
      if (tip.kategori.isNotEmpty) {
        kategoriMap[tip.ad] = tip.kategori;
      }
    }

    for (final kayit in kayitlar) {
      final zaman = parseKayitZamani(kayit.baslangicZamani);
      if (zaman == null) continue;
      final efektivTur = kategoriMap[kayit.tur] ?? kayit.tur;

      if (efektivTur == 'Sulama' &&
          (sonSulama == null || zaman.isAfter(sonSulama))) {
        sonSulama = zaman;
      }
      if (efektivTur == 'Gubre' &&
          (sonGubre == null || zaman.isAfter(sonGubre))) {
        sonGubre = zaman;
      }
      if (efektivTur == 'Ilac' &&
          (sonIlac == null || zaman.isAfter(sonIlac))) {
        sonIlac = zaman;
      }
    }

    widget.tarla
      ..sonSulama = sonSulama
      ..sonGubre = sonGubre
      ..sonIlac = sonIlac;
  }


  void takvimSeciminiUygula({bool zorlaSonKaydaGit = false}) {
    final filtreli = filtrelenmisGecmis;
    if (filtreli.isEmpty) {
      setState(() {
        seciliTakvimTarihi = tarihAnahtari(turkiyeSimdi());
        gosterilenTakvimAyi = DateTime(
          seciliTakvimTarihi.year,
          seciliTakvimTarihi.month,
        );
      });
      return;
    }

    final seciliGundeKayitVar = filtreli.any(
      (kayit) => ayniGun(islemTarihiGetir(kayit), seciliTakvimTarihi),
    );

    if (!zorlaSonKaydaGit && seciliGundeKayitVar) {
      return;
    }

    final hedefTarih = tarihAnahtari(islemTarihiGetir(filtreli.first));
    setState(() {
      seciliTakvimTarihi = hedefTarih;
      gosterilenTakvimAyi = DateTime(hedefTarih.year, hedefTarih.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final darEkran = MediaQuery.sizeOf(context).width < 600;
    final kayitliAlanMetrekare = sinirNoktalari.length >= 3
        ? parselAlaniMetrekare(sinirNoktalari)
        : widget.tarla.alanMetrekare;
    final fotoSayisi = fotoListesiCoz(widget.tarla.fotoBase64).length;
    final sezonOzeti = tarlaSezonOzetiHesapla(widget.tarla, gecmis);
    final aylikYogunluk = aylikIslemYogunluguHesapla(gecmis);

    return TasarimArkaPlani(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(widget.tarla.ad),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FinancialDashboardScreen(tarlaId: widget.tarla.id),
                ),
              );
            },
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Tarla Finansal Durumu',
          ),
          IconButton(
            onPressed: tarlaBilgileriniDuzenle,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Tarlayi duzenle',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(darEkran ? 10 : 14),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - (darEkran ? 20 : 28),
                maxWidth: 480,
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF476F3A).withValues(alpha: 0.12),
                          const Color(0xFFC89B5D).withValues(alpha: 0.16),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(darEkran ? 12 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hızlı işlemler',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(height: darEkran ? 6 : 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final kartGenisligi = (constraints.maxWidth - 10) / 2;
                              final hizliIslemTurleri = [
                                ...tumIslemTurleri,
                                if (islemTurleriYukleniyor) ...[],
                              ];
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final tanim in hizliIslemTurleri)
                                    HizliIslemKarti(
                                      width: kartGenisligi,
                                      ikon: islemTuruIkonunuGetir(tanim.iconKey),
                                      renk: islemTuruRenginiGetir(tanim),
                                      baslik: tanim.ad,
                                      aciklama: tanim.ad == 'Sulama'
                                          ? 'Başlangıç saati ve süre'
                                          : 'Not ve tarih ekle',
                                      onTap: () => yeniIslemEkle(tanim.ad),
                                    ),
                                  HizliIslemKarti(
                                    width: kartGenisligi,
                                    ikon: Icons.photo_library_outlined,
                                    renk: Colors.teal,
                                    baslik: 'Not ekle',
                                    aciklama: fotoSayisi == 0
                                        ? 'Sadece not ve fotograf'
                                        : '$fotoSayisi fotograf ve not',
                                    onTap: ekBilgileriDuzenle,
                                  ),
                                ],
                              );
                            },
                          ),
                          if (widget.tarla.notlar.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                MiniBilgiRozeti(
                                  ikon: Icons.notes_outlined,
                                  renk: Colors.blueGrey,
                                  metin: 'Not',
                                  altMetin: widget.tarla.notlar.trim(),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(darEkran ? 12 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4D7FC6).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.auto_graph_outlined),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Tarla sezon özeti',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              MiniBilgiRozeti(
                                ikon: Icons.water_drop,
                                renk: Colors.blue,
                                metin: 'Sulama',
                                altMetin: '${sezonOzeti.sulamaSayisi} kayıt',
                              ),
                              MiniBilgiRozeti(
                                ikon: Icons.grass,
                                renk: Colors.green,
                                metin: 'Gubre',
                                altMetin: '${sezonOzeti.gubreSayisi} kayıt',
                              ),
                              MiniBilgiRozeti(
                                ikon: Icons.science,
                                renk: Colors.orange,
                                metin: 'Ilac',
                                altMetin: '${sezonOzeti.ilacSayisi} kayıt',
                              ),
                              MiniBilgiRozeti(
                                ikon: Icons.payments_outlined,
                                renk: Colors.teal,
                                metin: 'Toplam islem',
                                altMetin: '${sezonOzeti.sulamaSayisi + sezonOzeti.gubreSayisi + sezonOzeti.ilacSayisi} kayıt',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(darEkran ? 12 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B5EA7).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.insights_outlined),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Son ayların işlem yoğunluğu',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Son 6 ayda hangi aylarda daha çok işlem yapıldığını küçük grafikte gör.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          AylikYogunlukGrafigi(veriler: aylikYogunluk),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(darEkran ? 12 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF476F3A).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.location_on_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tarla konumu',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      konumMetni(),
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatAlanOzeti(
                                        alanMetrekare: kayitliAlanMetrekare,
                                        varsayilanMetin: widget.tarla.alan,
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: konumuGuncelle,
                                  icon: const Icon(Icons.my_location),
                                  label: const Text('GPS güncelle'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: uyduHaritasiniAc,
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('Uydu haritası'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  onPressed: konumuPaylas,
                                  icon: const Icon(Icons.share_location_outlined),
                                  label: const Text('Paylaş'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(darEkran ? 14 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC89B5D).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.cloud_outlined),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Tarla hava durumu',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: havaDurumuYukle,
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Yenile',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (havaYukleniyor)
                            const Text('Hava durumu yukleniyor...')
                          else if (havaDurumu != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MGM baglantisi: ${havaDurumu!.mgmEtiketi}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      await launchUrl(
                                        Uri.parse(havaDurumu!.mgmDetayUrl),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_new_outlined),
                                    label: const Text('MGM sayfasini ac'),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(havaHatasi ?? 'Hava durumu verisi yok'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Islem gecmisi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < islemFiltreleri.length; i++) ...[
                    _islemFiltreCipi(islemFiltreleri[i]),
                    if (i != islemFiltreleri.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < kullaniciFiltreleri.length; i++) ...[
                    _kullaniciFiltreCipi(kullaniciFiltreleri[i]),
                    if (i != kullaniciFiltreleri.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'Liste',
                  icon: Icon(Icons.view_list_outlined),
                  label: Text('Liste'),
                ),
                ButtonSegment<String>(
                  value: 'Takvim',
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('Takvim'),
                ),
              ],
              selected: {seciliGecmisGorunumu},
              onSelectionChanged: (selection) {
                setState(() {
                  seciliGecmisGorunumu = selection.first;
                });
                if (selection.first == 'Takvim') {
                  takvimSeciminiUygula(zorlaSonKaydaGit: true);
                }
              },
            ),
            const SizedBox(height: 8),
            if (widget.bulutEtkin && !widget.aileSahibiMi) ...[
              Text(
                'Silme yetkisi yonetici hesapta. Kayitlari duzenleyebilirsin ama silemezsin.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (seciliGecmisGorunumu == 'Takvim') ...[
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.start,
                children: [
                  for (final tur in takvimLejandesiTurleri)
                    TakvimLejandesi(
                      renk: islemTuruRenginiGetir(islemTuruTanimGetir(tur)),
                      etiket: tur,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              AylikIslemTakvimi(
                gosterilenAy: gosterilenTakvimAyi,
                seciliTarih: seciliTakvimTarihi,
                islemSayilari: takvimIslemSayilari,
                islemTurleri: takvimIslemTurleri,
                turRenkleri: {
                  for (final tanim in tumIslemTurleri)
                    tanim.ad: islemTuruRenginiGetir(tanim),
                },
                onAyDegistir: (yeniAy) {
                  setState(() {
                    gosterilenTakvimAyi = DateTime(yeniAy.year, yeniAy.month);
                  });
                },
                onTarihSec: (tarih) {
                  setState(() {
                    seciliTakvimTarihi = tarih;
                    gosterilenTakvimAyi = DateTime(tarih.year, tarih.month);
                  });
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  takvimIslemSayilari.containsKey(tarihAnahtari(seciliTakvimTarihi))
                      ? 'Secili gunde ${takvimIslemSayilari[tarihAnahtari(seciliTakvimTarihi)]} kayit var.'
                      : 'Kayit olan gunler kutularin icindeki sayi ile gosterilir.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${DateFormat('dd MMMM yyyy', 'tr_TR').format(seciliTakvimTarihi)} icin kayitlar',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            if (yukleniyor)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((seciliGecmisGorunumu == 'Takvim'
                    ? seciliGundekiKayitlar
                    : filtrelenmisGecmis)
                .isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    seciliGecmisGorunumu == 'Takvim'
                        ? '${DateFormat('dd MMMM yyyy', 'tr_TR').format(seciliTakvimTarihi)} icin '
                            '${seciliIslemFiltresi == 'Tum' ? 'kayit yok.' : '$seciliIslemFiltresi kaydi bulunamadi.'}'
                        : seciliIslemFiltresi == 'Tum'
                            ? (seciliKullaniciFiltresi == 'Tum kullanicilar'
                                ? 'Bu tarla icin henuz kayit yok.'
                                : '$seciliKullaniciFiltresi icin kayit bulunamadi.')
                            : '$seciliIslemFiltresi kaydi bulunamadi.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: filtrelenmisGecmis.length > 10
                      ? 500
                      : (filtrelenmisGecmis.length * 80.0).clamp(80, 500),
                ),
                child: ListView.separated(
                  itemCount: seciliGecmisGorunumu == 'Takvim'
                      ? seciliGundekiKayitlar.length
                      : filtrelenmisGecmis.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final aktifListe = seciliGecmisGorunumu == 'Takvim'
                        ? seciliGundekiKayitlar
                        : filtrelenmisGecmis;
                    final kayit = aktifListe[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_islemIkonu(kayit.tur)),
                      title: Text(gecmisBaslikMetni(kayit)),
                      subtitle: Text(gecmisAltMetin(kayit)),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'duzenle') {
                            await gecmisKaydiniDuzenle(kayit);
                            return;
                          }
                          if (value == 'sil') {
                            await gecmisKaydiniSil(kayit);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'duzenle',
                            child: Text('Duzenle'),
                          ),
                          if (widget.aileSahibiMi)
                            const PopupMenuItem(
                              value: 'sil',
                              child: Text('Sil'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
                ],
              ),
            ),
          ),
        ),
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
    ],
  ),
);
}

  IconData _islemIkonu(String tur) {
    return islemTuruIkonunuGetir(islemTuruTanimGetir(tur).iconKey);
  }

  Widget _islemFiltreCipi(String filtre) {
    return ChoiceChip(
      label: Text(filtre),
      selected: seciliIslemFiltresi == filtre,
      onSelected: (_) {
        setState(() {
          seciliIslemFiltresi = filtre;
        });
        if (seciliGecmisGorunumu == 'Takvim') {
          takvimSeciminiUygula(zorlaSonKaydaGit: true);
        }
      },
    );
  }

  Widget _kullaniciFiltreCipi(String filtre) {
    return ChoiceChip(
      label: Text(filtre),
      selected: seciliKullaniciFiltresi == filtre,
      onSelected: (_) {
        setState(() {
          seciliKullaniciFiltresi = filtre;
        });
        if (seciliGecmisGorunumu == 'Takvim') {
          takvimSeciminiUygula(zorlaSonKaydaGit: true);
        }
      },
    );
  }
}
