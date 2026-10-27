
import 'package:flutter/material.dart';

import '../app_session_service.dart';
import '../cloud_sync_service.dart';
import '../islem_turu_model.dart';
import '../widgets/tasarim_arka_plani.dart';

// Fallback for globals

class IslemTurleriSayfasi extends StatefulWidget {
  const IslemTurleriSayfasi({
    super.key,
    required this.aileKodu,
    required this.bulutEtkin,
  });

  final String aileKodu;
  final bool bulutEtkin;

  @override
  State<IslemTurleriSayfasi> createState() => _IslemTurleriSayfasiState();
}

class _IslemTurleriSayfasiState extends State<IslemTurleriSayfasi> {
  List<IslemTuruTanim> ozelTipler = [];
  bool yukleniyor = true;
  bool kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    tipleriYukle();
  }

  List<IslemTuruTanim> get tumTipler => tumIslemTurleriniBirlestir(ozelTipler);

  Future<void> tipleriYukle() async {
    try {
      final tipler = widget.bulutEtkin
          ? await CloudSyncService.instance.ozelIslemTurleriniGetir(widget.aileKodu)
          : await AppSessionService.ozelIslemTurleriniGetir(widget.aileKodu);
      if (!mounted) return;
      setState(() {
        ozelTipler = tipler;
        yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        yukleniyor = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İşlem tipleri yüklenemedi'),
        ),
      );
    }
  }

  Future<void> tipleriKaydet(List<IslemTuruTanim> tipler) async {
    setState(() {
      kaydediliyor = true;
    });
    try {
      if (widget.bulutEtkin) {
        await CloudSyncService.instance.ozelIslemTurleriniKaydet(
          widget.aileKodu,
          tipler,
        );
      } else {
        await AppSessionService.ozelIslemTurleriniKaydet(
          widget.aileKodu,
          tipler,
        );
      }
      if (!mounted) return;
      setState(() {
        ozelTipler = tipler;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İşlem tipleri güncellendi'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İşlem tipleri kaydedilemedi'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          kaydediliyor = false;
        });
      }
    }
  }

  Future<void> tipEkle() async {
    final adController = TextEditingController();
    var seciliIkon = (kullanilabilirIslemIkonlari.first['key'] as String?) ?? 'inventory';
    var seciliRenk = (kullanilabilirIslemRenkleri.first['value'] as int?) ?? 0xFF607D8B;
    var seciliKategori = '';  // '' = Diger, 'Sulama', 'Gubre', 'Ilac'
    String? hataMetni;

    final yeniTip = await showDialog<IslemTuruTanim>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni işlem tipi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: adController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'İşlem adı',
                    hintText: 'Hasat',
                    errorText: hataMetni,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: seciliIkon,
                  decoration: const InputDecoration(
                    labelText: 'İkon',
                  ),
                  items: kullanilabilirIslemIkonlari
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item['key'] as String,
                          child: Row(
                            children: [
                              Icon(item['icon'] as IconData),
                              const SizedBox(width: 8),
                              Text(item['label'] as String),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      seciliIkon = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: seciliRenk,
                  decoration: const InputDecoration(
                    labelText: 'Renk',
                  ),
                  items: kullanilabilirIslemRenkleri
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item['value'] as int,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Color(item['value'] as int),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(item['label'] as String),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      seciliRenk = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: seciliKategori,
                  decoration: const InputDecoration(labelText: 'Ana Kategori (sulama/gubre takibi)'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Diger - genel islem')),
                    const DropdownMenuItem(value: 'Sulama', child: Text('Sulama gibi say')),
                    const DropdownMenuItem(value: 'Gubre', child: Text('Gubre gibi say')),
                    const DropdownMenuItem(value: 'Ilac', child: Text('Ilac gibi say')),
                  ],
                  onChanged: (v) => setDialogState(() => seciliKategori = v ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final ad = adController.text.trim();
                if (ad.length < 2) {
                  setDialogState(() {
                    hataMetni = 'En az 2 karakter olmalı';
                  });
                  return;
                }
                final ayniAdVar = tumTipler.any(
                  (tanim) => tanim.ad.toLowerCase() == ad.toLowerCase(),
                );
                if (ayniAdVar) {
                  setDialogState(() {
                    hataMetni = 'Bu isimde bir işlem tipi zaten var';
                  });
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  IslemTuruTanim(
                    ad: ad,
                    iconKey: seciliIkon,
                    colorValue: seciliRenk,
                    kategori: seciliKategori,
                  ),
                );
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );

    if (yeniTip == null) return;
    final yeniListe = [...ozelTipler, yeniTip]
      ..sort((a, b) => a.ad.toLowerCase().compareTo(b.ad.toLowerCase()));
    await tipleriKaydet(yeniListe);
  }

  Future<void> tipSil(IslemTuruTanim tanim) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İşlem tipini sil'),
        content: Text(
          '${tanim.ad} tipi hızlı işlemlerden ve filtrelerden kalkar. Eski kayıtlarda görünmeye devam eder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (onay != true) return;
    final yeniListe = ozelTipler.where((item) => item.ad != tanim.ad).toList();
    await tipleriKaydet(yeniListe);
  }

  @override
  Widget build(BuildContext context) {
    final darEkran = MediaQuery.sizeOf(context).width < 560;
    return TasarimArkaPlani(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('İşlem tipleri'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: kaydediliyor ? null : tipEkle,
        icon: const Icon(Icons.add),
        label: const Text('Yeni tip'),
      ),
      body: yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(darEkran ? 12 : 16),
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(darEkran ? 14 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Takvim, işlem geçmişi ve hızlı işlemler bu listedeki tiplerle aynı renk ve ikon düzenini kullanır.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sulama, Gübre ve İlaç sabit tiplerdir. İstersen üstlerine yeni işlem tipleri ekleyebilirsin.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final tanim in tumTipler) ...[
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(darEkran ? 14 : 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: islemTuruRenginiGetir(tanim).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              islemTuruIkonunuGetir(tanim.iconKey),
                              color: islemTuruRenginiGetir(tanim),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tanim.ad,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(
                                        kullanilabilirIslemIkonlari.firstWhere(
                                          (item) => item['key'] == tanim.iconKey,
                                          orElse: () => {
                                            'label': 'Özel',
                                          },
                                        )['label'] as String,
                                      ),
                                    ),
                                    Chip(
                                      avatar: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: islemTuruRenginiGetir(tanim),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      label: Text(
                                        kullanilabilirIslemRenkleri.firstWhere(
                                          (item) => item['value'] == tanim.colorValue,
                                          orElse: () => {
                                            'label': 'Özel renk',
                                          },
                                        )['label'] as String,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(tanim.varsayilan ? 'Sabit' : 'Özel'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!tanim.varsayilan)
                            IconButton(
                              onPressed: kaydediliyor ? null : () => tipSil(tanim),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Sil',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 80),
              ],
            ),
    ),
  );
}
}
