import 'dart:async';

import 'package:flutter/material.dart';


import '../utils/app_helpers.dart';
import '../widgets/tasarim_arka_plani.dart';
// Fallback for globals

class TarlaEkBilgiSonucu {
  const TarlaEkBilgiSonucu({
    required this.notlar,
    required this.fotolar,
  });

  final String notlar;
  final List<String> fotolar;
}

class TarlaEkBilgiSayfasi extends StatefulWidget {
  const TarlaEkBilgiSayfasi({
    super.key,
    required this.baslangicNot,
    required this.baslangicFotolar,
  });

  final String baslangicNot;
  final List<String> baslangicFotolar;

  @override
  State<TarlaEkBilgiSayfasi> createState() => _TarlaEkBilgiSayfasiState();
}

class _TarlaEkBilgiSayfasiState extends State<TarlaEkBilgiSayfasi> {
  late final TextEditingController notController =
      TextEditingController(text: widget.baslangicNot);
  late List<String> fotolar = List<String>.from(widget.baslangicFotolar);

  @override
  void dispose() {
    notController.dispose();
    super.dispose();
  }

  Future<void> fotoSec() async {
    try {
      final yeniFotolar = await galeridenFotografSec();
      if (yeniFotolar.isEmpty) return;
      if (!mounted) return;
      setState(() {
        fotolar = [...fotolar, ...yeniFotolar];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotograf secilemedi: $error')),
      );
    }
  }

  Future<void> fotografCek() async {
    try {
      final yeniFoto = await kameradanFotografCek(context: context);
      if (yeniFoto == null || yeniFoto.isEmpty) return;
      if (!mounted) return;
      setState(() {
        fotolar = [...fotolar, yeniFoto];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotograf cekilemedi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TasarimArkaPlani(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Not ekle'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(
                TarlaEkBilgiSonucu(
                  notlar: notController.text.trim(),
                  fotolar: fotolar,
                ),
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: notController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notlar',
                hintText: 'Bu tarlaya ozel notlarini yazabilirsin',
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fotograflar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (fotolar.isEmpty)
                      Container(
                        height: 140,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
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
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: fotolar.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final foto = fotolar[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.memory(
                                    base64OnizlemeCoz(foto),
                                    height: 120,
                                    width: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      height: 120,
                                      width: 150,
                                      alignment: Alignment.center,
                                      color: Colors.grey.shade200,
                                      child: const Text('Fotograf acilamadi'),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Material(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () {
                                        setState(() {
                                          fotolar.removeAt(index);
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final darEkran = constraints.maxWidth < 560;
                        final butonGenisligi = darEkran
                            ? (constraints.maxWidth - 10) / 2
                            : null;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (kameraDestekleniyor)
                              SizedBox(
                                width: butonGenisligi,
                                child: FilledButton.icon(
                                  onPressed: fotografCek,
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Foto cek'),
                                ),
                              ),
                            SizedBox(
                              width: butonGenisligi,
                              child: FilledButton.icon(
                                onPressed: fotoSec,
                                icon: const Icon(Icons.add_photo_alternate_outlined),
                                label: Text(
                                  fotolar.isEmpty
                                      ? (kameraDestekleniyor
                                          ? 'Galeriden sec'
                                          : 'Fotograf sec')
                                      : 'Daha fazla ekle',
                                ),
                              ),
                            ),
                            if (fotolar.isNotEmpty)
                              SizedBox(
                                width: butonGenisligi,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      fotolar = [];
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Tumunu kaldir'),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
