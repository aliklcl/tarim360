import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../providers/language_provider.dart';
import '../widgets/tasarim_arka_plani.dart';
import '../utils/app_helpers.dart';
import '../cloud_sync_service.dart';
import '../app_session_service.dart';

class ProfilBilgileriSayfasi extends ConsumerStatefulWidget {
  const ProfilBilgileriSayfasi({
    super.key,
    required this.kullaniciAdi,
    required this.email,
  });

  final String kullaniciAdi;
  final String? email;

  @override
  ConsumerState<ProfilBilgileriSayfasi> createState() => _ProfilBilgileriSayfasiState();
}

class _ProfilBilgileriSayfasiState extends ConsumerState<ProfilBilgileriSayfasi> {
  String? _fotoBase64;
  String _adSoyad = '';
  String _dogumTarihi = '';
  String _ePosta = '';
  String _telefon = '';

  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _adSoyad = widget.kullaniciAdi;
    _ePosta = widget.email ?? '';
    _profilVerileriniYukle();
  }

  Future<void> _profilVerileriniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fotoBase64 = prefs.getString('profil_foto_base64');
      _adSoyad = prefs.getString('profil_ad_soyad') ?? widget.kullaniciAdi;
      _dogumTarihi = prefs.getString('profil_dogum_tarihi') ?? '';
      _ePosta = prefs.getString('profil_eposta') ?? widget.email ?? '';
      _telefon = prefs.getString('profil_telefon') ?? '';

      _yukleniyor = false;
    });
  }

  Future<void> _veriyiKaydet(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _fotoSec(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 300, maxHeight: 300, imageQuality: 85);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profil_foto_base64', base64String);

      setState(() {
        _fotoBase64 = base64String;
      });

      _snack('Profil fotoğrafı başarıyla güncellendi.');
    } catch (e) {
      _snack('Fotoğraf yüklenirken hata oluştu: $e');
    }
  }

  void _fotoSecimMenusuGoster() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profil Fotoğrafı Ekle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _fotoSec(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Fotoğraf Çek'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _fotoSec(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeriden Seç'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _degerDuzenle({
    required String baslik,
    required String key,
    required String mevcutDeger,
    required Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final l10n = ref.read(languageProvider.notifier);
    String t(String key) => l10n.translate(key);

    final controller = TextEditingController(text: mevcutDeger);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$baslik ${t('change')}'),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: baslik,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final yeniDeger = controller.text.trim();
              if (yeniDeger.isEmpty && baslik != t('birthday')) {
                _snack('$baslik boş bırakılamaz.');
                return;
              }
              await _veriyiKaydet(key, yeniDeger);

              // Profil adi degisince tum sistemi guncelle
              if (key == 'profil_ad_soyad' && yeniDeger.isNotEmpty) {
                await AppSessionService.kullaniciAdiniKaydet(yeniDeger);
                try {
                  final session = ref.read(authProvider).value;
                  if (session != null && session.cloudEnabled && session.familyId != null) {
                    await CloudSyncService.instance.aileyeKatil(
                      session.familyId!,
                      session.userId,
                      yeniDeger,
                    );
                    await ref.read(authProvider.notifier).setSession(
                      session.copyWith(displayName: yeniDeger),
                    );
                  }
                } catch (_) {}
              }

              onSave(yeniDeger);
              if (context.mounted) Navigator.pop(context);
              _snack('$baslik başarıyla güncellendi.');
            },
            child: Text(t('save')),
          ),
        ],
      ),
    );
  }

  void _dogumTarihiSec() async {
    final ilkTarih = DateTime.tryParse(_dogumTarihi) ?? DateTime(1995, 1, 1);
    final secilen = await showDatePicker(
      context: context,
      initialDate: ilkTarih,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (secilen == null) return;

    final formatliTarih = "${secilen.day}.${secilen.month}.${secilen.year}";
    await _veriyiKaydet('profil_dogum_tarihi', formatliTarih);
    setState(() {
      _dogumTarihi = formatliTarih;
    });
    _snack('Doğum tarihi güncellendi.');
  }



  Future<void> _aileBilgileriniDuzenle(AuthSession session) async {
    final l10n = ref.read(languageProvider.notifier);
    String t(String key) => l10n.translate(key);

    final kodKontrolcu = TextEditingController(text: session.familyAccessCode);
    final aileAdiKontrolcu = TextEditingController(text: session.familyName);
    
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('edit_family_info')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('edit_family_desc')),
            const SizedBox(height: 12),
            TextField(
              controller: aileAdiKontrolcu,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t('family_name'),
                prefixIcon: const Icon(Icons.family_restroom_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kodKontrolcu,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: t('family_access_code'),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('update_info')),
          ),
        ],
      ),
    );
    if (onay != true) return;
    
    final yeniKod = kodKontrolcu.text.trim();
    final yeniAileAdi = aileAdiKontrolcu.text.trim();
    if (yeniKod.isEmpty || yeniAileAdi.isEmpty) return;

    setState(() => _yukleniyor = true);
    try {
      if (session.familyId != null) {
        await AppSessionService.aileAdiniKaydet(yeniAileAdi);
        await AppSessionService.authBilgisiniKaydet(
          mode: session.mode.name,
          userId: session.userId,
          email: session.email,
          sharedFarmCode: guvenliKodNormalizeEt(yeniKod),
        );
        await CloudSyncService.instance.aileBilgisiniGuncelle(
          session.familyId!,
          aileAdi: yeniAileAdi,
          erisimKodu: yeniKod,
        );
        await ref.read(authProvider.notifier).refreshSession();
        _snack(t('family_info_updated'));
      }
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  void _hesapAnahtariQrGoster(AuthSession session) {
    final l10n = ref.read(languageProvider.notifier);
    String t(String key) => l10n.translate(key);

    final kod = session.familyAccessCode ?? session.sharedFarmCode ?? '';
    final aileAdi = session.familyName ?? '';
    if (kod.isEmpty) {
      _snack('Ekip erişim kodu bulunamadı. Lütfen ekip bilgilerini güncelleyin.');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('invite_qr_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$aileAdi ${t('invite_qr_desc')}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: QrImageView(
                    data: ortakTarlaKodQrMetniOlustur(kod),
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                    errorStateBuilder: (cxt, err) {
                      return Center(
                        child: Text(
                          'QR Hata: $err',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    kod,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 3,
                      color: Color(0xFF1B5E35),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF1B5E35)),
                  tooltip: t('copy_code'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: kod));
                    _snack(t('code_copied'));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t('qr_instructions'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(languageProvider.notifier);
    String t(String key) => l10n.translate(key);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(authProvider).value;

    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return TasarimArkaPlani(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(t('profile_info')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            const SizedBox(height: 10),
            // Avatar with camera icon overlay
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: const Color(0xFF1B4332).withValues(alpha: 0.12),
                    backgroundImage: _fotoBase64 != null
                        ? MemoryImage(base64Decode(_fotoBase64!))
                        : null,
                    child: _fotoBase64 == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 74,
                            color: Color(0xFF1B4332),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: InkWell(
                      onTap: _fotoSecimMenusuGoster,
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B4332),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),

            // Profile info items list matching user screenshot layout

            _buildProfileField(
              title: t('name_surname'),
              value: _adSoyad,
              actionLabel: t('change'),
              onAction: () => _degerDuzenle(
                baslik: t('name_surname'),
                key: 'profil_ad_soyad',
                mevcutDeger: _adSoyad,
                onSave: (val) {
                  setState(() => _adSoyad = val);
                },
              ),
            ),
            _buildProfileField(
              title: t('birthday'),
              value: _dogumTarihi.isEmpty ? t('not_added') : _dogumTarihi,
              actionLabel: _dogumTarihi.isEmpty ? t('add') : t('change'),
              onAction: _dogumTarihiSec,
            ),
            _buildProfileField(
              title: t('email_label'),
              value: _ePosta.isEmpty ? t('not_added') : _ePosta,
              actionLabel: _ePosta.isEmpty ? t('add') : t('change'),
              onAction: () => _degerDuzenle(
                baslik: t('email_label'),
                key: 'profil_eposta',
                mevcutDeger: _ePosta,
                keyboardType: TextInputType.emailAddress,
                onSave: (val) => setState(() => _ePosta = val),
              ),
            ),
            _buildProfileField(
              title: t('phone_number'),
              value: _telefon,
              actionLabel: t('change'),
              onAction: () => _degerDuzenle(
                baslik: t('phone_number'),
                key: 'profil_telefon',
                mevcutDeger: _telefon,
                keyboardType: TextInputType.phone,
                onSave: (val) => setState(() => _telefon = val),
              ),
            ),

            
            // Family & Team Info restored card section
            if (session != null) ...[
              const SizedBox(height: 24),
              Card(
                color: isDark ? const Color(0xFF162A1F) : Colors.white.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.groups_outlined, color: isDark ? Colors.white70 : const Color(0xFF1B4332)),
                          const SizedBox(width: 8),
                          Text(
                            t('family_team_info'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1B4332),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Team Name Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('family_name'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  session.familyName ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1B3B2B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF4CAF50)),
                            onPressed: () => _aileBilgileriniDuzenle(session),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Team Access Code Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('family_access_code'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black26 : const Color(0xFFF1F8F4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? Colors.white10 : const Color(0xFFC8E6C9),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        session.familyAccessCode ?? session.sharedFarmCode ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 1,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: session.familyAccessCode ?? session.sharedFarmCode ?? ''));
                                          _snack(t('code_copied'));
                                        },
                                        child: const Icon(Icons.copy, size: 16, color: Color(0xFF2E7D32)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Show QR Code Button
                      FilledButton.icon(
                        onPressed: () => _hesapAnahtariQrGoster(session),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4332),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                        label: Text(
                          t('show_qr_code'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String title,
    required String value,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B3B2B),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
