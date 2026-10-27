import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';


import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_session_service.dart';
import 'database_helper.dart';
import 'islem_model.dart';
import 'tarla_model.dart';

class ExportService {
  /// Türkçe destekli Roboto fontunu yükler
  static Future<pw.Font> _fontYukle(String asset) async {
    final data = await rootBundle.load(asset);
    return pw.Font.ttf(data);
  }

  static Future<String> pdfRaporuOlustur() async {
    final tarlalar = await DatabaseHelper.instance.tumTarlalar();
    final aktifAileKodu =
        await AppSessionService.kayitliAileKodunuGetir() ??
        await AppSessionService.sonAileKodunuGetir() ??
        'YEREL';

    // Profil adini ve ozel isleri tipleri yukle
    final prefs = await SharedPreferences.getInstance();
    final profilAd = prefs.getString('profil_ad_soyad') ??
        await AppSessionService.kullaniciAdiniGetir() ?? '';

    // Türkçe destekli font yükle
    final regular = await _fontYukle('assets/fonts/Roboto-Regular.ttf');
    final bold = await _fontYukle('assets/fonts/Roboto-Bold.ttf');

    final rapor = pw.Document(
      title: 'Tarim360 PDF Raporu',
      author: profilAd.isNotEmpty ? profilAd : 'Tarim360',
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
      ),
    );

    final olusturmaZamani = DateTime.now();
    final tarihFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');
    final sezonBaslangici = DateTime(olusturmaZamani.year, 1, 1);
    final tarlaVerileri = <_TarlaRaporVerisi>[];
    final kullaniciOzeti = <String, _KullaniciRaporOzeti>{};

    var toplamAlan = 0.0;
    var toplamIslem = 0;
    var toplamSulama = 0;
    var toplamGubre = 0;
    var toplamIlac = 0;
    var toplamDiger = 0;
    DateTime? sonKayitTarihi;

    for (final tarla in tarlalar) {
      final islemler = tarla.id == null
          ? const <Islem>[]
          : await DatabaseHelper.instance.tarlaIslemleri(tarla.id!);
      final sezonOzeti = _tarlaSezonOzetiHesapla(
        tarla: tarla,
        islemler: islemler,
        sezonBaslangici: sezonBaslangici,
      );

      tarlaVerileri.add(
        _TarlaRaporVerisi(
          tarla: tarla,
          islemler: islemler,
          sezonOzeti: sezonOzeti,
        ),
      );

      toplamAlan += tarla.alanMetrekare ?? 0;
      toplamIslem += islemler.length;
      toplamSulama += sezonOzeti.sulamaSayisi;
      toplamGubre += sezonOzeti.gubreSayisi;
      toplamIlac += sezonOzeti.ilacSayisi;
      toplamDiger += sezonOzeti.digerIslemSayisi;
      for (final islem in islemler) {
        final kullanici = islem.kullaniciAdi.trim().isEmpty
            ? 'Bilinmeyen'
            : islem.kullaniciAdi.trim();
        final onceki = kullaniciOzeti[kullanici] ?? const _KullaniciRaporOzeti();
        kullaniciOzeti[kullanici] = onceki.kopyala(
          islemSayisi: onceki.islemSayisi + 1,
          sulamaSayisi: onceki.sulamaSayisi + (islem.tur == 'Sulama' ? 1 : 0),
          gubreSayisi: onceki.gubreSayisi + (islem.tur == 'Gubre' ? 1 : 0),
          ilacSayisi: onceki.ilacSayisi + (islem.tur == 'Ilac' ? 1 : 0),
        );

        final tarih = DateTime.tryParse(islem.baslangicZamani ?? '');
        if (tarih != null &&
            (sonKayitTarihi == null || tarih.isAfter(sonKayitTarihi))) {
          sonKayitTarihi = tarih;
        }
      }
    }

    final siraliKullanicilar = kullaniciOzeti.entries.toList()
      ..sort((a, b) => b.value.islemSayisi.compareTo(a.value.islemSayisi));

    rapor.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _kapakBolumu(
            aktifAileKodu: aktifAileKodu,
            olusturmaZamani: tarihFormat.format(olusturmaZamani),
          ),
          pw.SizedBox(height: 14),
          _raporBolumu(
            baslik: 'Ekip Özeti',
            altBaslik: 'Ortak kayıt alanının genel durumu',
            icerik: pw.Column(
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _vurguluKutucuk(
                        baslik: 'Kullanıcı',
                        deger: '${kullaniciOzeti.length}',
                        arkaPlan: PdfColors.blue50,
                        kenar: PdfColors.blue200,
                        yazi: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: _vurguluKutucuk(
                        baslik: 'Son Kayıt',
                        deger: sonKayitTarihi == null
                            ? '-'
                            : tarihFormat.format(sonKayitTarihi.toLocal()),
                        arkaPlan: PdfColors.orange50,
                        kenar: PdfColors.orange200,
                        yazi: PdfColors.orange800,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                _ciftKolonTablo(
                  headers: const ['Başlık', 'Değer'],
                  data: [
                    ['Toplam Tarla', '${tarlaVerileri.length}'],
                    ['Toplam Alan', '${toplamAlan.toStringAsFixed(0)} m²'],
                    ['Toplam Kayıt', '$toplamIslem'],
                    [
                      'En Aktif Kullanıcı',
                      siraliKullanicilar.isEmpty
                          ? '-'
                          : _pdfMetni(siraliKullanicilar.first.key),
                    ],
                  ],
                  baslikRengi: PdfColors.green700,
                  satirRengi: PdfColors.green50,
                  kenarRengi: PdfColors.green100,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _raporBolumu(
            baslik: 'Sezon Özeti',
            altBaslik: '${olusturmaZamani.year} sezonu toplu raporu',
            icerik: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _etiketRozeti('Sulama', '$toplamSulama', PdfColors.lightBlue700),
                    _etiketRozeti('Gübre', '$toplamGubre', PdfColors.green700),
                    _etiketRozeti('İlaç', '$toplamIlac', PdfColors.orange700),
                    _etiketRozeti('Diğer', '$toplamDiger', PdfColors.purple700),
                  ],
                ),
                pw.SizedBox(height: 10),
                _ciftKolonTablo(
                  headers: const ['Özet', 'Değer'],
                  data: [
                    ['Toplam Tarla', '${tarlaVerileri.length}'],
                    ['Toplam Alan', '${toplamAlan.toStringAsFixed(0)} m²'],
                    ['Toplam İşlem', '$toplamIslem'],
                    ['Toplam Sulama', '$toplamSulama'],
                    ['Toplam Gübre', '$toplamGubre'],
                    ['Toplam İlaç', '$toplamIlac'],
                  ],
                  baslikRengi: PdfColors.blueGrey700,
                  satirRengi: PdfColors.blueGrey50,
                  kenarRengi: PdfColors.blueGrey100,
                ),
              ],
            ),
          ),
          if (siraliKullanicilar.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _raporBolumu(
              baslik: 'Kullanıcı Özeti',
              altBaslik: 'Kim ne kadar işlem girdi',
              icerik: pw.TableHelper.fromTextArray(
                headers: const [
                  'Kullanıcı',
                  'Toplam',
                  'Sulama',
                  'Gübre',
                  'İlaç',
                ],
                data: siraliKullanicilar
                    .map(
                      (entry) => [
                        _pdfMetni(entry.key),
                        '${entry.value.islemSayisi}',
                        '${entry.value.sulamaSayisi}',
                        '${entry.value.gubreSayisi}',
                        '${entry.value.ilacSayisi}',
                      ],
                    )
                    .toList(),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.deepPurple700,
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.deepPurple50,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: pw.TableBorder.all(color: PdfColors.deepPurple100),
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
          pw.SizedBox(height: 18),
          if (tarlaVerileri.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text('Kayıtlı tarla bulunamadı.'),
            ),
          ...tarlaVerileri.expand(
            (veri) => [
              pw.NewPage(freeSpace: 330),
              _tarlaBolumu(veri, tarihFormat),
            ],
          ),
        ],
      ),
    );

    final klasor = await _hedefKlasoruGetir();
    await klasor.create(recursive: true);

    final zamanDamgasi = olusturmaZamani
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final dosya = File(
      p.join(klasor.path, 'Tarim360_Analiz_Raporu_$zamanDamgasi.pdf'),
    );
    await dosya.writeAsBytes(await rapor.save());
    return dosya.path;
  }

  static Future<Directory> _hedefKlasoruGetir() async {
    if (Platform.isAndroid) {
      final indirilenler = Directory('/storage/emulated/0/Download/Tarim360');
      try {
        await indirilenler.create(recursive: true);
        return indirilenler;
      } catch (_) {}
      final indirilenlerAlt = Directory('/storage/emulated/0/Downloads/Tarim360');
      try {
        await indirilenlerAlt.create(recursive: true);
        return indirilenlerAlt;
      } catch (_) {}
      final disKlasor = await getExternalStorageDirectory();
      if (disKlasor != null) {
        return Directory(p.join(disKlasor.path, 'Tarim360Raporlari'));
      }
    }

    final indirilenler = await getDownloadsDirectory();
    if (indirilenler != null) {
      return Directory(p.join(indirilenler.path, 'Tarim360Raporlari'));
    }

    final belgeler = await getApplicationDocumentsDirectory();
    return Directory(p.join(belgeler.path, 'Tarim360Raporlari'));
  }

  static pw.Widget _kapakBolumu({
    required String aktifAileKodu,
    required String olusturmaZamani,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.green700,
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Tarim360 Analiz Raporu',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 24,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Olusturma: $olusturmaZamani',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static pw.Widget _raporBolumu({
    required String baslik,
    required String altBaslik,
    required pw.Widget icerik,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            baslik,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            altBaslik,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          icerik,
        ],
      ),
    );
  }

  static pw.Widget _vurguluKutucuk({
    required String baslik,
    required String deger,
    required PdfColor arkaPlan,
    required PdfColor kenar,
    required PdfColor yazi,
  }) {
    final double degerFontSize = deger.length > 12 ? 8.5 : 12;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: arkaPlan,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: kenar),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            baslik,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _pdfMetni(deger),
            style: pw.TextStyle(
              color: yazi,
              fontSize: degerFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _etiketRozeti(String baslik, String deger, PdfColor renk) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border.all(color: renk),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$baslik: ',
              style: const pw.TextStyle(
                color: PdfColors.black,
                fontSize: 10,
              ),
            ),
            pw.TextSpan(
              text: _pdfMetni(deger),
              style: pw.TextStyle(
                color: renk,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _ciftKolonTablo({
    required List<String> headers,
    required List<List<String>> data,
    required PdfColor baslikRengi,
    required PdfColor satirRengi,
    required PdfColor kenarRengi,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerDecoration: pw.BoxDecoration(color: baslikRengi),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      ),
      oddRowDecoration: pw.BoxDecoration(color: satirRengi),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: pw.TableBorder.all(color: kenarRengi),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }

  static pw.Widget _tarlaBolumu(
    _TarlaRaporVerisi veri,
    DateFormat tarihFormat,
  ) {
    final tarla = veri.tarla;
    final alanOzeti = _alanOzeti(tarla);
    final bilgiler = <List<String>>[
      ['Urun', _pdfMetni(tarla.urun.isEmpty ? 'Belirtilmedi' : tarla.urun)],
      ['Alan', _pdfMetni(alanOzeti)],
      [
        'Konum',
        _pdfMetni(
          tarla.enlem != null && tarla.boylam != null
              ? '${tarla.enlem!.toStringAsFixed(6)}, ${tarla.boylam!.toStringAsFixed(6)}'
              : 'Konum yok',
        ),
      ],
      ['Son sulama', _tarihMetni(tarla.sonSulama, tarihFormat)],
      ['Son gubre', _tarihMetni(tarla.sonGubre, tarihFormat)],
      ['Son ilac', _tarihMetni(tarla.sonIlac, tarihFormat)],
      ['Not', _pdfMetni(tarla.notlar.isEmpty ? '-' : tarla.notlar)],
      ['Kim ne girdi', _pdfMetni(_kullaniciOzetMetni(veri.islemler))],
    ];

    // Islem gecmisini tarihe gore sirala (en yeni en uste)
    final siraliIslemler = List<Islem>.from(veri.islemler)
      ..sort((a, b) {
        final ta = DateTime.tryParse(a.baslangicZamani ?? '') ?? DateTime(2000);
        final tb = DateTime.tryParse(b.baslangicZamani ?? '') ?? DateTime(2000);
        return tb.compareTo(ta);
      });

    final islemSatirlari = siraliIslemler.isEmpty
        ? [
            ['Kayit yok', '-', '-', '-'],
          ]
        : siraliIslemler.map((islem) {
            final zaman = DateTime.tryParse(islem.baslangicZamani ?? '');
            final detayParcalari = <String>[
              if (islem.detay.isNotEmpty) islem.detay,
              if (islem.fotoBase64.trim().isNotEmpty)
                '${_fotoSayisiGetir(islem.fotoBase64)} foto',
            ];
            return [
              _pdfMetni(islem.tur),
              _pdfMetni(detayParcalari.isEmpty ? '-' : detayParcalari.join(' • ')),
              zaman != null ? tarihFormat.format(zaman.toLocal()) : '-',
              _pdfMetni(
                islem.kullaniciAdi.trim().isEmpty
                    ? 'Bilinmeyen'
                    : islem.kullaniciAdi.trim(),
              ),
            ];
          }).toList(growable: false);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green300),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _pdfMetni(tarla.ad),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (veri.sezonOzeti.sulamaSayisi > 0) _etiketRozeti('Sulama', '${veri.sezonOzeti.sulamaSayisi}', PdfColors.lightBlue700),
              if (veri.sezonOzeti.gubreSayisi > 0) _etiketRozeti('Gubre', '${veri.sezonOzeti.gubreSayisi}', PdfColors.green700),
              if (veri.sezonOzeti.ilacSayisi > 0) _etiketRozeti('Ilac', '${veri.sezonOzeti.ilacSayisi}', PdfColors.orange700),
              // Custom islem turleri — her biri kendi adiya goster
              ...veri.sezonOzeti.customTipler.entries
                  .where((e) => e.value > 0)
                  .map((e) => _etiketRozeti(_pdfMetni(e.key), '${e.value}', PdfColors.teal700)),
            ],
          ),
          pw.SizedBox(height: 10),
          _ciftKolonTablo(
            headers: const ['Bilgi', 'Deger'],
            data: bilgiler,
            baslikRengi: PdfColors.green700,
            satirRengi: PdfColors.green50,
            kenarRengi: PdfColors.green100,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Islem gecmisi',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Tur', 'Detay', 'Baslangic', 'Ekleyen'],
            data: islemSatirlari,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey700,
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey50,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            border: pw.TableBorder.all(color: PdfColors.blueGrey100),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          if (_sulamaHatirlatmasiVar(tarla)) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                _pdfMetni(_sulamaHatirlatmaMetni(tarla, tarihFormat)),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _alanOzeti(Tarla tarla) {
    if (tarla.alanMetrekare != null && tarla.alanMetrekare! > 0) {
      return '${tarla.alanMetrekare!.toStringAsFixed(0)} m2';
    }
    if (tarla.alan.trim().isNotEmpty) {
      final temiz = tarla.alan.trim();
      if (temiz.contains('m2 /')) {
        return temiz.split('/').first.trim();
      }
      return temiz;
    }
    return 'Alan bilgisi yok';
  }

  static bool _sulamaHatirlatmasiVar(Tarla tarla) {
    final sonSulama = tarla.sonSulama;
    if (sonSulama == null) return true;
    return DateTime.now().difference(sonSulama).inDays >= 7;
  }

  static String _sulamaHatirlatmaMetni(Tarla tarla, DateFormat tarihFormat) {
    final sonSulama = tarla.sonSulama;
    if (sonSulama == null) {
      return '${tarla.ad}: son sulama kaydi yok.';
    }

    final gun = DateTime.now().difference(sonSulama).inDays;
    return '${tarla.ad}: $gun gundur sulanmadi. Son sulama ${tarihFormat.format(sonSulama)}.';
  }

  static String _tarihMetni(DateTime? tarih, DateFormat format) {
    if (tarih == null) return '-';
    return format.format(tarih);
  }

  static int _fotoSayisiGetir(String value) {
    final temiz = value.trim();
    if (temiz.isEmpty) return 0;
    if (temiz.startsWith('[')) {
      try {
        final jsonDegeri = jsonDecode(temiz);
        if (jsonDegeri is List) {
          return jsonDegeri
              .whereType<String>()
              .where((e) => e.trim().isNotEmpty)
              .length;
        }
      } catch (_) {}
    }
    return 1;
  }

  static String _kullaniciOzetMetni(List<Islem> islemler) {
    if (islemler.isEmpty) return '-';
    final ozet = <String, int>{};
    for (final islem in islemler) {
      final kullanici = islem.kullaniciAdi.trim().isEmpty
          ? 'Bilinmeyen'
          : islem.kullaniciAdi.trim();
      ozet[kullanici] = (ozet[kullanici] ?? 0) + 1;
    }
    return ozet.entries.map((e) => '${e.key} (${e.value})').join(', ');
  }

  /// Türkçe karakterleri artık olduğu gibi bırakır — font embed edildiği için
  /// PDF'de düzgün görüntülenir.
  static String _pdfMetni(String value) => value;
}

class _TarlaRaporVerisi {
  const _TarlaRaporVerisi({
    required this.tarla,
    required this.islemler,
    required this.sezonOzeti,
  });

  final Tarla tarla;
  final List<Islem> islemler;
  final _SezonOzeti sezonOzeti;
}

class _SezonOzeti {
  const _SezonOzeti({
    required this.sulamaSayisi,
    required this.gubreSayisi,
    required this.ilacSayisi,
    required this.digerIslemSayisi,
    this.customTipler = const {},
  });

  final int sulamaSayisi;
  final int gubreSayisi;
  final int ilacSayisi;
  final int digerIslemSayisi;
  final Map<String, int> customTipler;
}

class _KullaniciRaporOzeti {
  const _KullaniciRaporOzeti({
    this.islemSayisi = 0,
    this.sulamaSayisi = 0,
    this.gubreSayisi = 0,
    this.ilacSayisi = 0,
  });

  final int islemSayisi;
  final int sulamaSayisi;
  final int gubreSayisi;
  final int ilacSayisi;

  _KullaniciRaporOzeti kopyala({
    int? islemSayisi,
    int? sulamaSayisi,
    int? gubreSayisi,
    int? ilacSayisi,
  }) {
    return _KullaniciRaporOzeti(
      islemSayisi: islemSayisi ?? this.islemSayisi,
      sulamaSayisi: sulamaSayisi ?? this.sulamaSayisi,
      gubreSayisi: gubreSayisi ?? this.gubreSayisi,
      ilacSayisi: ilacSayisi ?? this.ilacSayisi,
    );
  }
}

_SezonOzeti _tarlaSezonOzetiHesapla({
  required Tarla tarla,
  required List<Islem> islemler,
  required DateTime sezonBaslangici,
}) {
  var sulama = 0;
  var gubre = 0;
  var ilac = 0;
  var diger = 0;
  final customMap = <String, int>{};

  for (final islem in islemler) {
    final tarih = DateTime.tryParse(islem.baslangicZamani ?? '');
    if (tarih == null || tarih.isBefore(sezonBaslangici)) continue;
    switch (islem.tur) {
      case 'Sulama':
        sulama++;
        break;
      case 'Gubre':
        gubre++;
        break;
      case 'Ilac':
        ilac++;
        break;
      default:
        // Custom islem tupu — adini koru
        customMap[islem.tur] = (customMap[islem.tur] ?? 0) + 1;
        diger++;
        break;
    }
  }

  return _SezonOzeti(
    sulamaSayisi: sulama,
    gubreSayisi: gubre,
    ilacSayisi: ilac,
    digerIslemSayisi: diger,
    customTipler: customMap,
  );
}
