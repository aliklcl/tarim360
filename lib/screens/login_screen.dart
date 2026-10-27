import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_helpers.dart';
import '../widgets/tasarim_arka_plani.dart';

// Ana giriş sayfası — iki yol sunar: Yönetici girişi, Üye QR ile katılım
class GenelGirisSayfasi extends ConsumerStatefulWidget {
  const GenelGirisSayfasi({
    super.key,
    required this.bulutDestegi,
    required this.initialSharedFarmCode,
  });

  final bool bulutDestegi;
  final String initialSharedFarmCode;

  @override
  ConsumerState<GenelGirisSayfasi> createState() => _GenelGirisSayfasiState();
}

class _GenelGirisSayfasiState extends ConsumerState<GenelGirisSayfasi>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final currentLang = ref.watch(languageProvider);
    final l10n = ref.read(languageProvider.notifier);
    String t(String key) => l10n.translate(key);

    return TasarimArkaPlani(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  const SizedBox(height: 20),
                  // Logo / Başlık — Premium tasarım
                  Column(
                    children: [
                      // Logo - uygulama simgesiyle birebir aynı
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D3B14), // Aynı koyu yeşil arka plan
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1D3B14).withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/icons/app_icon_foreground.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                'assets/icons/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Brand name — styled
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: t('brand_title').contains('Tarım') ? 'Tarım' : 'Tarim',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1,
                              ),
                            ),
                            const TextSpan(
                              text: '360',
                              style: TextStyle(
                                color: Color(0xFFA8E6BB),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        t('brand_subtitle'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Version badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: Text(
                          t('version_badge'),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 500.ms).slideY(begin: -0.1),
                  const SizedBox(height: 28),

                  // Tab seçici
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: const Color(0xFF1B5E35),
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                          text: t('tab_manager'),
                        ),
                        Tab(
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          text: t('tab_member'),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 500.ms, delay: 150.ms),
                  const SizedBox(height: 16),

                  // Tab içerikleri
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 500, maxHeight: 680),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _YoneticiGirisKarti(bulutDestegi: widget.bulutDestegi),
                        const _QrUyeKatilimKarti(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Created by Ali Kılıçlı — sabit sağ alt imza
        bottomNavigationBar: Container(
        height: 38,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2D1A), Color(0xFF1B5E35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.code_rounded,
                      size: 13, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 5),
                  Text(
                    'Created by Ali Kılıçlı',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
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

// ─── Yönetici Girişi ─────────────────────────────────────────────────────────

class _YoneticiGirisKarti extends ConsumerStatefulWidget {
  const _YoneticiGirisKarti({required this.bulutDestegi});
  final bool bulutDestegi;

  @override
  ConsumerState<_YoneticiGirisKarti> createState() => _YoneticiGirisKartiState();
}

class _YoneticiGirisKartiState extends ConsumerState<_YoneticiGirisKarti> {
  final _emailCtrl = TextEditingController();
  final _sifreCtrl = TextEditingController();
  final _adCtrl = TextEditingController();
  final _aileAdiCtrl = TextEditingController();
  bool _kayitModu = false;
  bool _islemde = false;
  bool _sifreGizli = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _sifreCtrl.dispose();
    _adCtrl.dispose();
    _aileAdiCtrl.dispose();
    super.dispose();
  }

  Future<void> _devamEt() async {
    final email = _emailCtrl.text.trim();
    final sifre = _sifreCtrl.text.trim();
    final adRaw = _adCtrl.text.trim();

    if (email.isEmpty || sifre.isEmpty) {
      _snack('E-posta ve şifre zorunlu.');
      return;
    }

    // İsim doğrulama
    final isimHata = isimDogrula(adRaw);
    if (isimHata != null) {
      _snack(isimHata);
      return;
    }
    final ad = isimFormatla(adRaw);

    setState(() => _islemde = true);
    try {
      await ref.read(authProvider.notifier).firebaseYoneticiGirisYap(
        email: email,
        password: sifre,
        displayName: ad,
        familyName: _aileAdiCtrl.text.trim().isEmpty
            ? '${ad.split(' ').first} Ekibi'
            : _aileAdiCtrl.text.trim(),
        kayitOl: _kayitModu,
      );
      if (mounted) _snack(_kayitModu ? 'Hesap oluşturuldu! Hoş geldin, $ad.' : 'Giriş başarılı! Hoş geldin, $ad.');
    } catch (e) {
      if (e is FirebaseAuthException && _kayitModu && e.code == 'email-already-in-use') {
        setState(() => _kayitModu = false);
      }
      if (mounted) _snack(bulutHataMetni(e));
    } finally {
      if (mounted) setState(() => _islemde = false);
    }
  }
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(languageProvider);
    final l10n = ref.read(languageProvider.notifier);
    String t(String key) => l10n.translate(key);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mod seçici
            Row(
              children: [
                Expanded(
                  child: _ModButon(
                    label: t('login'),
                    secili: !_kayitModu,
                    onTap: () => setState(() => _kayitModu = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModButon(
                    label: t('register'),
                    secili: _kayitModu,
                    onTap: () => setState(() => _kayitModu = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (_kayitModu)
              _AciklamaKutusu(
                ikon: Icons.info_outline,
                metin: t('manager_register_desc'),
              ),
            if (!_kayitModu)
              _AciklamaKutusu(
                ikon: Icons.security_outlined,
                metin: t('manager_login_desc'),
              ),
            const SizedBox(height: 14),

            _Alan(
              controller: _emailCtrl,
              label: t('email'),
              ikon: Icons.email_outlined,
              klavye: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            _Alan(
              controller: _sifreCtrl,
              label: t('password'),
              ikon: Icons.lock_outline,
              gizli: _sifreGizli,
              sonEk: IconButton(
                icon: Icon(_sifreGizli ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _sifreGizli = !_sifreGizli),
              ),
            ),
            const SizedBox(height: 10),
            _Alan(
              controller: _adCtrl,
              label: t('name_field'),
              ikon: Icons.badge_outlined,
              buyukHarf: TextCapitalization.words,
            ),
            if (_kayitModu) ...[
              const SizedBox(height: 10),
              _Alan(
                controller: _aileAdiCtrl,
                label: t('family_name_field'),
                ikon: Icons.family_restroom_outlined,
                buyukHarf: TextCapitalization.words,
                ipucu: currentLang == 'en' ? 'e.g. Smith Team' : 'Örn: Yıldız Ekibi',
              ),
            ],
            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: _islemde ? null : _devamEt,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _islemde
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.arrow_forward),
              label: Text(
                _kayitModu
                    ? (currentLang == 'en' ? 'Create Manager Account' : 'Yönetici Hesabı Oluştur')
                    : t('login'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(t('or'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _islemde
                  ? null
                  : () async {
                      setState(() => _islemde = true);
                      try {
                        await ref.read(authProvider.notifier).googleIleGirisYap();
                        if (mounted) _snack('Google ile giriş başarılı!');
                      } catch (e) {
                        if (mounted) _snack(bulutHataMetni(e));
                      } finally {
                        if (mounted) setState(() => _islemde = false);
                      }
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
              label: Text(t('google_btn'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
      ),
      ),
    );
  }
}

// ─── QR ile Üye Katılımı ─────────────────────────────────────────────────────

class _QrUyeKatilimKarti extends ConsumerStatefulWidget {
  const _QrUyeKatilimKarti();

  @override
  ConsumerState<_QrUyeKatilimKarti> createState() => _QrUyeKatilimKartiState();
}

class _QrUyeKatilimKartiState extends ConsumerState<_QrUyeKatilimKarti> {
  final _adCtrl = TextEditingController();
  String? _tarananKod;
  bool _islemde = false;
  bool _kameraAcik = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    super.dispose();
  }

  Future<void> _qrTara() async {
    if (_kameraAcik) {
      setState(() => _kameraAcik = false);
      return;
    }

    final izin = await kameraBilgilendirmesiniGoster(context, amac: 'QR kod okutmak');
    if (!izin) return;

    setState(() {
      _kameraAcik = true;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final kod = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (kod == null || kod.isEmpty) return;
    final cozulen = ortakTarlaKodunuQrMetnindenCoz(kod);
    setState(() {
      _tarananKod = cozulen;
      _kameraAcik = false;
    });
    _snack('QR kodu başarıyla okundu! Şimdi adını gir.');
  }

  Future<void> _katil() async {
    final adRaw = _adCtrl.text.trim();
    if (_tarananKod == null || _tarananKod!.isEmpty) {
      _snack('Önce QR kodu okutman gerekiyor.');
      return;
    }
    // İsim doğrulama
    final isimHata = isimDogrula(adRaw);
    if (isimHata != null) {
      _snack(isimHata);
      return;
    }
    final ad = isimFormatla(adRaw);

    setState(() => _islemde = true);
    try {
      await ref.read(authProvider.notifier).qrIleUyeKatil(
        sharedFarmCode: _tarananKod!,
        displayName: ad,
      );
      if (mounted) _snack('Ekibe katıldın! Hoş geldin, $ad.');
    } catch (e) {
      if (mounted) _snack(bulutHataMetni(e));
    } finally {
      if (mounted) setState(() => _islemde = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(languageProvider);
    final l10n = ref.read(languageProvider.notifier);
    String t(String key) => l10n.translate(key);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AciklamaKutusu(
              ikon: Icons.groups_outlined,
              metin: t('qr_desc'),
            ),
            const SizedBox(height: 20),

            // Adım 1: QR Tara
            _AdimKutusu(
              adim: '1',
              baslik: t('step1_title'),
              tamamlandi: _tarananKod != null,
              child: Column(
                children: [
                  if (_tarananKod != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF4CAF50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${t('family_access_code')}: $_tarananKod',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_kameraAcik) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            MobileScanner(
                              onDetect: _onDetect,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF1B5E35), width: 3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withValues(alpha: 0.5),
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                  onPressed: () => setState(() => _kameraAcik = false),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Text(
                                currentLang == 'en' ? 'Align the QR code' : 'QR kodu hizalayın',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: _islemde ? null : _qrTara,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B5E35),
                      side: const BorderSide(color: Color(0xFF1B5E35), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_kameraAcik ? Icons.camera_alt_outlined : Icons.qr_code_scanner_rounded),
                    label: Text(
                      _kameraAcik
                          ? (currentLang == 'en' ? 'Close Camera' : 'Kamerayı Kapat')
                          : _tarananKod == null
                              ? t('step1_title')
                              : (currentLang == 'en' ? 'Scan Again' : 'Tekrar Okut'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Adım 2: İsim Gir
            _AdimKutusu(
              adim: '2',
              baslik: t('step2_title'),
              aktif: _tarananKod != null,
              child: _Alan(
                controller: _adCtrl,
                label: currentLang == 'en' ? 'Your Name (visible to team)' : 'Adın (ekipte görünecek)',
                ikon: Icons.person_outline,
                buyukHarf: TextCapitalization.words,
                ipucu: currentLang == 'en' ? 'e.g. John' : 'Örn: Mehmet',
                etkin: _tarananKod != null,
                autofillHints: const [AutofillHints.name],
              ),
            ),
            const SizedBox(height: 14),

            // Adım 3: Katıl
            _AdimKutusu(
              adim: '3',
              baslik: t('step3_title'),
              aktif: _tarananKod != null,
              child: FilledButton.icon(
                onPressed: (_islemde || _tarananKod == null) ? null : _katil,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _islemde
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.group_add_outlined),
                label: Text(t('step3_title'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
      ),
      ),
    );
  }
}

// ─── Yardımcı widget'lar ─────────────────────────────────────────────────────

class _ModButon extends StatelessWidget {
  const _ModButon({required this.label, required this.secili, required this.onTap});
  final String label;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: secili ? const Color(0xFF1B5E35) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: secili ? Colors.white : Colors.grey.shade600,
            fontWeight: secili ? FontWeight.w800 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _AciklamaKutusu extends StatelessWidget {
  const _AciklamaKutusu({required this.ikon, required this.metin});
  final IconData ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              metin,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdimKutusu extends StatelessWidget {
  const _AdimKutusu({
    required this.adim,
    required this.baslik,
    required this.child,
    this.aktif = true,
    this.tamamlandi = false,
  });
  final String adim;
  final String baslik;
  final Widget child;
  final bool aktif;
  final bool tamamlandi;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: aktif ? 1.0 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: tamamlandi
                      ? const Color(0xFF2E7D32)
                      : aktif
                          ? const Color(0xFF1B5E35).withValues(alpha: 0.12)
                          : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: tamamlandi
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        adim,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: aktif ? const Color(0xFF1B5E35) : Colors.grey,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                baslik,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: aktif ? Colors.grey.shade800 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Alan extends StatelessWidget {
  const _Alan({
    required this.controller,
    required this.label,
    required this.ikon,
    this.klavye,
    this.buyukHarf = TextCapitalization.none,
    this.gizli = false,
    this.sonEk,
    this.ipucu,
    this.etkin = true,
    this.autofillHints,
  });
  final TextEditingController controller;
  final String label;
  final IconData ikon;
  final TextInputType? klavye;
  final TextCapitalization buyukHarf;
  final bool gizli;
  final Widget? sonEk;
  final String? ipucu;
  final bool etkin;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: etkin,
      keyboardType: klavye,
      textCapitalization: buyukHarf,
      obscureText: gizli,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        hintText: ipucu,
        prefixIcon: Icon(ikon),
        suffixIcon: sonEk,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: etkin ? Colors.grey.shade50 : Colors.grey.shade100,
      ),
    );
  }
}

// QR kodu gösterme dialog'u — ayarlar ekranından da çağrılabilir
class QrKoduGosterDialog extends StatelessWidget {
  const QrKoduGosterDialog({super.key, required this.erisimKodu, required this.aileAdi});
  final String erisimKodu;
  final String aileAdi;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Üye Davet QR Kodu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$aileAdi ekibine üye davet etmek için bu kodu okutun.',
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
            child: QrImageView(
              data: ortakTarlaKodQrMetniOlustur(erisimKodu),
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
                  erisimKodu,
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
                tooltip: 'Kodu kopyala',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: erisimKodu));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ekip kodu panoya kopyalandı!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Üye QR Okut → İsim Gir → Katıl adımlarını takip eder.',
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
    );
  }
}
