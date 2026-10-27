import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../widgets/tasarim_arka_plani.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../sinir_noktasi_model.dart';
import '../tarla_model.dart';

import '../utils/app_helpers.dart';
import 'screens.dart';
import '../database_helper.dart';
// Fallback for globals

class TarlaEkleSayfasi extends StatefulWidget {
  const TarlaEkleSayfasi({
    super.key,
    required this.onTarlaKaydet,
    this.mevcutTarla,
  });

  final Future<void> Function(Tarla tarla, List<SinirNoktasi> sinirNoktalari)
      onTarlaKaydet;
  final Tarla? mevcutTarla;

  @override
  State<TarlaEkleSayfasi> createState() => _TarlaEkleSayfasiState();
}

class _TarlaEkleSayfasiState extends State<TarlaEkleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final adController = TextEditingController();
  final urunController = TextEditingController();
  final alanController = TextEditingController();
  final notController = TextEditingController();
  bool kaydediliyor = false;
  bool konumAliniyor = false;
  double? secilenEnlem;
  double? secilenBoylam;
  List<String> secilenFotolar = [];
  List<SinirNoktasi> secilenSinirNoktalari = [];
  int aktifAdim = 0;

  bool get duzenlemeModu => widget.mevcutTarla != null;

  @override
  void initState() {
    super.initState();
    final mevcutTarla = widget.mevcutTarla;
    if (mevcutTarla == null) return;

    adController.text = mevcutTarla.ad;
    urunController.text = mevcutTarla.urun;
    alanController.text = mevcutTarla.alan;
    notController.text = mevcutTarla.notlar;
    secilenEnlem = mevcutTarla.enlem;
    secilenBoylam = mevcutTarla.boylam;
    secilenFotolar = fotoListesiCoz(mevcutTarla.fotoBase64);
    // Düzenleme modunda sınır noktalarını yükle
    if (mevcutTarla.id != null) {
      DatabaseHelper.instance.tarlaSinirNoktalari(mevcutTarla.id!).then((noktalar) {
        if (mounted) {
          setState(() {
            secilenSinirNoktalari = noktalar;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    adController.dispose();
    urunController.dispose();
    alanController.dispose();
    notController.dispose();
    super.dispose();
  }

  Future<Position> _mevcutKonumuGetir() async {
    final serviceEnabled = await konumServisiKapaliysaAyarlaraYonlendir(
      context,
      baslik: 'Konum hizmeti kapalı',
      aciklama:
          'Tarla konumunu alabilmek için konum hizmetini açman gerekiyor. İstersen şimdi ayarlara gidebilirsin.',
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
        amac: 'yeni tarla konumunu GPS ile almak',
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
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> mevcutKonumuAl() async {
    setState(() {
      konumAliniyor = true;
    });

    try {
      final position = await _mevcutKonumuGetir();
      if (!mounted) return;
      setState(() {
        secilenEnlem = position.latitude;
        secilenBoylam = position.longitude;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum alındı')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum alinamadi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          konumAliniyor = false;
        });
      }
    }
  }

  Future<void> haritadanKonumSec() async {
    final baslangicKonum = (secilenEnlem != null && secilenBoylam != null)
        ? LatLng(secilenEnlem!, secilenBoylam!)
        : const LatLng(39.0, 35.0); // Türkiye merkez
    final secilen = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(
        builder: (context) => TarlaKonumSecSayfasi(
          baslangicKonum: baslangicKonum,
        ),
      ),
    );
    if (secilen != null) {
      setState(() {
        secilenEnlem = secilen.latitude;
        secilenBoylam = secilen.longitude;
      });
    }
  }

  Future<void> fotoSec() async {
    try {
      final yeniFotolar = await galeridenFotografSec();
      if (yeniFotolar.isEmpty) {
        return;
      }
      if (!mounted) return;
      setState(() {
        secilenFotolar = [...secilenFotolar, ...yeniFotolar];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf seçilemedi: $error')),
      );
    }
  }

  Future<void> fotografCek() async {
    try {
      final yeniFoto = await kameradanFotografCek(context: context);
      if (yeniFoto == null || yeniFoto.isEmpty) return;
      if (!mounted) return;
      setState(() {
        secilenFotolar = [...secilenFotolar, yeniFoto];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotograf cekilemedi: $error')),
      );
    }
  }

  Future<void> sinirNoktalariDuzenle() async {
    final noktalar = await Navigator.push<List<SinirNoktasi>>(
      context,
      MaterialPageRoute(
        builder: (context) => TarlaUyduParselSayfasi(
          tarlaAdi: adController.text.trim().isEmpty
              ? 'Yeni Tarla'
              : adController.text.trim(),
          merkezEnlem: secilenEnlem,
          merkezBoylam: secilenBoylam,
          baslangicNoktalari: secilenSinirNoktalari,
        ),
      ),
    );
    if (noktalar == null) return;
    if (!mounted) return;
    setState(() {
      secilenSinirNoktalari = noktalar;
      if (noktalar.length >= 3) {
        final alan = parselAlaniMetrekare(noktalar);
        alanController.text = formatAlanOzeti(alanMetrekare: alan);
      }
    });
  }

  bool _aktifAdimGecerliMi() {
    if (aktifAdim == 0) {
      return _formKey.currentState?.validate() ?? false;
    }
    if (aktifAdim == 1) {
      if (secilenEnlem == null || secilenBoylam == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum adiminda merkez konum gerekli')),
        );
        return false;
      }
    }
    return true;
  }

  void adimIlerle() {
    if (!_aktifAdimGecerliMi()) return;
    if (!mounted) return;
    setState(() {
      aktifAdim = (aktifAdim + 1).clamp(0, 4);
    });
  }

  void adimGeri() {
    if (!mounted) return;
    setState(() {
      aktifAdim = (aktifAdim - 1).clamp(0, 4);
    });
  }

  Future<void> kaydet() async {
    if (!_formKey.currentState!.validate()) return;
    if (secilenEnlem == null || secilenBoylam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Once tarla konumunu alman gerekiyor')),
      );
      return;
    }

    setState(() {
      kaydediliyor = true;
    });

    bool basarili = false;
    try {
      final tarla = Tarla(
          id: widget.mevcutTarla?.id,
          remoteId: widget.mevcutTarla?.remoteId,
          ad: adController.text.trim(),
          urun: urunController.text.trim(),
          alan: alanController.text.trim(),
          alanMetrekare: widget.mevcutTarla?.alanMetrekare,
          alanDekar: widget.mevcutTarla?.alanDekar,
          enlem: secilenEnlem,
          boylam: secilenBoylam,
          notlar: notController.text.trim(),
          fotoBase64: fotoListesiniKaydet(secilenFotolar),
          sonSulama: widget.mevcutTarla?.sonSulama,
          sonGubre: widget.mevcutTarla?.sonGubre,
          sonIlac: widget.mevcutTarla?.sonIlac,
        );
      await widget.onTarlaKaydet(
        tarla,
        secilenSinirNoktalari,
      );
      basarili = true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              duzenlemeModu
                  ? 'Tarla guncellenemedi: $error'
                  : 'Tarla kaydedilemedi: $error',
            ),
          ),
        );
      }
    } finally {
      // Her durumda yukleniyor durumunu sifirla
      if (mounted) {
        setState(() {
          kaydediliyor = false;
        });
      }
    }

    if (basarili && mounted) {
      Navigator.pop(context, !duzenlemeModu);
    }
  }

  String _adimBaslik(int adim) {
    switch (adim) {
      case 0: return 'Temel bilgi';
      case 1: return 'Konum';
      case 2: return 'Sinir';
      case 3: return 'Foto / Not';
      case 4: return 'Onay';
      default: return '';
    }
  }

  String _adimAciklama(int adim) {
    switch (adim) {
      case 0: return 'Tarla adı zorunludur. Ürün ve alan bilgisi isteğe bağlıdır.';
      case 1: return 'Haritada konumunuzu işaretleyin.';
      case 2: return 'Sınır noktası isteğe bağlıdır. Çizersen alan otomatik hesaplanır.';
      case 3: return 'Not ve fotoğraflar isteğe bağlıdır.';
      case 4: return 'Kaydetmeden önce bilgileri son kez kontrol et.';
      default: return '';
    }
  }

  Widget _adimIcerigi(int adim, double? tahminiAlan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (adim) {
      case 0:
        return Column(
          children: [
            TextFormField(
              controller: adController,
              decoration: const InputDecoration(
                labelText: 'Tarla adı',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tarla adi bos olamaz';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: urunController,
              decoration: const InputDecoration(
                labelText: 'Ürün',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: alanController,
              decoration: const InputDecoration(
                labelText: 'Alan bilgisi',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merkez Konum:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    secilenEnlem == null || secilenBoylam == null
                        ? 'Konum henüz alınmadı'
                        : '${secilenEnlem!.toStringAsFixed(6)}, ${secilenBoylam!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: konumAliniyor ? null : mevcutKonumuAl,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E35),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      konumAliniyor ? 'Konum alınıyor...' : 'GPS ile Konum Al',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: haritadanKonumSec,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.map),
                    label: const Text('Haritadan Seç'),
                  ),
                ),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              child: Text(
                secilenSinirNoktalari.isEmpty
                    ? 'Henüz sınır noktası çizilmedi.'
                    : '${secilenSinirNoktalari.length} adet sınır noktası çizildi.',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            if (tahminiAlan != null) ...[
              const SizedBox(height: 12),
              Text(
                'Tahmini Alan: ${formatAlanOzeti(alanMetrekare: tahminiAlan)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: sinirNoktalariDuzenle,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E35),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Uydu Haritasında Düzenle'),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            TextFormField(
              controller: notController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Tarla notu',
                hintText: 'Bu tarlaya özel notlarını yazabilirsin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (kameraDestekleniyor)
                  FilledButton.icon(
                    onPressed: fotografCek,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E35)),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Fotoğraf Çek'),
                  ),
                FilledButton.icon(
                  onPressed: fotoSec,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E35)),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Galeriden Seç'),
                ),
                if (secilenFotolar.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        secilenFotolar = [];
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Fotoğrafları Temizle'),
                  ),
              ],
            ),
            if (secilenFotolar.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${secilenFotolar.length} fotoğraf eklendi', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64OnizlemeCoz(secilenFotolar[index]),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemCount: secilenFotolar.length,
                ),
              ),
            ],
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOnaySatiri('Tarla Adı', adController.text.trim()),
            _buildOnaySatiri('Ürün', urunController.text.trim().isEmpty ? '-' : urunController.text.trim()),
            _buildOnaySatiri('Konum', secilenEnlem == null || secilenBoylam == null ? 'Yok' : '${secilenEnlem!.toStringAsFixed(6)}, ${secilenBoylam!.toStringAsFixed(6)}'),
            _buildOnaySatiri('Sınır Noktası', '${secilenSinirNoktalari.length} nokta'),
            _buildOnaySatiri('Fotoğraf', '${secilenFotolar.length} adet'),
            if (notController.text.trim().isNotEmpty)
              _buildOnaySatiri('Not', notController.text.trim()),
            const SizedBox(height: 16),
            const Text(
              'Kaydet dediğinde tarla bilgileri ve varsa sınır noktaların birlikte güvenle kaydedilir.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => aktifAdim = 0),
                  child: const Text('Temel bilgiyi düzenle'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => aktifAdim = 1),
                  child: const Text('Konumu düzenle'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => aktifAdim = 3),
                  child: const Text('Not ve fotoğrafları düzenle'),
                ),
              ],
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOnaySatiri(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$baslik:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(deger)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tahminiAlan = secilenSinirNoktalari.length >= 3
        ? parselAlaniMetrekare(secilenSinirNoktalari)
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TasarimArkaPlani(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(duzenlemeModu ? 'Tarlayı Düzenle' : 'Tarla Ekle'),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Custom Horizontal Wizard Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162A1F) : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (index) {
                      final isCompleted = index < aktifAdim;
                      final isActive = index == aktifAdim;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Step Circle
                          GestureDetector(
                            onTap: () {
                              if (index <= aktifAdim || _aktifAdimGecerliMi()) {
                                setState(() {
                                  aktifAdim = index;
                                });
                              }
                            },
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: isCompleted
                                  ? const Color(0xFF4CAF50)
                                  : (isActive ? const Color(0xFF1B5E35) : Colors.grey.shade400),
                              child: isCompleted
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                          ),
                          // Connection line
                          if (index < 4)
                            Container(
                              width: math.max(0.0, (MediaQuery.sizeOf(context).width - 32 - 190) / 4),
                              height: 2,
                              color: index < aktifAdim ? const Color(0xFF4CAF50) : Colors.grey.shade300,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              
              // Active Step Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step Title & Description
                      Text(
                        _adimBaslik(aktifAdim),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _adimAciklama(aktifAdim),
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      
                      // Render step content
                      _adimIcerigi(aktifAdim, tahminiAlan),
                    ],
                  ),
                ),
              ),
              
              // Control buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (aktifAdim > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: adimGeri,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Geri'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: aktifAdim == 4 ? (kaydediliyor ? null : kaydet) : adimIlerle,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF1B5E35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          aktifAdim == 4
                              ? (kaydediliyor
                                  ? (duzenlemeModu ? 'Güncelleniyor...' : 'Kaydediliyor...')
                                  : (duzenlemeModu ? 'Güncelle ve Kaydet' : 'Kaydet'))
                              : 'Devam Et',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TarlaKonumSecSayfasi extends StatefulWidget {
  final LatLng baslangicKonum;
  const TarlaKonumSecSayfasi({super.key, required this.baslangicKonum});

  @override
  State<TarlaKonumSecSayfasi> createState() => _TarlaKonumSecSayfasiState();
}

class _TarlaKonumSecSayfasiState extends State<TarlaKonumSecSayfasi> {
  final _mapController = MapController();
  LatLng? _pinKonum;

  @override
  void initState() {
    super.initState();
    _pinKonum = widget.baslangicKonum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konumu Haritadan Seç'),
        actions: [
          if (_pinKonum != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _pinKonum),
              child: const Text('Konumu Seç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.baslangicKonum,
              initialZoom: 16,
              maxZoom: 22,
              onTap: (tapPosition, point) {
                setState(() {
                  _pinKonum = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.ali.tarlatakip',
                maxNativeZoom: 18,
                maxZoom: 22,
              ),
              if (_pinKonum != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pinKonum!,
                      width: 80,
                      height: 80,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Haritada tarla konumunu seçmek için istediğiniz yere dokunun ve yukarıdaki "Konumu Seç" butonuna basın.',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
