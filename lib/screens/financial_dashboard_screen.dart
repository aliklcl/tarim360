import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../cloud_sync_service.dart';
import '../database_helper.dart';
import '../gelir_model.dart';
import '../islem_model.dart';
import '../providers/auth_provider.dart';
import '../tarla_model.dart';
import '../services/pdf_report_service.dart';
import '../widgets/widgets.dart';

class FinancialDashboardScreen extends ConsumerStatefulWidget {
  const FinancialDashboardScreen({super.key, this.tarlaId});

  final int? tarlaId; // If null, show global stats

  @override
  ConsumerState<FinancialDashboardScreen> createState() => _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState extends ConsumerState<FinancialDashboardScreen> {
  bool _yukleniyor = true;
  double _toplamGelir = 0;
  double _toplamMaliyet = 0;
  List<Islem> _tumIslemler = [];
  List<Islem> _maliyetliIslemler = [];
  List<Gelir> _gelirler = [];
  Tarla? _aktifTarla;
  final Map<String, double> _turBazliMaliyetler = {};
  
  List<Tarla> _tarlalar = [];
  String _seciliGrup = 'gelir'; // 'gelir' veya 'gider'
  int? _seciliTarlaFiltresiId;

  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    setState(() => _yukleniyor = true);

    try {
      final db = DatabaseHelper.instance;
      List<Islem> tumIslemler = [];
      List<Gelir> tumGelirler = [];
      
      _tarlalar = await db.tumTarlalar();

      int? hedefTarlaId = widget.tarlaId ?? _seciliTarlaFiltresiId;

      if (hedefTarlaId != null) {
        tumIslemler = await db.tarlaIslemleri(hedefTarlaId);
        tumGelirler = await db.tarlaGelirleri(hedefTarlaId);
        _aktifTarla = _tarlalar.where((t) => t.id == hedefTarlaId).firstOrNull;
      } else {
        // Tum tarlalarin verisi
        _aktifTarla = null;
        for (var t in _tarlalar) {
          if (t.id != null) {
            tumIslemler.addAll(await db.tarlaIslemleri(t.id!));
            tumGelirler.addAll(await db.tarlaGelirleri(t.id!));
          }
        }
      }

      _tumIslemler = tumIslemler;
      _maliyetliIslemler = tumIslemler.where((i) => (i.maliyet ?? 0) > 0).toList();
      _gelirler = tumGelirler;

      _toplamGelir = _gelirler.fold(0, (sum, g) => sum + g.miktar);
      _toplamMaliyet = _maliyetliIslemler.fold(0, (sum, i) => sum + (i.maliyet ?? 0));

      _turBazliMaliyetler.clear();
      for (var islem in _maliyetliIslemler) {
        _turBazliMaliyetler[islem.tur] = (_turBazliMaliyetler[islem.tur] ?? 0) + (islem.maliyet ?? 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veriler yüklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const TasarimArkaPlani(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final double karZarar = _toplamGelir - _toplamMaliyet;
    final bool karda = karZarar >= 0;

    return DefaultTabController(
      length: 2,
      child: TasarimArkaPlani(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(widget.tarlaId == null ? 'Genel Finansal Durum' : 'Tarla Finansal Durumu'),
            bottom: TabBar(
              indicatorColor: const Color(0xFF2D6A4F),
              labelColor: const Color(0xFF2D6A4F),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelColor: Colors.grey.shade600,
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Genel Bakış'),
                Tab(icon: Icon(Icons.receipt_long_rounded), text: 'İşlem Geçmişi'),
              ],
            ),
            actions: [
              if (widget.tarlaId != null && _aktifTarla != null)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'PDF Raporu Al',
                  onPressed: () async {
                    setState(() => _yukleniyor = true);
                    try {
                      final aileAdi = ref.read(authProvider).value?.familyName ?? '';
                      final file = await PdfReportService.sezonlukRaporOlustur(
                        tarla: _aktifTarla!,
                        islemler: _tumIslemler,
                        gelirler: _gelirler,
                        aileAdi: aileAdi,
                      );
                      await Share.shareXFiles([XFile(file.path)], text: '${_aktifTarla!.ad} Sezonluk Finans Raporu');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapor olusturulamadi: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => _yukleniyor = false);
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.add_chart),
                tooltip: 'Gelir Ekle',
                onPressed: () => _gelirEkleDialog(context),
              )
            ],
          ),
          body: TabBarView(
            children: [
              _buildGenelBakisSekmesi(karZarar, karda),
              _buildIslemGecmisiSekmesi(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenelBakisSekmesi(double karZarar, bool karda) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── TARLA FİLTRE DROPDOWN ──────────────────────────────
          if (widget.tarlaId == null && _tarlalar.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int?>(
                value: _seciliTarlaFiltresiId,
                decoration: InputDecoration(
                  labelText: 'Tarla Filtresi',
                  prefixIcon: const Icon(Icons.filter_alt_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Tüm Tarlalar')),
                  ..._tarlalar.map((t) => DropdownMenuItem<int?>(
                    value: t.id,
                    child: Text(t.ad, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (id) {
                  setState(() => _seciliTarlaFiltresiId = id);
                  _verileriYukle();
                },
              ),
            ),

          // Ozet Kartlari
          Row(
            children: [
              Expanded(
                child: _ozetKarti(
                  'Toplam Gelir',
                  _toplamGelir,
                  const [Color(0xFF2D6A4F), Color(0xFF1B4332)],
                  Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ozetKarti(
                  'Toplam Maliyet',
                  _toplamMaliyet,
                  const [Color(0xFFB7094C), Color(0xFF892B64)],
                  Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Kar/Zarar Card with dynamic design
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: karda
                    ? [const Color(0xFF1B4332).withValues(alpha: 0.08), const Color(0xFF2D6A4F).withValues(alpha: 0.05)]
                    : [const Color(0xFFB7094C).withValues(alpha: 0.08), const Color(0xFF892B64).withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: karda 
                    ? const Color(0xFF2D6A4F).withValues(alpha: 0.2) 
                    : const Color(0xFFB7094C).withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        karda ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: karda ? const Color(0xFF2D6A4F) : const Color(0xFFB7094C),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        karda ? 'Net Kar' : 'Net Zarar',
                        style: TextStyle(
                          fontSize: 16,
                          color: karda ? const Color(0xFF2D6A4F) : const Color(0xFFB7094C),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFormat.format(karZarar.abs()),
                    style: TextStyle(
                      fontSize: 34,
                      color: karda ? const Color(0xFF2D6A4F) : const Color(0xFFB7094C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Maliyet Dagilimi (Pie Chart)
          if (_turBazliMaliyetler.isNotEmpty) ...[
            Text(
              'Maliyet Dağılımı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1B3B2B),
              ),
            ),
            const SizedBox(height: 16),
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
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 40,
                          sections: _turBazliMaliyetler.entries.map((e) {
                            final islemTuru = e.key;
                            final maliyet = e.value;
                            final percentage = _toplamMaliyet == 0 ? 0.0 : (maliyet / _toplamMaliyet) * 100;
                            final title = percentage < 1.0 ? '<1%' : '${percentage.toStringAsFixed(0)}%';

                            return PieChartSectionData(
                              color: _getColorForType(islemTuru),
                              value: maliyet,
                              title: title,
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Legend
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _turBazliMaliyetler.entries.map((e) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _getColorForType(e.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${e.key}: ${_currencyFormat.format(e.value)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              ),
              color: isDark ? const Color(0xFF162A1F) : Colors.white,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Henüz kayıtlı bir maliyet/gider bulunmuyor.',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Son Hareketler Summary
          Text(
            'Son Finansal Hareketler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B3B2B),
            ),
          ),
          const SizedBox(height: 10),
          _buildSonHareketlerListesi(),
        ],
      ),
    );
  }

  Widget _buildSonHareketlerListesi() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Combine incomes and expenses
    final List<Map<String, dynamic>> hareketler = [];
    
    for (var g in _gelirler) {
      hareketler.add({
        'isGelir': true,
        'baslik': g.aciklama.isEmpty ? 'Gelir' : g.aciklama,
        'tarih': g.tarih,
        'miktar': g.miktar,
        'original': g,
      });
    }
    
    for (var i in _maliyetliIslemler) {
      hareketler.add({
        'isGelir': false,
        'baslik': '${i.tur} İşlemi',
        'tarih': i.baslangicZamani ?? '',
        'miktar': i.maliyet ?? 0.0,
        'original': i,
      });
    }
    
    // Sort by date (descending)
    hareketler.sort((a, b) {
      DateTime parseDate(String d) {
        try {
          return DateFormat('dd.MM.yyyy HH:mm').parse(d);
        } catch (_) {
          try {
            return DateTime.parse(d);
          } catch (_) {
            return DateTime(1970);
          }
        }
      }
      return parseDate(b['tarih']).compareTo(parseDate(a['tarih']));
    });
    
    final sonBes = hareketler.take(5).toList();
    
    if (sonBes.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        color: isDark ? const Color(0xFF162A1F) : Colors.white,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Son finansal hareket bulunmuyor.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      color: isDark ? const Color(0xFF162A1F) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: sonBes.map((h) {
            final isGelir = h['isGelir'] as bool;
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGelir ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGelir ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isGelir ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              title: Text(h['baslik'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              subtitle: Text(h['tarih'] as String, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              trailing: Text(
                '${isGelir ? "+" : "-"}${_currencyFormat.format(h['miktar'])}',
                style: TextStyle(
                  color: isGelir ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIslemGecmisiSekmesi() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // Horizontal Tarla selector (only if widget.tarlaId is null)
        if (widget.tarlaId == null && _tarlalar.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(
                  label: const Text('Tüm Tarlalar'),
                  selected: _seciliTarlaFiltresiId == null,
                  selectedColor: const Color(0xFF2D6A4F),
                  labelStyle: TextStyle(
                    color: _seciliTarlaFiltresiId == null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _seciliTarlaFiltresiId = null;
                      });
                      _verileriYukle();
                    }
                  },
                ),
                const SizedBox(width: 8),
                ..._tarlalar.map((t) {
                  final isSelected = _seciliTarlaFiltresiId == t.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(t.ad),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2D6A4F),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _seciliTarlaFiltresiId = t.id;
                          });
                          _verileriYukle();
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Segmented Control for Income/Expense
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'gelir',
                  label: Text('Gelirler'),
                  icon: Icon(Icons.arrow_upward, color: Colors.green, size: 18),
                ),
                ButtonSegment(
                  value: 'gider',
                  label: Text('Giderler (Maliyetler)'),
                  icon: Icon(Icons.arrow_downward, color: Colors.red, size: 18),
                ),
              ],
              selected: {_seciliGrup},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _seciliGrup = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: const Color(0xFF2D6A4F).withValues(alpha: 0.15),
                selectedForegroundColor: const Color(0xFF2D6A4F),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // List View
        Expanded(
          child: _seciliGrup == 'gelir' ? _buildGelirlerListesi() : _buildGiderlerListesi(),
        ),
      ],
    );
  }

  Widget _buildGelirlerListesi() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_gelirler.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Kayıtlı gelir bulunmuyor.',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _gelirler.length,
      itemBuilder: (context, index) {
        final g = _gelirler[index];
        final tarlaAdi = _tarlalar.where((t) => t.id == g.tarlaId).firstOrNull?.ad ?? 'Bilinmeyen Tarla';
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
          color: isDark ? const Color(0xFF162A1F) : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward, color: Colors.green),
            ),
            title: Text(
              g.aciklama.isEmpty ? 'Gelir' : g.aciklama,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  '$tarlaAdi • ${g.tarih}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currencyFormat.format(g.miktar),
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                  onPressed: () => _gelirDuzenleDialog(context, g),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                  onPressed: () => _gelirSilOnayDialog(context, g),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGiderlerListesi() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_maliyetliIslemler.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Kayıtlı gider bulunmuyor.',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _maliyetliIslemler.length,
      itemBuilder: (context, index) {
        final i = _maliyetliIslemler[index];
        final tarlaAdi = _tarlalar.where((t) => t.id == i.tarlaId).firstOrNull?.ad ?? 'Bilinmeyen Tarla';
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
          color: isDark ? const Color(0xFF162A1F) : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_downward, color: Colors.red),
            ),
            title: Text(
              '${i.tur} İşlemi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  i.detay.isEmpty ? tarlaAdi : '$tarlaAdi • ${i.detay}',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  i.baslangicZamani ?? '',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            trailing: Text(
              _currencyFormat.format(i.maliyet),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  Future<void> _gelirSilOnayDialog(BuildContext context, Gelir gelir) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Gelir Silinsin mi?'),
        content: Text('"${gelir.aciklama.isEmpty ? 'Gelir' : gelir.aciklama}" kaydı kalıcı olarak silinecektir. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    
    if (onay == true && gelir.id != null) {
      final session = ref.read(authProvider).value;
      final tarla = _tarlalar.where((t) => t.id == gelir.tarlaId).firstOrNull;
      if (session != null && session.cloudEnabled && tarla != null) {
        await CloudSyncService.instance.gelirSil(
          session.familyAccessCode ?? session.sharedFarmCode ?? '',
          tarla,
          gelir.id!,
        );
      } else {
        await DatabaseHelper.instance.gelirSil(gelir.id!);
      }
      _verileriYukle();
    }
  }

  Future<void> _gelirDuzenleDialog(BuildContext context, Gelir gelir) async {
    final miktarController = TextEditingController(text: gelir.miktar.toString());
    final aciklamaController = TextEditingController(text: gelir.aciklama);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Geliri Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: miktarController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Miktar (TL)', prefixIcon: Icon(Icons.attach_money)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aciklamaController,
              decoration: const InputDecoration(labelText: 'Açıklama', prefixIcon: Icon(Icons.description_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              final miktar = double.tryParse(miktarController.text.replaceAll(',', '.'));
              if (miktar != null && miktar > 0) {
                final yeniGelir = Gelir(
                  id: gelir.id,
                  tarlaId: gelir.tarlaId,
                  tarih: gelir.tarih,
                  miktar: miktar,
                  aciklama: aciklamaController.text,
                );
                final session = ref.read(authProvider).value;
                final tarla = _tarlalar.where((t) => t.id == yeniGelir.tarlaId).firstOrNull;
                if (session != null && session.cloudEnabled && tarla != null) {
                  await CloudSyncService.instance.gelirGuncelle(
                    session.familyAccessCode ?? session.sharedFarmCode ?? '',
                    tarla,
                    yeniGelir,
                  );
                } else {
                  await DatabaseHelper.instance.gelirGuncelle(yeniGelir);
                }
                if (context.mounted) Navigator.pop(context);
                _verileriYukle();
              }
            },
            child: const Text('Güncelle'),
          )
        ],
      ),
    );
    miktarController.dispose();
    aciklamaController.dispose();
  }

  Widget _ozetKarti(String baslik, double miktar, List<Color> gradientColors, IconData ikon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                Icon(ikon, color: Colors.white70, size: 20),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _currencyFormat.format(miktar),
              style: const TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'sulama': return Colors.blue.shade600;
      case 'gubre': return Colors.orange.shade700;
      case 'ilac': return Colors.purple.shade600;
      case 'budama': return Colors.amber.shade800;
      case 'hasat': return Colors.teal.shade600;
      case 'surum': return Colors.brown.shade600;
      default: return Colors.blueGrey;
    }
  }

  Future<void> _gelirEkleDialog(BuildContext context) async {
    final miktarController = TextEditingController();
    final aciklamaController = TextEditingController();
    int? seciliTarlaId = widget.tarlaId;
    DateTime seciliTarih = DateTime.now();
    
    final db = DatabaseHelper.instance;
    final tarlalar = await db.tumTarlalar();

    if (!mounted) return;
    final outerContext = context;
    // ignore: use_build_context_synchronously
    await showDialog(
      // ignore: use_build_context_synchronously
      context: outerContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Gelir Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tarlaId == null) ...[
                DropdownButtonFormField<int>(
                // ignore: deprecated_member_use
                  value: seciliTarlaId,
                  decoration: const InputDecoration(labelText: 'Tarla Seçin', prefixIcon: Icon(Icons.landscape_rounded)),
                  items: tarlalar.map((t) => DropdownMenuItem(value: t.id, child: Text(t.ad))).toList(),
                  onChanged: (val) {
                    setModalState(() {
                      seciliTarlaId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: miktarController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Miktar (TL)', prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aciklamaController,
                decoration: const InputDecoration(labelText: 'Açıklama (Örn: Buğday Hasatı)'),
              ),
              const SizedBox(height: 12),
              // Tarih seçici
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: outerContext,
                    initialDate: seciliTarih,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setModalState(() => seciliTarih = picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd.MM.yyyy').format(seciliTarih),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                final miktar = double.tryParse(miktarController.text.replaceAll(',', '.'));
                if (seciliTarlaId != null && miktar != null && miktar > 0) {
                  final gelir = Gelir(
                    tarlaId: seciliTarlaId!,
                    tarih: DateFormat('dd.MM.yyyy HH:mm').format(seciliTarih),
                    miktar: miktar,
                    aciklama: aciklamaController.text,
                  );
                  final session = ref.read(authProvider).value;
                  final tarla = _tarlalar.where((t) => t.id == seciliTarlaId).firstOrNull;
                  if (session != null && session.cloudEnabled && tarla != null) {
                    await CloudSyncService.instance.gelirEkle(
                      session.familyAccessCode ?? session.sharedFarmCode ?? '',
                      tarla,
                      gelir,
                    );
                  } else {
                    await DatabaseHelper.instance.gelirEkle(gelir);
                  }
                  if (context.mounted) Navigator.pop(context);
                  _verileriYukle();
                }
              },
              child: const Text('Kaydet'),
            )
          ],
        ),
      ),
    );
    miktarController.dispose();
    aciklamaController.dispose();
  }
}
