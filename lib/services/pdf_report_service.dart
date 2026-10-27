import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../gelir_model.dart';
import '../islem_model.dart';
import '../tarla_model.dart';

class PdfReportService {
  static Future<pw.Font> _fontYukle(String asset) async {
    final data = await rootBundle.load(asset);
    return pw.Font.ttf(data);
  }

  /// Tüm tarlaları kapsayan tek finans raporu PDF'i oluşturur
  static Future<File> tumTarlaFinansRaporuOlustur({
    required List<Tarla> tarlalar,
    required Map<int, List<Islem>> tarlaIslemleriMap,
    required Map<int, List<Gelir>> tarlaGelirleriMap,
    String aileAdi = '',
  }) async {
    final regular = await _fontYukle('assets/fonts/Roboto-Regular.ttf');
    final bold = await _fontYukle('assets/fonts/Roboto-Bold.ttf');
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    final trFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
    final tarihStr = trFormat.format(DateTime.now());

    var genelToplamMaliyet = 0.0;
    var genelToplamGelir = 0.0;

    final tarlaSatirlar = <List<String>>[];
    for (final tarla in tarlalar) {
      final islemler = tarlaIslemleriMap[tarla.id] ?? [];
      final gelirler = tarlaGelirleriMap[tarla.id] ?? [];
      final maliyet = islemler.fold(0.0, (s, i) => s + (i.maliyet ?? 0));
      final gelir = gelirler.fold(0.0, (s, g) => s + g.miktar);
      final net = gelir - maliyet;
      genelToplamMaliyet += maliyet;
      genelToplamGelir += gelir;
      tarlaSatirlar.add([
        tarla.ad,
        '${gelir.toStringAsFixed(2)} TL',
        '${maliyet.toStringAsFixed(2)} TL',
        '${net >= 0 ? '+' : ''}${net.toStringAsFixed(2)} TL',
      ]);
    }
    final genelNet = genelToplamGelir - genelToplamMaliyet;

    // Özet sayfası
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      header: (ctx) => _buildHeader(aileAdi, tarihStr, baslik: 'Tarim360 Finans Raporu'),
      footer: (ctx) => _buildFooter(ctx),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: genelNet >= 0 ? PdfColors.green50 : PdfColors.red50,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: genelNet >= 0 ? PdfColors.green300 : PdfColors.red300),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Genel Ozet - Tum Tarlalar',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              _ozetKutu('Toplam Gelir', '${genelToplamGelir.toStringAsFixed(2)} TL', PdfColors.green700),
              pw.SizedBox(width: 10),
              _ozetKutu('Toplam Gider', '${genelToplamMaliyet.toStringAsFixed(2)} TL', PdfColors.red700),
              pw.SizedBox(width: 10),
              _ozetKutu('Net Kar/Zarar', '${genelNet >= 0 ? '+' : ''}${genelNet.toStringAsFixed(2)} TL',
                  genelNet >= 0 ? PdfColors.green700 : PdfColors.red700),
            ]),
          ]),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Tarla Bazli Ozet', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Tarla', 'Gelir', 'Gider', 'Net'],
          data: tarlaSatirlar,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: pw.TableBorder.all(color: PdfColors.blueGrey100),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ));

    // Her tarla için ayrı sayfa
    for (final tarla in tarlalar) {
      final islemler = tarlaIslemleriMap[tarla.id] ?? [];
      final gelirler = tarlaGelirleriMap[tarla.id] ?? [];
      final maliyet = islemler.fold(0.0, (s, i) => s + (i.maliyet ?? 0));
      final gelir = gelirler.fold(0.0, (s, g) => s + g.miktar);
      final netKar = gelir - maliyet;
      final karDurumu = netKar >= 0 ? 'KAR' : 'ZARAR';
      final karRengi = netKar >= 0 ? PdfColors.green700 : PdfColors.red700;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (ctx) => _buildHeader(aileAdi, tarihStr, baslik: tarla.ad),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _buildTitleBlock(tarla),
          pw.SizedBox(height: 18),
          _buildFinancialSummary(gelir, maliyet, netKar, karDurumu, karRengi),
          pw.SizedBox(height: 24),
          _buildSectionTitle('Gelirler', PdfColors.green800),
          pw.SizedBox(height: 8),
          _buildGelirlerTable(gelirler, trFormat),
          pw.SizedBox(height: 24),
          _buildSectionTitle('Giderler ve Maliyetler', PdfColors.red800),
          pw.SizedBox(height: 8),
          _buildMaliyetlerTable(islemler, trFormat),
        ],
      ));
    }

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Tarim360_Finans_Raporu_$tarihStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _ozetKutu(String baslik, String deger, PdfColor renk) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: renk),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(baslik, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(deger, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: renk)),
        ]),
      ),
    );
  }

  static Future<File> sezonlukRaporOlustur({
    required Tarla tarla,
    required List<Islem> islemler,
    required List<Gelir> gelirler,
    String aileAdi = '',
  }) async {
    // Türkçe destekli fontları yükle
    final regular = await _fontYukle('assets/fonts/Roboto-Regular.ttf');
    final bold = await _fontYukle('assets/fonts/Roboto-Bold.ttf');

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final trFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
    final tarihStr = trFormat.format(DateTime.now());

    double toplamMaliyet = 0;
    for (final i in islemler) {
      toplamMaliyet += i.maliyet ?? 0.0;
    }

    double toplamGelir = 0;
    for (final g in gelirler) {
      toplamGelir += g.miktar;
    }

    final netKar = toplamGelir - toplamMaliyet;
    final karDurumu = netKar >= 0 ? 'KAR' : 'ZARAR';
    final karRengi = netKar >= 0 ? PdfColors.green700 : PdfColors.red700;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (context) => _buildHeader(aileAdi, tarihStr),
        footer: (context) => _buildFooter(context),
        build: (context) {
          return [
            _buildTitleBlock(tarla),
            pw.SizedBox(height: 18),
            _buildFinancialSummary(toplamGelir, toplamMaliyet, netKar, karDurumu, karRengi),
            pw.SizedBox(height: 24),
            _buildSectionTitle('Gelirler', PdfColors.green800),
            pw.SizedBox(height: 8),
            _buildGelirlerTable(gelirler, trFormat),
            pw.SizedBox(height: 24),
            _buildSectionTitle('Giderler ve Maliyetler', PdfColors.red800),
            pw.SizedBox(height: 8),
            _buildMaliyetlerTable(islemler, trFormat),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final safeName = tarla.ad
        .replaceAll('ş', 's').replaceAll('Ş', 'S')
        .replaceAll('ğ', 'g').replaceAll('Ğ', 'G')
        .replaceAll('ı', 'i').replaceAll('İ', 'I')
        .replaceAll('ö', 'o').replaceAll('Ö', 'O')
        .replaceAll('ü', 'u').replaceAll('Ü', 'U')
        .replaceAll('ç', 'c').replaceAll('Ç', 'C')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final file = File('${output.path}/${safeName}_FinansRaporu_$tarihStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(String aileAdi, String tarihStr, {String baslik = 'Tarim360 Finans Raporu'}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF1B4332),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Tarım360',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              if (aileAdi.isNotEmpty)
                pw.Text(
                  aileAdi,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300),
                ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Finans Raporu',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300),
              ),
              pw.Text(
                tarihStr,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FOOTER ────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Tarım360 — Otomatik Finans Raporu',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              ),
              pw.Text(
                'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TITLE BLOCK ───────────────────────────────────────────────────────────

  static pw.Widget _buildTitleBlock(Tarla tarla) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColors.green50, PdfColors.white],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.green200, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TARLA FİNANS RAPORU',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1B4332),
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              _infoChip('Tarla', tarla.ad),
              if (tarla.urun.isNotEmpty) _infoChip('Ürün', tarla.urun),
              if (tarla.alan.isNotEmpty) _infoChip('Alan', tarla.alan),
              if (tarla.notlar.isNotEmpty) _infoChip('Not', tarla.notlar),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoChip(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // ─── FINANCIAL SUMMARY ─────────────────────────────────────────────────────

  static pw.Widget _buildFinancialSummary(
    double gelir,
    double gider,
    double net,
    String durum,
    PdfColor renk,
  ) {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.blueGrey200),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: _summaryCard('Toplam Gelir', '${fmt.format(gelir)} ₺', PdfColors.green700, PdfColors.green50)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _summaryCard('Toplam Gider', '${fmt.format(gider)} ₺', PdfColors.red700, PdfColors.red50)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _summaryCard('Net ($durum)', '${fmt.format(net)} ₺', renk, PdfColors.grey100)),
        ],
      ),
    );
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: textColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: textColor)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── SECTION TITLE ─────────────────────────────────────────────────────────

  static pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  // ─── GELIRLER TABLOSU ──────────────────────────────────────────────────────

  static pw.Widget _buildGelirlerTable(List<Gelir> gelirler, DateFormat format) {
    if (gelirler.isEmpty) {
      return _emptyRow('Kayıtlı gelir bulunmamaktadır.');
    }

    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final headers = ['Tarih', 'Açıklama', 'Miktar (₺)'];
    final data = gelirler.map((g) {
      final t = DateTime.tryParse(g.tarih);
      return [
        t != null ? format.format(t) : g.tarih,
        g.aciklama.isEmpty ? '—' : g.aciklama,
        fmt.format(g.miktar),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.green50),
      cellHeight: 28,
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      border: pw.TableBorder.all(color: PdfColors.green100),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
      },
    );
  }

  // ─── MALIYETLER TABLOSU ────────────────────────────────────────────────────

  static pw.Widget _buildMaliyetlerTable(List<Islem> islemler, DateFormat format) {
    final maliyetliIslemler = islemler.where((i) => i.maliyet != null && i.maliyet! > 0).toList();

    if (maliyetliIslemler.isEmpty) {
      return _emptyRow('Kayıtlı gider bulunmamaktadır.');
    }

    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final headers = ['Tarih', 'İşlem Türü', 'Detay', 'Kullanıcı', 'Maliyet (₺)'];
    final data = maliyetliIslemler.map((i) {
      final t = DateTime.tryParse(i.baslangicZamani ?? '');
      final detay = i.detay.trim().isEmpty ? '—' : i.detay.trim();
      final kullanici = i.kullaniciAdi.trim().isEmpty ? '—' : i.kullaniciAdi.trim();
      return [
        t != null ? format.format(t) : i.tarih,
        i.tur,
        detay,
        kullanici,
        fmt.format(i.maliyet!),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.red50),
      cellHeight: 28,
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      border: pw.TableBorder.all(color: PdfColors.red100),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
      },
    );
  }

  // ─── YARDIMCI ──────────────────────────────────────────────────────────────

  static pw.Widget _emptyRow(String metin) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      child: pw.Text(metin, style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 11)),
    );
  }
}
