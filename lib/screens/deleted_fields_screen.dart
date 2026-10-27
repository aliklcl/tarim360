import '../widgets/badges_and_cards.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../tarla_model.dart';
import '../utils/app_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fields_provider.dart';
import '../widgets/tasarim_arka_plani.dart';
// Fallback for globals

class SilinenTarlalarSayfasi extends ConsumerStatefulWidget {
  const SilinenTarlalarSayfasi({
    super.key,
    required this.aileKodu,
    required this.bulutEtkin,
  });

  final String aileKodu;
  final bool bulutEtkin;

  @override
  ConsumerState<SilinenTarlalarSayfasi> createState() => _SilinenTarlalarSayfasiState();
}

class _SilinenTarlalarSayfasiState extends ConsumerState<SilinenTarlalarSayfasi> {
  bool yukleniyor = true;
  List<Tarla> silinenTarlalar = [];
  final Map<int, int> islemSayilari = {};
  final Map<int, int> fotografSayilari = {};
  final TextEditingController aramaController = TextEditingController();
  String aramaMetni = '';

  @override
  void initState() {
    super.initState();
    yukle();
  }

  @override
  void dispose() {
    aramaController.dispose();
    super.dispose();
  }

  Future<void> yukle() async {
    await ref.read(deletedFieldsProvider.notifier).refreshFields();
  }

  Future<void> geriYukle(Tarla tarla) async {
    final tarlaId = tarla.id;
    final islemSayisi = tarlaId == null ? 0 : (islemSayilari[tarlaId] ?? 0);
    final fotoSayisi = tarlaId == null ? 0 : (fotografSayilari[tarlaId] ?? 0);
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${tarla.ad} geri yüklensin mi?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GirisBilgiRozeti(
                    ikon: Icons.event_note_outlined,
                    metin: '$islemSayisi işlem geri gelecek',
                  ),
                  GirisBilgiRozeti(
                    ikon: Icons.photo_library_outlined,
                    metin: '$fotoSayisi fotoğraf geri gelecek',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Bu işlem tarlayı tüm ayrıntılarıyla geri getirir:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Notlar, fotoğraflar, konum, alan bilgisi, sınır noktaları ve işlem geçmişi aynen geri yüklenir.',
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.undo),
            label: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (onay != true) return;

    await ref.read(fieldsProvider.notifier).restoreField(tarla);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tarla.ad} geri yüklendi!'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Geri Al',
          textColor: Colors.amber,
          onPressed: () async {
            await ref.read(fieldsProvider.notifier).deleteField(tarla);
          },
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final deletedFieldsAsync = ref.watch(deletedFieldsProvider);
    
    return TasarimArkaPlani(
      child: deletedFieldsAsync.when(
        loading: () => const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: Text('Hata: $error')),
        ),
        data: (silinenTarlalar) {
          final gosterilenTarlalar = aramaMetni.trim().isEmpty 
              ? silinenTarlalar 
              : silinenTarlalar.where((tarla) => 
                  tarla.ad.toLowerCase().contains(aramaMetni.toLowerCase())).toList();

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Silinen Tarlalar'),
            ),
          body: silinenTarlalar.isEmpty
              ? const Center(
                  child: Text('Su anda arsivde geri yuklenecek tarla yok'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: gosterilenTarlalar.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          TextField(
                            controller: aramaController,
                            onChanged: (value) {
                              setState(() {
                                aramaMetni = value;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Arsivde ara',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          if (gosterilenTarlalar.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'Aramana uygun silinmiş tarla bulunamadı.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                        ],
                      );
                    }
                    final tarla = gosterilenTarlalar[index - 1];
                    final alanOzeti = formatAlanOzeti(
                      alanMetrekare: tarla.alanMetrekare,
                      varsayilanMetin: tarla.alan,
                    );
                    final tarlaId = tarla.id;
                    final islemSayisi =
                        tarlaId == null ? 0 : (islemSayilari[tarlaId] ?? 0);
                    final fotoSayisi =
                        tarlaId == null ? 0 : (fotografSayilari[tarlaId] ?? 0);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF476F3A).withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.restore_from_trash_outlined,
                                    color: Color(0xFF476F3A),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tarla.ad,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tarla.urun.trim().isEmpty
                                            ? 'Urun belirtilmedi'
                                            : tarla.urun,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        alanOzeti,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        arsivdenKaliciSilinmeMetni(tarla.silinmeTarihi),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                GirisBilgiRozeti(
                                  ikon: Icons.event_note_outlined,
                                  metin: '$islemSayisi islem',
                                ),
                                GirisBilgiRozeti(
                                  ikon: Icons.photo_library_outlined,
                                  metin: '$fotoSayisi fotograf',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Geri yuklediginde bu tarlanin notlari, fotograflari, konumu, alan bilgisi, sinir noktalari ve islem gecmisi aynen geri gelir.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () => geriYukle(tarla),
                                icon: const Icon(Icons.undo),
                                label: const Text('Geri yukle'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          );
        },
      ),
    );
  }
}
