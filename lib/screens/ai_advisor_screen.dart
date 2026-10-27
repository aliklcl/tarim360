import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/free_plant_advice_service.dart';
import '../services/gemini_service.dart';
import '../app_session_service.dart';
import '../utils/app_helpers.dart';
import '../providers/auth_provider.dart';
import '../database_helper.dart';

class AiDanismanSayfasi extends ConsumerStatefulWidget {
  const AiDanismanSayfasi({super.key});

  @override
  ConsumerState<AiDanismanSayfasi> createState() => _AiDanismanSayfasiState();
}

class _AiDanismanSayfasiState extends ConsumerState<AiDanismanSayfasi> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _soruController = TextEditingController(
    text: 'Bu bitkideki olası hastalık nedir ve ilk ne yapmalıyım?',
  );

  File? _secilenGorsel;
  bool _yukleniyor = false;
  String? _yanit;
  final Set<String> _seciliBelirtiler = <String>{};
  List<Map<String, dynamic>> _gecmisAnalizler = [];

  @override
  void initState() {
    super.initState();
    _gecmisiYukle();
  }

  @override
  void dispose() {
    _soruController.dispose();
    super.dispose();
  }

  Future<void> _gecmisiYukle() async {
    try {
      final list = await DatabaseHelper.instance.tumYapayZekaAnalizleri();
      setState(() {
        _gecmisAnalizler = list;
      });
    } catch (_) {}
  }

  Future<void> _gorselSec(ImageSource source) async {
    if (source == ImageSource.camera) {
      final devam = await kameraBilgilendirmesiniGoster(
        context,
        amac: 'bitki fotografi cekip analiz baslatmak',
      );
      if (!devam) return;
    }
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (xfile == null) return;
    setState(() {
      _secilenGorsel = File(xfile.path);
    });
  }

  Future<void> _analizEt() async {
    final soru = _soruController.text.trim();
    final gorsel = _secilenGorsel;
    if (gorsel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analiz için fotoğraf seçin.')),
      );
      return;
    }
    if (soru.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soru alanı boş olamaz.')),
      );
      return;
    }
    setState(() {
      _yukleniyor = true;
      _yanit = null;
    });
    try {
      final geminiAktif = await AppSessionService.geminiAktifMi();
      String sonuc;
      if (geminiAktif) {
        sonuc = await GeminiService.analizEt(
          soru: soru,
          seciliBelirtiler: _seciliBelirtiler.toList(growable: false),
          gorsel: gorsel,
        );
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        sonuc = FreePlantAdviceService.onAnalizUret(
          soru: soru,
          gorselVar: gorsel.existsSync(),
          seciliBelirtiler: _seciliBelirtiler.toList(growable: false),
        );
      }
      if (!mounted) return;
      setState(() {
        _yanit = sonuc;
      });

      // Save to SQLite history
      try {
        final map = {
          'soru': soru,
          'yanit': sonuc,
          'tarih': DateTime.now().toIso8601String(),
          'gorsel_yolu': gorsel.path,
          'belirtiler': _seciliBelirtiler.join(','),
        };
        await DatabaseHelper.instance.yapayZekaAnaliziEkle(map);
        if (mounted) _gecmisiYukle();
      } catch (_) {}
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analiz oluşturulamadı: ${error.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
        });
      }
    }
  }

  void _hazirSoruyuSec(String soru) {
    _soruController.text = soru;
  }

  void _belirtiSec(String belirti) {
    setState(() {
      if (_seciliBelirtiler.contains(belirti)) {
        _seciliBelirtiler.remove(belirti);
      } else {
        _seciliBelirtiler.add(belirti);
      }
    });
  }

  void _resimSecmeSecenekleriniGoster() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fotoğraf Kaynağı Seçin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF1F6E43)),
              title: const Text('Kamerayı Aç'),
              onTap: () {
                Navigator.pop(context);
                _gorselSec(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF1F6E43)),
              title: const Text('Galeriye Git'),
              onTap: () {
                Navigator.pop(context);
                _gorselSec(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleQuestionChip(String fullQuestion, String chipLabel) {
    return ActionChip(
      label: Text(
        chipLabel,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF1F6E43)),
      ),
      backgroundColor: const Color(0xFF1F6E43).withValues(alpha: 0.05),
      side: BorderSide(color: const Color(0xFF1F6E43).withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () => _hazirSoruyuSec(fullQuestion),
    );
  }

  Widget _buildRichText(String text, BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Theme.of(context).colorScheme.onSurface;
    final List<TextSpan> spans = [];
    final regExp = RegExp(r'\*\*(.*?)\*\*');
    
    int lastMatchEnd = 0;
    final matches = regExp.allMatches(text);
    
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: textColor, fontWeight: FontWeight.normal),
        ));
      }
      
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ));
      
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(color: textColor, fontWeight: FontWeight.normal),
      ));
    }
    
    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(
          fontSize: 14, 
          height: 1.5, 
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
      ),
    );
  }

  List<Widget> parseMarkdownText(String text, BuildContext context) {
    // Gorsel/karsilastirma bloklari kaldirildi — sadece metin gosterilir
    // Markdown gorsel soz dizimini ([...]) metinden temizle
    final temizMetin = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '').trim();
    if (temizMetin.isEmpty) return const [];
    return [_buildRichText(temizMetin, context)];
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F6E43), Color(0xFF2D8A56)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.spa_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Filiz Yapay Zeka',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bitki fotoğrafı ve sorununa göre hızlı ön değerlendirme raporu sunar.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: AppSessionService.geminiAktifMi(),
              key: ValueKey(authState.hashCode),
              builder: (context, snapshot) {
                final geminiAktif = snapshot.data ?? false;
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: geminiAktif 
                        ? const Color(0xFF0F9D58).withValues(alpha: 0.08) 
                        : Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: geminiAktif 
                          ? const Color(0xFF0F9D58).withValues(alpha: 0.2) 
                          : Colors.amber.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        geminiAktif ? Icons.bolt_rounded : Icons.offline_bolt_rounded,
                        color: geminiAktif ? const Color(0xFF0F9D58) : Colors.amber.shade800,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              geminiAktif ? 'AI Aktif 🟢' : 'Çevrimdışı Mod 🟡',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: geminiAktif ? const Color(0xFF1F6E43) : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              geminiAktif 
                                  ? 'Groq bulut AI ile ücretsiz ve hızlı bitki teşhisi devrede.' 
                                  : 'Ayarlardan Groq API anahtarı ekleyerek gerçek AI\'ı etkinleştirebilirsiniz.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: geminiAktif ? const Color(0xFF1F6E43).withValues(alpha: 0.8) : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Interactive Image Selector Card
                    if (_secilenGorsel == null)
                      InkWell(
                        onTap: _resimSecmeSecenekleriniGoster,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined, 
                                size: 44, 
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Bitki Fotoğrafı Yükleyin',
                                style: TextStyle(
                                  fontSize: 15, 
                                  fontWeight: FontWeight.bold, 
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fotoğraf çekmek veya galeriden yüklemek için dokunun',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              _secilenGorsel!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 18,
                                  child: IconButton(
                                    icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF1F6E43), size: 18),
                                    onPressed: _resimSecmeSecenekleriniGoster,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 18,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _secilenGorsel = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Symptoms Selector Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF1F6E43), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Bitkide Ne Görüyorsunuz? (Belirtiler)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F6E43)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          selected: _seciliBelirtiler.contains('sararma'),
                          onSelected: (_) => _belirtiSec('sararma'),
                          selectedColor: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF1F6E43),
                          label: const Text('🟡 Sararma'),
                        ),
                        FilterChip(
                          selected: _seciliBelirtiler.contains('leke'),
                          onSelected: (_) => _belirtiSec('leke'),
                          selectedColor: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF1F6E43),
                          label: const Text('🟤 Leke / Benek'),
                        ),
                        FilterChip(
                          selected: _seciliBelirtiler.contains('mantar'),
                          onSelected: (_) => _belirtiSec('mantar'),
                          selectedColor: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF1F6E43),
                          label: const Text('🍄 Mantar / Küf'),
                        ),
                        FilterChip(
                          selected: _seciliBelirtiler.contains('bocek'),
                          onSelected: (_) => _belirtiSec('bocek'),
                          selectedColor: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF1F6E43),
                          label: const Text('🐛 Böcek / Zararlı'),
                        ),
                        FilterChip(
                          selected: _seciliBelirtiler.contains('solma'),
                          onSelected: (_) => _belirtiSec('solma'),
                          selectedColor: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF1F6E43),
                          label: const Text('🥀 Solma'),
                        ),
                        FilterChip(
                          selected: _seciliBelirtiler.contains('kuruma'),
                          onSelected: (_) => _belirtiSec('kuruma'),
                          selectedColor: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF1F6E43),
                          label: const Text('🍂 Kuruma'),
                        ),
                        FilterChip(
                          selected: _seciliBelirtiler.contains('kivrilma'),
                          onSelected: (_) => _belirtiSec('kivrilma'),
                          selectedColor: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF1F6E43),
                          label: const Text('🕸️ Kıvrılma'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Question Input Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF1F6E43), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Filiz\'e Detayları Belirtin',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F6E43)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _soruController,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Bitkinizin durumuna dair detayları veya spesifik sorularınızı yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Örnek Sorular:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildExampleQuestionChip('Yapraktaki lekelerin nedeni nedir?', 'Yaprak lekesi'),
                          const SizedBox(width: 8),
                          _buildExampleQuestionChip('Mantar kaynaklı bir enfeksiyon olabilir mi?', 'Mantar şüphesi'),
                          const SizedBox(width: 8),
                          _buildExampleQuestionChip('Hangi böcekler zarar vermiş olabilir?', 'Zararlı tespiti'),
                          const SizedBox(width: 8),
                          _buildExampleQuestionChip('Bitkimde sararma var, sulamayı nasıl yapmalıyım?', 'Sulama ve sararma'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _yukleniyor ? null : _analizEt,
              icon: _yukleniyor 
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F6E43),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              label: Text(
                _yukleniyor ? 'Filiz Analiz Ediyor...' : 'Analizi Başlat',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Not: Yapay zeka değerlendirmeleri ön değerlendirme niteliğindedir. Kesin sonuçlar için bölgenizdeki ziraat uzmanlarına veya tarım danışmanlarına başvurun.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
            if (_yanit != null) ...[
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF1F6E43), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF0F9D58)),
                          const SizedBox(width: 8),
                          const Text(
                            'Filiz Analiz Raporu',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F6E43),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      ...parseMarkdownText(_yanit!, context),
                    ],
                  ),
                ),
              ),
            ],
            if (_gecmisAnalizler.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Geçmiş Analizler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F6E43),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final eminMi = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Geçmişi Temizle'),
                          content: const Text('Tüm geçmiş analizler silinecek. Emin misiniz?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('İptal'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              child: const Text('Temizle'),
                            ),
                          ],
                        ),
                      );
                      if (eminMi == true) {
                        await DatabaseHelper.instance.yapayZekaAnalizleriniTemizle();
                        _gecmisiYukle();
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                    label: const Text('Tümünü Temizle', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _gecmisAnalizler.length,
                itemBuilder: (context, index) {
                  final analiz = _gecmisAnalizler[index];
                  final id = analiz['id'] as int;
                  final soru = analiz['soru'] as String;
                  final yanit = analiz['yanit'] as String;
                  final tarihStr = analiz['tarih'] as String;
                  final gorselYolu = analiz['gorsel_yolu'] as String?;
                  final belirtilerStr = analiz['belirtiler'] as String? ?? '';
                  
                  DateTime? tarih;
                  try {
                    tarih = DateTime.parse(tarihStr);
                  } catch (_) {}
                  
                  final formatliTarih = tarih != null 
                      ? DateFormat('dd.MM.yyyy HH:mm').format(tarih)
                      : tarihStr;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: gorselYolu != null && File(gorselYolu).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(gorselYolu),
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image_outlined, color: Colors.grey),
                              ),
                        title: Text(
                          soru,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          formatliTarih,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () async {
                            final eminMi = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('Analizi Sil'),
                                content: const Text('Bu analiz kaydını silmek istediğinize emin misiniz?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('İptal'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                    child: const Text('Sil'),
                                  ),
                                ],
                              ),
                            );
                            if (eminMi == true) {
                              await DatabaseHelper.instance.yapayZekaAnaliziSil(id);
                              _gecmisiYukle();
                            }
                          },
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Divider(),
                                const SizedBox(height: 6),
                                if (belirtilerStr.isNotEmpty) ...[
                                  Text(
                                    'Seçilen Belirtiler: ${belirtilerStr.split(',').join(', ')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey.shade400 
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (gorselYolu != null && File(gorselYolu).existsSync()) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(gorselYolu),
                                      height: 180,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 180,
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? Colors.grey.shade900 
                                            : Colors.grey.shade100,
                                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                const Text(
                                  'Filiz Rapor Detayı:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F6E43),
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.grey.shade900 
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey.shade800 
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: parseMarkdownText(yanit, context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
