import 'operation_types_screen.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_session_service.dart';
import '../utils/app_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/fields_provider.dart';
import '../database_helper.dart';
import 'profile_screen.dart';

// Fallback for globals

class IslemFormSonucu {
  const IslemFormSonucu({
    required this.tur,
    required this.detay,
    required this.baslangic,
    required this.fotolar,
    this.maliyet,
  });

  final String tur;
  final String detay;
  final DateTime baslangic;
  final List<String> fotolar;
  final double? maliyet;
}

class AyarlarSayfasi extends ConsumerStatefulWidget {
  const AyarlarSayfasi({
    super.key,
    required this.aileKodu,
    required this.ortakTarlaKodu,
    required this.aileAdi,
    required this.aileErisimKodu,
    required this.bulutEtkin,
    required this.kullaniciAdi,
    required this.aileSahibiMi,
    required this.onSenkronizeEt,
    required this.onSilinenTarlalariAc,
    required this.onAiledenCik,
    required this.onOrtakTarlaKodunuDegistir,
    this.onAileBilgisiniDegistir,
    required this.onAylikVeriIndir,
    required this.onVeriyiYenile,
    this.currentKullaniciId,
    this.onBulutuTekrarDene,
  });

  final String aileKodu;
  final String ortakTarlaKodu;
  final String? aileAdi;
  final String? aileErisimKodu;
  final bool bulutEtkin;
  final String kullaniciAdi;
  final bool aileSahibiMi;
  final Future<void> Function() onSenkronizeEt;
  final Future<void> Function() onSilinenTarlalariAc;
  final Future<void> Function() onAiledenCik;
  final Future<void> Function(String yeniKod) onOrtakTarlaKodunuDegistir;
  final Future<void> Function({
    required String yeniAileAdi,
    required String yeniKod,
  })? onAileBilgisiniDegistir;
  final Future<void> Function() onAylikVeriIndir;
  final Future<void> Function() onVeriyiYenile;
  final String? currentKullaniciId;
  final Future<void> Function()? onBulutuTekrarDene;

  @override
  ConsumerState<AyarlarSayfasi> createState() => _AyarlarSayfasiState();
}

class _AyarlarSayfasiState extends ConsumerState<AyarlarSayfasi> {
  bool veriIndirmeIslemde = false;
  String? veriDurumMesaji;
  DateTime? sonIndirmeHatirlatmasi;
  String? _fotoBase64;
  String? _adSoyad;

  bool get aileSahibiEtkin => widget.aileSahibiMi;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _profilVerileriniYukle();
      await aylikIndirmeDurumunuYukle();
    });
  }

  Future<void> _profilVerileriniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fotoBase64 = prefs.getString('profil_foto_base64');
      _adSoyad = prefs.getString('profil_ad_soyad');
    });
  }

  Future<void> _uygulamaIstatistikleriniGoster() async {
    final tarlalar = ref.read(fieldsProvider).value ?? [];
    final silinenTarlalar = ref.read(deletedFieldsProvider).value ?? [];
    
    int toplamIslemSayisi = 0;
    double toplamAlanM2 = 0;
    
    for (var tarla in tarlalar) {
      double alanVal = tarla.alanMetrekare ?? (double.tryParse(tarla.alan) ?? 0.0);
      toplamAlanM2 += alanVal;
      if (tarla.id != null) {
        final islemler = await DatabaseHelper.instance.tarlaIslemleri(tarla.id!);
        toplamIslemSayisi += islemler.length;
      }
    }
    
    final dekar = toplamAlanM2 / 1000.0;
    final isEnglish = ref.read(languageProvider) == 'en';
    
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF1B4332)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEnglish ? 'App Statistics' : 'Uygulama İstatistikleri',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _istatistikSatiri(isEnglish ? 'Total Fields' : 'Toplam Tarla', '${tarlalar.length}'),
              _istatistikSatiri(isEnglish ? 'Total Area' : 'Toplam Alan', '${dekar.toStringAsFixed(1)} dekar'),
              _istatistikSatiri(isEnglish ? 'Total Operations' : 'Toplam İşlem', '$toplamIslemSayisi'),
              _istatistikSatiri(isEnglish ? 'Archived Fields' : 'Arşivdeki Tarlalar', '${silinenTarlalar.length}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Close' : 'Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _istatistikSatiri(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(deger, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B4332))),
        ],
      ),
    );
  }

  void _destekVeIletisimGoster() {
    final isEnglish = ref.read(languageProvider) == 'en';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.support_agent_rounded, color: Color(0xFF1B4332)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEnglish ? 'Support & Feedback' : 'Destek ve İletişim',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEnglish 
                    ? 'For any questions, issues or suggestions, please contact our support team:'
                    : 'Her türlü soru, sorun veya öneriniz için destek ekibimizle iletişime geçebilirsiniz:',
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('kilicliali96@gmail.com', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.phone_android_rounded, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('0539 474 56 88', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isEnglish
                    ? 'Your feedback is very important to make Tarim360 better.'
                    : 'Görüşleriniz Tarım360\'ı geliştirmek için bizim için çok değerlidir.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Close' : 'Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF476F3A),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Dil secenegi kaldirildi

  // ignore: unused_element
  String _tarihGoster(DateTime tarih) {
    return DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(tarih);
  }

  Future<void> aylikIndirmeDurumunuYukle() async {
    final tarih = await AppSessionService.sonPdfHatirlatmaTarihiniGetir(widget.aileKodu);
    if (!mounted) return;
    setState(() {
      sonIndirmeHatirlatmasi = tarih;
    });
  }

  Future<void> aylikVeriIndir() async {
    setState(() {
      veriIndirmeIslemde = true;
      veriDurumMesaji = null;
    });
    try {
      await widget.onAylikVeriIndir();
      await aylikIndirmeDurumunuYukle();
      if (!mounted) return;
      setState(() {
        veriDurumMesaji = 'Sürüme göre veri raporu indirildi.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        veriDurumMesaji = 'Veri indirme başarısız: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          veriIndirmeIslemde = false;
        });
      }
    }
  }

  Future<void> hesapAnahtariniDegistir() async {
    final authState = ref.read(authProvider).value;
    final mevcutKod = (authState?.familyAccessCode ?? authState?.sharedFarmCode ?? widget.aileErisimKodu ?? widget.ortakTarlaKodu).trim();
    final mevcutAileAdi = authState?.familyName ?? widget.aileAdi ?? 'Ekibim';

    final kodKontrolcu = TextEditingController(text: mevcutKod);
    final aileAdiKontrolcu = TextEditingController(text: mevcutAileAdi);

    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Ekip Bilgilerini Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ekip adını ve kodunu değiştirebilirsin. QR paylaşımı yeni koda göre otomatik yenilenir.',
              style: TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: aileAdiKontrolcu,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ekip adı',
                prefixIcon: Icon(Icons.family_restroom_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kodKontrolcu,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Yeni ekip kodu',
                hintText: 'Örnek: EKIP01',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bilgileri Güncelle'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    final yeniKod = kodKontrolcu.text.trim();
    final yeniAileAdi = aileAdiKontrolcu.text.trim();
    if (yeniKod.isEmpty) return;
    if (widget.onAileBilgisiniDegistir != null) {
      await widget.onAileBilgisiniDegistir!(
        yeniAileAdi: yeniAileAdi,
        yeniKod: yeniKod,
      );
    } else {
      await widget.onOrtakTarlaKodunuDegistir(yeniKod);
    }

    await ref.read(authProvider.notifier).refreshSession();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ekip bilgileri güncellendi.')),
    );
  }

  Future<void> hesapAnahtariQrGoster() async {
    final authState = ref.read(authProvider).value;
    final kod = (authState?.familyAccessCode ?? authState?.sharedFarmCode ?? widget.aileErisimKodu ?? widget.ortakTarlaKodu).trim();
    if (kod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ekip kodu bulunamadı. Lütfen ekip bilgilerini kontrol edin.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Ekip Kodu QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SizedBox(
                width: 220,
                height: 220,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: QrImageView(
                    data: ortakTarlaKodQrMetniOlustur(kod),
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Ekip kodu: $kod',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> yapayZekaAyarlariniAc() async {
    final isEnglish = ref.read(languageProvider) == 'en';
    final mevcutKey = await AppSessionService.geminiApiAnahtariniGetir() ?? '';
    final controller = TextEditingController(text: mevcutKey);
    
    if (!mounted) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.smart_toy_outlined, color: Color(0xFF0F9D58)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEnglish ? 'AI Analyzer Settings' : 'AI Analiz Ayarları (Groq)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEnglish 
                  ? 'Enter your free Groq API Key to enable real AI plant disease analysis. Get it at console.groq.com (no credit card needed).'
                  : 'Ücretsiz Groq API anahtarını ekleyerek gerçek yapay zeka analizini aktif et. console.groq.com adresinden ücretsiz alabilirsin (kredi kartı gerekmez).',
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Groq API Key' : 'Groq API Anahtarı',
                  hintText: 'gsk_...',
                  prefixIcon: const Icon(Icons.api_rounded),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  await launchUrl(Uri.parse('https://console.groq.com/keys'), mode: LaunchMode.externalApplication);
                },
                child: Text(
                  isEnglish ? '👉 Click here for free Groq API key' : '👉 Buraya tıkla → Ücretsiz Groq anahtarı al',
                  style: const TextStyle(
                    color: Color(0xFF0F9D58),
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEnglish 
                  ? '💡 Note: The API key is stored securely on this device and is never shared.'
                  : '💡 Not: API anahtarı bu cihazda güvenli bir şekilde saklanır ve asla dışarıyla paylaşılmaz.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isEnglish ? 'Cancel' : 'İptal'),
          ),
          if (mevcutKey.isNotEmpty)
            TextButton(
              onPressed: () {
                controller.clear();
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: Text(isEnglish ? 'Clear Key' : 'Anahtarı Sil'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F9D58)),
            child: Text(isEnglish ? 'Save' : 'Kaydet'),
          ),
        ],
      ),
    );

    if (onay != true) return;
    final yeniKey = controller.text.trim();
    
    // Save locally
    await AppSessionService.geminiApiAnahtariniKaydet(yeniKey);

    // Refresh Riverpod session
    await ref.read(authProvider.notifier).refreshSession();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          yeniKey.isEmpty 
            ? (isEnglish ? 'Groq API key removed.' : 'Groq API anahtarı temizlendi.')
            : (isEnglish ? 'Groq API key saved!' : 'Groq API anahtarı kaydedildi! Artık analiz yapabilirsin 🌱'),
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive 
        ? Colors.red.shade600 
        : (isDark ? Colors.white : const Color(0xFF1B3B2B));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A1F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: iconColor ?? color, size: 26),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: isDark ? Colors.white30 : Colors.black26,
          size: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final darEkran = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = ref.watch(languageProvider);
    final isEnglish = currentLang == 'en';

    final authState = ref.watch(authProvider).value;
    final activeCode = (authState?.familyAccessCode ?? authState?.sharedFarmCode ?? widget.aileErisimKodu ?? widget.ortakTarlaKodu).trim();

    return TasarimArkaPlani(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Premium Header with Avatar
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1B4332), Color(0xFF0F261D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              isEnglish ? 'Menu & Settings' : 'Menü',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (widget.bulutEtkin)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.cloud_done_rounded, color: Colors.white70, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    activeCode,
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1B13) : const Color(0xFFF3F7F4),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: const Color(0xFF1B4332).withValues(alpha: 0.1),
                        backgroundImage: (_fotoBase64 != null && _fotoBase64!.isNotEmpty)
                            ? MemoryImage(base64Decode(_fotoBase64!))
                            : null,
                        child: (_fotoBase64 == null || _fotoBase64!.isEmpty)
                            ? const Icon(
                                Icons.person_rounded,
                                size: 50,
                                color: Color(0xFF1B4332),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            // User details under the avatar
            Text(
              _adSoyad != null && _adSoyad!.isNotEmpty ? _adSoyad! : widget.kullaniciAdi,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1B3B2B),
              ),
            ),
            Builder(builder: (context) {
              final session = ref.watch(authProvider).value;
              final email = session?.email;
              if (email != null && email.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 18),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                children: [
                  _buildSectionHeader(isEnglish ? 'Account & Team' : 'Hesap ve Ekip'),
                  _buildMenuTile(
                    context,
                    icon: Icons.manage_accounts_outlined,
                    title: isEnglish ? 'Profile Info' : 'Profil Bilgileri',
                    onTap: () {
                      final session = ref.read(authProvider).value;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilBilgileriSayfasi(
                            kullaniciAdi: widget.kullaniciAdi,
                            email: session?.email,
                          ),
                        ),
                      ).then((_) {
                        _profilVerileriniYukle();
                      });
                    },
                  ),
                  if (widget.bulutEtkin) ...[
                    _buildMenuTile(
                      context,
                      icon: Icons.family_restroom_rounded,
                      title: isEnglish ? 'Edit Family Info' : 'Ekip Bilgilerini Düzenle',
                      iconColor: const Color(0xFF4D7FC6),
                      onTap: hesapAnahtariniDegistir,
                    ),
                    _buildMenuTile(
                      context,
                      icon: Icons.qr_code_2_rounded,
                      title: isEnglish ? 'Show Team QR' : 'Ekip Kodu QR Göster',
                      iconColor: const Color(0xFFE28B14),
                      onTap: hesapAnahtariQrGoster,
                    ),
                    _buildMenuTile(
                      context,
                      icon: Icons.sync_rounded,
                      title: isEnglish ? 'Sync Now' : 'Şimdi Senkronize Et',
                      iconColor: const Color(0xFF4D7FC6),
                      onTap: () async {
                        await widget.onSenkronizeEt();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                  if (!widget.bulutEtkin && widget.onBulutuTekrarDene != null)
                    _buildMenuTile(
                      context,
                      icon: Icons.cloud_sync_outlined,
                      title: isEnglish ? 'Retry Cloud Sync' : 'Bulutu Tekrar Dene',
                      iconColor: const Color(0xFF4D7FC6),
                      onTap: () async {
                        await widget.onBulutuTekrarDene!();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),

                  _buildSectionHeader(isEnglish ? 'App & Appearance' : 'Uygulama ve Görünüm'),
                  _buildMenuTile(
                    context,
                    icon: Icons.wallpaper_outlined,
                    title: isEnglish ? 'Appearance & Background' : 'Görünüm & Arka Plan',
                    iconColor: Colors.deepPurple.shade400,
                    onTap: () async {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: isDark ? const Color(0xFF12241C) : Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        builder: (context) => StatefulBuilder(
                          builder: (context, setModalState) => SafeArea(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.palette_outlined, color: Color(0xFF1B4332)),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEnglish ? 'Appearance & Background' : 'Görünüm & Arka Plan',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isEnglish
                                          ? 'Personalize the visual theme with premium presets.'
                                          : 'Uygulamanın görsel temasını premium çiftlik temalarıyla özelleştir.',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      isEnglish ? 'Premium Nature Themes:' : 'Premium Doğa Temaları:',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    const SizedBox(height: 10),
                                    // Presets row
                                    SizedBox(
                                      height: 100,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        children: [
                                          GestureDetector(
                                            onTapDown: (details) {
                                              ref.read(themeTransitionCenterProvider.notifier).updateState(details.globalPosition);
                                            },
                                            child: _PresetCard(
                                              name: isEnglish ? 'Default' : 'Varsayılan',
                                              desc: isEnglish ? 'Natural Green' : 'Doğal Gradyan',
                                              gradient: const [Color(0xFF0F261C), Color(0xFF07140E)],
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await setTasarimArkaPlani(ref, null);
                                              },
                                            ),
                                          ),
                                          GestureDetector(
                                            onTapDown: (details) {
                                              ref.read(themeTransitionCenterProvider.notifier).updateState(details.globalPosition);
                                            },
                                            child: _PresetCard(
                                              name: isEnglish ? 'Deep Forest' : 'Doğa & Orman',
                                              desc: isEnglish ? 'Rich Pine View' : 'Çam ve Orman Manzarası',
                                              gradient: const [Color(0xFF0A1F13), Color(0xFF030D08)],
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await setTasarimArkaPlani(ref, 'preset:deep_forest');
                                              },
                                            ),
                                          ),
                                          GestureDetector(
                                            onTapDown: (details) {
                                              ref.read(themeTransitionCenterProvider.notifier).updateState(details.globalPosition);
                                            },
                                            child: _PresetCard(
                                              name: isEnglish ? 'Golden Wheat' : 'Buğday Tarlası',
                                              desc: isEnglish ? 'Harvest Amber' : 'Altın Başak Tarlası',
                                              gradient: const [Color(0xFF24180A), Color(0xFF0F0A04)],
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await setTasarimArkaPlani(ref, 'preset:golden_wheat');
                                              },
                                            ),
                                          ),
                                          GestureDetector(
                                            onTapDown: (details) {
                                              ref.read(themeTransitionCenterProvider.notifier).updateState(details.globalPosition);
                                            },
                                            child: _PresetCard(
                                              name: isEnglish ? 'Morning Dew' : 'Sabah Çiyi',
                                              desc: isEnglish ? 'Fresh Mint' : 'Taze Nane',
                                              gradient: const [Color(0xFF0C2424), Color(0xFF051010)],
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await setTasarimArkaPlani(ref, 'preset:morning_dew');
                                              },
                                            ),
                                          ),
                                          GestureDetector(
                                            onTapDown: (details) {
                                              ref.read(themeTransitionCenterProvider.notifier).updateState(details.globalPosition);
                                            },
                                            child: _PresetCard(
                                              name: isEnglish ? 'Lavender Field' : 'Menekşe Bahçesi',
                                              desc: isEnglish ? 'Elegant Lavender' : 'Lavantalar ve Menekşeler',
                                              gradient: const [Color(0xFF180C24), Color(0xFF0A0510)],
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await setTasarimArkaPlani(ref, 'preset:lavender_field');
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      isEnglish ? 'Your Photo:' : 'Kendi Fotoğrafın:',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTapDown: (details) {
                                        ref.read(themeTransitionCenterProvider.notifier).updateState(details.globalPosition);
                                      },
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size.fromHeight(48),
                                          backgroundColor: const Color(0xFF1B4332),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () async {
                                          final picker = ImagePicker();
                                          Navigator.pop(context);
                                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                          if (picked != null && mounted) {
                                            await setTasarimArkaPlani(ref, picked.path);
                                          }
                                        },
                                        icon: const Icon(Icons.photo_library_outlined),
                                        label: Text(isEnglish ? 'Choose Photo from Gallery' : 'Galeriden Fotoğraf Seç'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMenuTile(
                    context,
                    icon: Icons.category_outlined,
                    title: isEnglish ? 'Edit Operation Types' : 'İşlem Tiplerini Düzenle',
                    iconColor: const Color(0xFF6F8B3A),
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IslemTurleriSayfasi(
                            aileKodu: widget.aileKodu,
                            bulutEtkin: widget.bulutEtkin,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMenuTile(
                    context,
                    icon: Icons.inventory_2_outlined,
                    title: isEnglish ? 'Archive (Deleted Fields)' : 'Arşiv (Silinen Tarlalar)',
                    onTap: () async {
                      await widget.onSilinenTarlalariAc();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),

                  _buildSectionHeader(isEnglish ? 'AI Settings' : 'Yapay Zeka (AI)'),
                  _buildMenuTile(
                    context,
                    icon: Icons.smart_toy_outlined,
                    title: isEnglish ? 'AI Analyzer Settings (Groq)' : 'AI Analiz Ayarları (Groq)',
                    iconColor: const Color(0xFF0F9D58),
                    onTap: yapayZekaAyarlariniAc,
                  ),

                  _buildSectionHeader(isEnglish ? 'Support & Info' : 'Destek ve Bilgi'),
                  _buildMenuTile(
                    context,
                    icon: Icons.analytics_outlined,
                    title: isEnglish ? 'App Statistics' : 'Uygulama İstatistikleri',
                    iconColor: const Color(0xFF2D6A4F),
                    onTap: _uygulamaIstatistikleriniGoster,
                  ),
                  _buildMenuTile(
                    context,
                    icon: Icons.support_agent_rounded,
                    title: isEnglish ? 'Support & Feedback' : 'Destek ve İletişim',
                    iconColor: const Color(0xFF1B4332),
                    onTap: _destekVeIletisimGoster,
                  ),

                  _buildSectionHeader(isEnglish ? 'Session' : 'Oturum'),
                  _buildMenuTile(
                    context,
                    icon: Icons.logout_rounded,
                    title: isEnglish ? 'Log Out' : 'Çıkış Yap',
                    isDestructive: true,
                    onTap: () async {
                      final onay = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: Text(isEnglish ? 'Log Out?' : 'Çıkış Yapılsın mı?'),
                          content: Text(isEnglish
                              ? 'Are you sure you want to log out of your family account?'
                              : 'Ekip hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(isEnglish ? 'Cancel' : 'İptal'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              child: Text(isEnglish ? 'Log Out' : 'Çıkış Yap'),
                            ),
                          ],
                        ),
                      );
                      if (onay == true) {
                        await widget.onAiledenCik();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      isEnglish ? 'Version 1.0' : 'Sürüm 1.0',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 40),
                ].animate(interval: 40.ms).fade(duration: 300.ms).slideX(begin: 0.1, end: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.name,
    required this.desc,
    required this.gradient,
    required this.onTap,
  });

  final String name;
  final String desc;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

