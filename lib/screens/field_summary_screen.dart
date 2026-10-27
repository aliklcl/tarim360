import '../widgets/widgets.dart';

import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../islem_turu_model.dart';
import '../app_session_service.dart';
import '../islem_model.dart';
import '../tarla_model.dart';

import '../utils/app_helpers.dart';

// Sekme enum
enum _OzetSekme { tumTarlalar, hatirlatmalar, ekipKayitlari }

class TarlaOzetSayfasi extends StatefulWidget {
  const TarlaOzetSayfasi({
    super.key,
    required this.baslangicTarlalari,
    required this.aileKodu,
  });

  final List<Tarla> baslangicTarlalari;
  final String aileKodu;

  @override
  State<TarlaOzetSayfasi> createState() => _TarlaOzetSayfasiState();
}

class _TarlaOzetSayfasiState extends State<TarlaOzetSayfasi> {
  List<Tarla> tarlalar = [];
  bool yukleniyor = true;
  Map<int, List<Islem>> tarlaIslemleri = {};
  Map<String, int> aileUyesiRaporu = {};
  _OzetSekme aktifSekme = _OzetSekme.tumTarlalar;
  List<IslemTuruTanim> ozelIslemTurleri = [];

  @override
  void initState() {
    super.initState();
    tarlalar = widget.baslangicTarlalari;
    ozetiYukle();
  }

  Future<void> ozetiYukle() async {
    final yeniTarlalar = await DatabaseHelper.instance.tumTarlalar();
    final yeniOzelTipler = await AppSessionService.ozelIslemTurleriniGetir(widget.aileKodu);
    final yeniTarlaIslemleri = <int, List<Islem>>{};
    final yeniAileUyesiRaporu = <String, int>{};
    for (final tarla in yeniTarlalar) {
      final tarlaId = tarla.id;
      if (tarlaId == null) continue;
      final islemler = await DatabaseHelper.instance.tarlaIslemleri(tarlaId);
      yeniTarlaIslemleri[tarlaId] = islemler;
      for (final islem in islemler) {
        final kullanici = islem.kullaniciAdi.trim().isEmpty
            ? 'Bilinmeyen'
            : islem.kullaniciAdi.trim();
        yeniAileUyesiRaporu[kullanici] =
            (yeniAileUyesiRaporu[kullanici] ?? 0) + 1;
      }
    }

    if (!mounted) return;
    setState(() {
      tarlalar = yeniTarlalar;
      tarlaIslemleri = yeniTarlaIslemleri;
      aileUyesiRaporu = yeniAileUyesiRaporu;
      ozelIslemTurleri = yeniOzelTipler;
      yukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hatırlatma eşiği: 3 gün (daha erişilebilir)
    final hatirlamaListesi = tarlalar
        .where((t) =>
            t.sonSulama == null ||
            turkiyeSimdi().difference(t.sonSulama!).inDays >= sulamaKritikGunSiniri)
        .toList();

    final siraliUyeRaporu = aileUyesiRaporu.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return TasarimArkaPlani(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Tarla Özeti'),
          centerTitle: true,
          elevation: 0,
        ),
        body: yukleniyor
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: ozetiYukle,
                child: tarlalar.isEmpty
                    ? _buildEmptyState(isDark, textColor, subTextColor)
                    : _buildContent(
                        hatirlamaListesi,
                        siraliUyeRaporu,
                        isDark,
                        textColor,
                        subTextColor,
                      ),
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 80,
                color: isDark ? Colors.white54 : Colors.black38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Rapor bulunamadı',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz tarla eklemediğiniz için özet raporu oluşturulamıyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subTextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    List<Tarla> hatirlamaListesi,
    List<MapEntry<String, int>> siraliUyeRaporu,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    String sampiyonMetni = '';
    if (siraliUyeRaporu.isNotEmpty) {
      final enCok = siraliUyeRaporu.first.value;
      final sampiyonlar = siraliUyeRaporu
          .where((u) => u.value == enCok)
          .map((u) => u.key)
          .join(' ve ');
      sampiyonMetni = '$sampiyonlar ($enCok işlem)';
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ─── SEKME BAR ─────────────────────────────────────────────────
        _buildSekmeBar(hatirlamaListesi.length, siraliUyeRaporu.length, isDark, textColor),
        const SizedBox(height: 18),

        // ─── İÇERİK: SEÇİLİ SEKMEYE GÖRE ──────────────────────────────
        if (aktifSekme == _OzetSekme.hatirlatmalar) ...[
          if (hatirlamaListesi.isEmpty)
            _buildBosAlan(
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              ikon: Icons.check_circle_outline_rounded,
              ikonRenk: Colors.green,
              baslik: 'Tüm Tarlalar Güncel',
              aciklama: 'Son 3 gün içinde sulanan tüm tarlalar için hatırlatma bulunmuyor.',
            )
          else
            _buildPremiumCard(
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              title: 'Sulama Bekleyen Tarlalar (${hatirlamaListesi.length})',
              icon: Icons.notifications_active_rounded,
              iconColor: Colors.orange.shade600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final tarla in hatirlamaListesi)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50.withValues(alpha: isDark ? 0.1 : 1.0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200.withValues(alpha: isDark ? 0.2 : 1.0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.water_drop_outlined, size: 18, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tarla.ad,
                                    style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tarla.sonSulama == null
                                        ? 'Sulama kaydı yok'
                                        : '${turkiyeSimdi().difference(tarla.sonSulama!).inDays} gündür sulanmadı',
                                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],

        if (aktifSekme == _OzetSekme.ekipKayitlari) ...[
          if (siraliUyeRaporu.isEmpty)
            _buildBosAlan(
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              ikon: Icons.people_outline_rounded,
              ikonRenk: Colors.blue,
              baslik: 'Ekip Kaydı Yok',
              aciklama: 'Henüz işlem kaydı bulunmuyor. İşlem eklenince ekip istatistikleri burada görünür.',
            )
          else
            _buildPremiumCard(
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              title: 'Ekip Kayıt Özeti',
              icon: Icons.groups_rounded,
              iconColor: Colors.blue.shade600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'En çok kayıt giren:\n$sampiyonMetni',
                            style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tablo görünümü
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Başlık satırı
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Kullanıcı',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'İşlem Sayısı',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Veri satırları
                        for (int i = 0; i < siraliUyeRaporu.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: i.isEven
                                  ? Colors.transparent
                                  : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                              border: Border(
                                top: BorderSide(
                                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      if (i == 0)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(Icons.emoji_events_rounded, size: 16, color: Colors.amber),
                                        ),
                                      Flexible(
                                        child: Text(
                                          siraliUyeRaporu[i].key,
                                          style: TextStyle(
                                            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.normal,
                                            color: textColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${siraliUyeRaporu[i].value} işlem',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],

        if (aktifSekme == _OzetSekme.tumTarlalar) ...[
          // Özet istatistikler
          _buildOzetIstatistikler(isDark, textColor, subTextColor),
          const SizedBox(height: 12),
          // Hatırlatma banner (varsa)
          if (hatirlamaListesi.isNotEmpty)
            _buildHatirlatmaBanner(hatirlamaListesi.length, isDark),
          // Tarla kartları
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              'Tarla Durumları',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          for (final tarla in tarlalar)
            Builder(
              builder: (context) {
                final ozet = tarlaSezonOzetiHesapla(
                  tarla,
                  tarlaIslemleri[tarla.id] ?? const [],
                  ozelTipler: ozelIslemTurleri,
                );
                return _buildPremiumCard(
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  title: tarla.ad,
                  icon: Icons.landscape_rounded,
                  iconColor: const Color(0xFF3D8C40),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: aciliyetRengi(tarla).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      aciliyetMetni(tarla),
                      style: TextStyle(
                        color: aciliyetRengi(tarla),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tarla.urun.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(Icons.eco_rounded, size: 15, color: Colors.green.shade600),
                              const SizedBox(width: 6),
                              Text(
                                tarla.urun,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                              ),
                              if (tarla.alan.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text('• ${tarla.alan}', style: TextStyle(color: subTextColor, fontSize: 13)),
                              ],
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 15, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Son işlem: ${sonIslemEtiketi(tarla)}',
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 15, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            sonIslemTarihi(tarla) != null
                                ? formatTarihSaat(sonIslemTarihi(tarla)!)
                                : 'Kayıt yok',
                            style: TextStyle(color: subTextColor, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _islemCipi(
                            Icons.water_drop_rounded,
                            Colors.blue,
                            '${ozet.sulamaSayisi} sulama',
                            isDark,
                          ),
                          _islemCipi(
                            Icons.compost_rounded,
                            Colors.green,
                            '${ozet.gubreSayisi} gübre',
                            isDark,
                          ),
                          _islemCipi(
                            Icons.science_rounded,
                            Colors.deepOrange,
                            '${ozet.ilacSayisi} ilaç',
                            isDark,
                          ),
                          if ((tarlaIslemleri[tarla.id]?.length ?? 0) > 0)
                            _islemCipi(
                              Icons.list_alt_rounded,
                              Colors.purple,
                              '${tarlaIslemleri[tarla.id]!.length} toplam',
                              isDark,
                            ),
                          // Custom işlem tipi chip'leri
                          ...(() {
                            final islemler = tarlaIslemleri[tarla.id] ?? [];
                            final sayac = <String, int>{};
                            for (final islem in islemler) {
                              final ozel = ozelIslemTurleri.where((t) => t.ad == islem.tur);
                              if (ozel.isNotEmpty) {
                                sayac[islem.tur] = (sayac[islem.tur] ?? 0) + 1;
                              }
                            }
                            return sayac.entries.map((e) {
                              final tip = ozelIslemTurleri.firstWhere((t) => t.ad == e.key);
                              return _islemCipi(
                                islemTuruIkonunuGetir(tip.iconKey),
                                Color(tip.colorValue),
                                '${e.value} ${e.key}',
                                isDark,
                              );
                            });
                          })(),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  // ─── SEKME BAR ─────────────────────────────────────────────────────────────

  Widget _buildSekmeBar(int hatirlamaCount, int ekipCount, bool isDark, Color textColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSekme(
            _OzetSekme.tumTarlalar,
            'Tümü',
            Icons.grid_view_rounded,
            isDark,
            textColor,
            badge: tarlalar.length,
          ),
          const SizedBox(width: 8),
          _buildSekme(
            _OzetSekme.hatirlatmalar,
            'Hatırlatmalar',
            Icons.notifications_active_rounded,
            isDark,
            textColor,
            badge: hatirlamaCount,
            badgeColor: Colors.orange,
          ),
          const SizedBox(width: 8),
          _buildSekme(
            _OzetSekme.ekipKayitlari,
            'Ekip Kayıtları',
            Icons.groups_rounded,
            isDark,
            textColor,
            badge: ekipCount,
            badgeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildSekme(
    _OzetSekme sekme,
    String etiket,
    IconData ikon,
    bool isDark,
    Color textColor, {
    int badge = 0,
    Color badgeColor = const Color(0xFF2D6A4F),
  }) {
    final secili = aktifSekme == sekme;
    return GestureDetector(
      onTap: () => setState(() => aktifSekme = sekme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: secili
              ? const Color(0xFF2D6A4F)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(22),
          border: secili
              ? null
              : Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 16, color: secili ? Colors.white : textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              etiket,
              style: TextStyle(
                color: secili ? Colors.white : textColor,
                fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: secili ? Colors.white.withValues(alpha: 0.25) : badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secili ? Colors.white : badgeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── ÖZET İSTATİSTİKLER ────────────────────────────────────────────────────

  Widget _buildOzetIstatistikler(bool isDark, Color textColor, Color subTextColor) {
    final toplamIslem = tarlaIslemleri.values.fold<int>(0, (s, l) => s + l.length);
    final hatirlamaCount = tarlalar
        .where((t) =>
            t.sonSulama == null ||
            turkiyeSimdi().difference(t.sonSulama!).inDays >= sulamaKritikGunSiniri)
        .length;

    return Row(
      children: [
        Expanded(child: _miniIstatKarti('${tarlalar.length}', 'Tarla', Icons.landscape_rounded, const Color(0xFF2D6A4F), isDark, textColor, subTextColor)),
        const SizedBox(width: 10),
        Expanded(child: _miniIstatKarti('$toplamIslem', 'İşlem', Icons.list_alt_rounded, Colors.blue.shade700, isDark, textColor, subTextColor)),
        const SizedBox(width: 10),
        Expanded(child: _miniIstatKarti('$hatirlamaCount', 'Sulama Bekleyen', Icons.water_drop_rounded, Colors.orange.shade700, isDark, textColor, subTextColor)),
      ],
    );
  }

  Widget _miniIstatKarti(
    String deger,
    String baslik,
    IconData ikon,
    Color renk,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A1F) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: renk),
          const SizedBox(height: 8),
          Text(deger, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
          Text(baslik, style: TextStyle(fontSize: 11, color: subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ─── HATIRLATMA BANNER ─────────────────────────────────────────────────────

  Widget _buildHatirlatmaBanner(int count, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => aktifSekme = _OzetSekme.hatirlatmalar),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50.withValues(alpha: isDark ? 0.15 : 1.0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.shade200.withValues(alpha: isDark ? 0.3 : 1.0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count tarla sulama bekliyor. Detayları görmek için tıkla.',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  // ─── BOŞ ALAN ──────────────────────────────────────────────────────────────

  Widget _buildBosAlan({
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required IconData ikon,
    required Color ikonRenk,
    required String baslik,
    required String aciklama,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(ikon, size: 52, color: ikonRenk.withValues(alpha: 0.7)),
          const SizedBox(height: 14),
          Text(baslik, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text(aciklama, textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  // ─── PREMIUM KART ──────────────────────────────────────────────────────────

  Widget _buildPremiumCard({
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A1F) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ─── İŞLEM CİPİ ───────────────────────────────────────────────────────────

  Widget _islemCipi(IconData ikon, Color renk, String metin, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withValues(alpha: isDark ? 0.25 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: renk),
          const SizedBox(width: 5),
          Text(
            metin,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: renk),
          ),
        ],
      ),
    );
  }
}
