import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../sinir_noktasi_model.dart';

import '../utils/app_helpers.dart';

class TarlaUyduParselSayfasi extends StatefulWidget {
  const TarlaUyduParselSayfasi({
    super.key,
    required this.tarlaAdi,
    required this.merkezEnlem,
    required this.merkezBoylam,
    required this.baslangicNoktalari,
  });

  final String tarlaAdi;
  final double? merkezEnlem;
  final double? merkezBoylam;
  final List<SinirNoktasi> baslangicNoktalari;

  @override
  State<TarlaUyduParselSayfasi> createState() => _TarlaUyduParselSayfasiState();
}

class _TarlaUyduParselSayfasiState extends State<TarlaUyduParselSayfasi> {
  final mapController = MapController();

  /// false = nokta-nokta mod, true = serbest çizim modu
  bool _serbestCizimModu = false;

  late final List<SinirNoktasi> noktalar = widget.baslangicNoktalari
      .map(
        (nokta) => SinirNoktasi(
          tarlaId: nokta.tarlaId,
          enlem: nokta.enlem,
          boylam: nokta.boylam,
        ),
      )
      .toList();

  /// Sadece nokta-nokta modda seçili nokta indeksi geçerlidir.
  int? seciliNoktaIndex;

  LatLng get merkez {
    if (noktalar.isNotEmpty) {
      final ortalamaEnlem =
          noktalar.map((e) => e.enlem).reduce((a, b) => a + b) / noktalar.length;
      final ortalamaBoylam =
          noktalar.map((e) => e.boylam).reduce((a, b) => a + b) / noktalar.length;
      return LatLng(ortalamaEnlem, ortalamaBoylam);
    }
    return LatLng(widget.merkezEnlem ?? 39.0, widget.merkezBoylam ?? 35.0);
  }

  Future<void> gpsNoktasiEkle() async {
    try {
      final serviceEnabled = await konumServisiKapaliysaAyarlaraYonlendir(
        context,
        baslik: 'Konum hizmeti kapalı',
        aciklama: 'GPS noktası eklemek için konum hizmetini açman gerekiyor.',
      );
      if (!mounted) throw Exception('Ekran kapandi');
      if (!serviceEnabled) throw Exception('Konum servisi kapali');

      var permission = await Geolocator.checkPermission();
      if (!mounted) throw Exception('Ekran kapandi');
      if (permission == LocationPermission.denied) {
        final izinIstensin = await konumBilgilendirmesiniGoster(
          context,
          amac: 'sinir noktasi eklemek icin anlik GPS konumunu almak',
        );
        if (!izinIstensin) throw Exception('Konum izni istegi iptal edildi');
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (permission == LocationPermission.deniedForever) {
          if (!mounted) throw Exception('Ekran kapandi');
          await kaliciReddedilenKonumIzniIcinAyarlaraYonlendir(context);
        }
        throw Exception('Konum izni verilmedi');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        final yeniNokta = SinirNoktasi(
          tarlaId: 0,
          enlem: position.latitude,
          boylam: position.longitude,
        );
        if (seciliNoktaIndex != null &&
            seciliNoktaIndex! >= 0 &&
            seciliNoktaIndex! < noktalar.length) {
          noktalar[seciliNoktaIndex!] = yeniNokta;
          seciliNoktaIndex = null;
        } else {
          noktalar.add(yeniNokta);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS noktasi eklenemedi: $error')),
      );
    }
  }

  Future<void> konumumaGit() async {
    try {
      final serviceEnabled = await konumServisiKapaliysaAyarlaraYonlendir(
        context,
        baslik: 'Konum hizmeti kapalı',
        aciklama: 'Bulunduğun konuma gitmek için konum hizmetini açman gerekiyor.',
      );
      if (!mounted) return;
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      mapController.move(LatLng(position.latitude, position.longitude), 17.5);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum alınamadı: $error')),
      );
    }
  }

  void _serbestCizimeNoktaEkle(Offset localPosition) {
    try {
      final latlng = mapController.camera.screenOffsetToLatLng(localPosition);
      if (noktalar.isNotEmpty) {
        final son = noktalar.last;
        final dist = const Distance().as(
          LengthUnit.Meter,
          LatLng(son.enlem, son.boylam),
          latlng,
        );
        if (dist < 3.0) return; // Her 3 metrede bir nokta ekle — daha az nokta, daha temiz çizgi
      }
      setState(() {
        noktalar.add(SinirNoktasi(tarlaId: 0, enlem: latlng.latitude, boylam: latlng.longitude));
        seciliNoktaIndex = null;
      });
    } catch (_) {
      // Safely ignore if map camera is not ready yet
    }
  }

  @override
  Widget build(BuildContext context) {
    final noktaListesi = noktalar
        .map((e) => LatLng(e.enlem, e.boylam))
        .toList(growable: false);
    final alanMetrekare = parselAlaniMetrekare(noktalar);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tarlaAdi),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(noktalar),
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ─── Harita ───────────────────────────────────────────────
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: merkez,
              initialZoom: 17.5,
              maxZoom: 22,
              // Serbest çizim modunda harita sürükleme devre dışı
              interactionOptions: InteractionOptions(
                flags: _serbestCizimModu
                    ? InteractiveFlag.all & ~InteractiveFlag.drag & ~InteractiveFlag.doubleTapZoom
                    : InteractiveFlag.all,
              ),
              onTap: (_, point) {
                if (_serbestCizimModu) return;
                setState(() {
                  final yeniNokta = SinirNoktasi(
                    tarlaId: 0,
                    enlem: point.latitude,
                    boylam: point.longitude,
                  );
                  if (seciliNoktaIndex != null &&
                      seciliNoktaIndex! >= 0 &&
                      seciliNoktaIndex! < noktalar.length) {
                    noktalar[seciliNoktaIndex!] = yeniNokta;
                    seciliNoktaIndex = null;
                  } else {
                    noktalar.add(yeniNokta);
                  }
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
              // Tarlayı dolduran yeşil polygon
              if (noktaListesi.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: noktaListesi,
                      color: Colors.green.withValues(alpha: 0.22),
                      borderStrokeWidth: 2.5,
                      borderColor: Colors.green.shade500,
                    ),
                  ],
                ),
              // Kapatma çizgisi (serbest çizimde yeterli)
              if (noktaListesi.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        ...noktaListesi,
                        if (noktaListesi.length >= 3) noktaListesi.first,
                      ],
                      strokeWidth: 2.5,
                      color: Colors.green.shade600,
                    ),
                  ],
                ),
              // Noktalar: serbest çizim modunda sadece ilk/son/merkez gösterilir
              // Nokta-nokta modunda tüm noktalar numara ile gösterilir
              MarkerLayer(
                markers: [
                  // Kayıtlı merkez işareti (kırmızı pin) — her zaman görünür
                  if (widget.merkezEnlem != null && widget.merkezBoylam != null)
                    Marker(
                      point: LatLng(widget.merkezEnlem!, widget.merkezBoylam!),
                      width: 32,
                      height: 32,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 28),
                    ),

                  // Serbest çizim modunda sadece ilk ve son noktayı göster
                  if (_serbestCizimModu && noktaListesi.isNotEmpty)
                    _kucukNoktaMarkeri(noktaListesi.first, 'B', Colors.blue.shade700),

                  if (_serbestCizimModu && noktaListesi.length > 1)
                    _kucukNoktaMarkeri(noktaListesi.last, '...', Colors.orange.shade700),

                  // Nokta-nokta modunda tüm noktaları profesyonel küçük CAD halkaları olarak göster
                  if (!_serbestCizimModu)
                    for (var i = 0; i < noktaListesi.length; i++)
                      Marker(
                        point: noktaListesi[i],
                        width: seciliNoktaIndex == i ? 26 : 12,
                        height: seciliNoktaIndex == i ? 26 : 12,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            seciliNoktaIndex = seciliNoktaIndex == i ? null : i;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              color: seciliNoktaIndex == i
                                  ? Colors.orange.shade700
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: seciliNoktaIndex == i 
                                    ? Colors.white 
                                    : Colors.green.shade700,
                                width: seciliNoktaIndex == i ? 2.5 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: seciliNoktaIndex == i
                                ? Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),

          // ─── Serbest Çizim Gesture Katmanı ────────────────────────
          if (_serbestCizimModu)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) => _serbestCizimeNoktaEkle(details.localPosition),
                onPanUpdate: (details) => _serbestCizimeNoktaEkle(details.localPosition),
                child: Container(color: Colors.transparent),
              ),
            ),

          // ─── Üst Bilgi Bandı ──────────────────────────────────────
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              color: Colors.black.withValues(alpha: 0.72),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Nokta sayısı rozeti
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _serbestCizimModu
                            ? Colors.orange.withValues(alpha: 0.30)
                            : Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${noktalar.length} nokta',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _serbestCizimModu
                            ? '✏️ Parmağını sürükleyerek çiz. Yakınlaştırmak/Konum için sağdaki + - 🎯 tuşlarını kullan.'
                            : noktalar.length >= 3
                                ? '${formatAlanOzeti(alanMetrekare: alanMetrekare)}\n📍 Haritaya dokunarak nokta ekle/düzenle.'
                                : '📍 Haritaya dokunarak nokta ekle. Min. 3 nokta gerekli.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Mod Değiştir Butonu (sağ orta) ──────────────────────
          Positioned(
            right: 10,
            top: 90,
            child: _modButonu(),
          ),

          // ─── Yakınlaştırma & Konum Kontrolleri ──────────────────
          Positioned(
            right: 10,
            top: 150,
            child: Column(
              children: [
                // Yakınlaştır (+)
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      final currentZoom = mapController.camera.zoom;
                      if (currentZoom < 22) {
                        mapController.move(mapController.camera.center, currentZoom + 0.5);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.add, color: Color(0xFF1B5E35), size: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Uzaklaştır (-)
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      final currentZoom = mapController.camera.zoom;
                      if (currentZoom > 1) {
                        mapController.move(mapController.camera.center, currentZoom - 0.5);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.remove, color: Color(0xFF1B5E35), size: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Konumuma Git (🎯)
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: konumumaGit,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.my_location, color: Color(0xFF1B5E35), size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Alt Aksiyon Butonları ────────────────────────────────
          Positioned(
            left: 10,
            right: 10,
            bottom: 16,
            child: Row(
              children: [
                // GPS Nokta — sadece nokta-nokta modda
                if (!_serbestCizimModu)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: gpsNoktasiEkle,
                      icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                      label: const Text('GPS'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (!_serbestCizimModu) const SizedBox(width: 8),

                // Geri al / Seçimi bırak
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _serbestCizimModu
                        ? (noktalar.isEmpty
                            ? null
                            : () => setState(() => noktalar.removeLast()))
                        : seciliNoktaIndex != null
                            ? () => setState(() => seciliNoktaIndex = null)
                            : noktalar.isEmpty
                                ? null
                                : () => setState(() => noktalar.removeLast()),
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(
                      (!_serbestCizimModu && seciliNoktaIndex != null) ? 'Bırak' : 'Geri',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Temizle
                Expanded(
                  child: FilledButton.icon(
                    onPressed: noktalar.isEmpty
                        ? null
                        : () => setState(() {
                              noktalar.clear();
                              seciliNoktaIndex = null;
                            }),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7B352C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Temizle'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Serbest çizim / Nokta-Nokta geçiş butonu
  Widget _modButonu() {
    return Material(
      color: _serbestCizimModu ? Colors.orange.shade700 : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _serbestCizimModu = !_serbestCizimModu;
          if (_serbestCizimModu) seciliNoktaIndex = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _serbestCizimModu ? Icons.touch_app : Icons.gesture,
                color: _serbestCizimModu ? Colors.white : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                _serbestCizimModu ? 'Nokta Nokta' : 'Serbest Çizim',
                style: TextStyle(
                  color: _serbestCizimModu ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Serbest çizimde küçük etiket marker
  Marker _kucukNoktaMarkeri(LatLng point, String label, Color color) {
    return Marker(
      point: point,
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
