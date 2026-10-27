import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_session_service.dart';
import '../cloud_sync_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';
import '../utils/app_helpers.dart';
import '../utils/app_logger.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthSession?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    return _loadSession();
  }

  Future<AuthSession?> _loadSession() async {
    try {
      final authModu = await AppSessionService.authModunuGetir();
      final kayitliAd = await AppSessionService.kullaniciAdiniGetir();
      final kayitliOrtakKod = await AppSessionService.aktifOrtakTarlaKodunuGetir();
      final kayitliAileId = await AppSessionService.kayitliAileKodunuGetir();
      
      final ilkOrtakTarlaKodu = guvenliKodNormalizeEt(kayitliOrtakKod ?? '');

      if (authModu == AuthMode.firebase.name && bulutDestegiAktif()) {
        final user = FirebaseAuthService.currentUser();
        var aileId = (kayitliAileId ?? '').trim();
        
        if (user != null && aileId.isEmpty && ilkOrtakTarlaKodu.isNotEmpty) {
          final bulunanAile = await CloudSyncService.instance.erisimKoduIleAileBul(
            ilkOrtakTarlaKodu,
          );
          aileId = bulunanAile?.aileKodu ?? '';
        }
        
        if (user != null && aileId.isNotEmpty) {
          final displayName = kayitliAd?.trim().isNotEmpty == true
              ? kayitliAd!.trim()
              : (user.email?.split('@').first ?? 'Kullanici');
              
          final aileBilgisi = await CloudSyncService.instance.aileBilgisiGetir(aileId, callerUserId: user.uid);
          final yerelAileAdi = await AppSessionService.aileAdiniGetir();
          final aileAdi = (yerelAileAdi != null && yerelAileAdi.isNotEmpty) ? yerelAileAdi : aileBilgisi.aileAdi;
          
          final session = AuthSession(
            mode: AuthMode.firebase,
            userId: user.uid,
            displayName: displayName,
            email: user.email,
            cloudEnabled: true,
            sharedFarmCode: aileBilgisi.erisimKodu,
            familyId: aileBilgisi.aileKodu,
            familyName: aileAdi,
            familyAccessCode: aileBilgisi.erisimKodu,
            isFamilyOwner: aileBilgisi.olusturanKullaniciId == user.uid,
          );
          
          // Save back to local storage
          await AppSessionService.authBilgisiniKaydet(
            mode: session.mode.name,
            userId: session.userId,
            email: session.email,
            sharedFarmCode: session.sharedFarmCode,
          );
          await AppSessionService.kullaniciAdiniKaydet(session.displayName);
          if (session.familyId != null) {
            await AppSessionService.aileKodunuKaydet(session.familyId!);
          }
          if (session.familyName != null) {
            await AppSessionService.aileAdiniKaydet(session.familyName!);
          }
          
          return session;
        }
      } else if (authModu == AuthMode.local.name) {
        // Cloud-first moda gecis: eski yerel oturumlar otomatik sifirlanir.
        await AppSessionService.authBilgisiniTemizle();
        await AppSessionService.aileKodunuTemizle();
      }
      return null;
    } catch (e) {
      // Return null on error, UI can decide what to do
      return null;
    }
  }

  Future<void> refreshSession() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadSession());
  }

  Future<void> setSession(AuthSession session) async {
    await AppSessionService.authBilgisiniKaydet(
      mode: session.mode.name,
      userId: session.userId,
      email: session.email,
      sharedFarmCode: session.sharedFarmCode,
    );
    await AppSessionService.kullaniciAdiniKaydet(session.displayName);
    if (session.familyId != null) {
      await AppSessionService.aileKodunuKaydet(session.familyId!);
    }
    if (session.familyName != null) {
      await AppSessionService.aileAdiniKaydet(session.familyName!);
    }
    state = AsyncValue.data(session);
  }

  Future<void> clearSession() async {
    await AppSessionService.authBilgisiniTemizle();
    await AppSessionService.aileKodunuTemizle();
    await AppSessionService.aileAdiniTemizle();
    state = const AsyncValue.data(null);
  }

  // Yönetici: e-posta + şifre ile kayıt/giriş, aile otomatik oluşturulur
  Future<void> firebaseYoneticiGirisYap({
    required String email,
    required String password,
    required String displayName,
    required String familyName,
    required bool kayitOl,
  }) async {
    state = const AsyncValue.loading();
    try {
      if (!bulutDestegiAktif()) throw Exception('Bu cihazda bulut modu desteklenmiyor');

      final temizEmail = email.trim();
      final gorunenAd = displayName.trim().isEmpty ? temizEmail.split('@').first : displayName.trim();

      UserCredential sonuc;
      if (kayitOl) {
        sonuc = await FirebaseAuthService.register(email: temizEmail, password: password);
      } else {
        sonuc = await FirebaseAuthService.signIn(email: temizEmail, password: password);
      }

      final user = sonuc.user;
      if (user == null) throw Exception('Firebase oturumu açılamadı');

      // Kayıtlı aile ID'si var mı?
      final kayitliAileId = await AppSessionService.kayitliAileKodunuGetir();
      AileBilgisi aileBilgisi;

      if (kayitliAileId != null && kayitliAileId.trim().isNotEmpty) {
        // Mevcut aileyi yükle
        aileBilgisi = await CloudSyncService.instance.aileBilgisiGetir(kayitliAileId.trim(), callerUserId: user.uid);
        if (aileBilgisi.olusturanKullaniciId == null) {
          if (!kayitOl) {
            throw Exception('Bu e-postaya bağlı ekip bulunamadı. Lütfen "Kayıt Ol" ile ekip oluştur.');
          }
          final temizAileAdi = familyName.trim().isEmpty ? '${gorunenAd.split(' ').first} Ekibi' : familyName.trim();
          aileBilgisi = await CloudSyncService.instance.yeniAileOlustur(user.uid, temizAileAdi, gorunenAd);
        }
      } else {
        // Firestore'da bu kullanıcıya ait aile var mı?
        final mevcutAile = await CloudSyncService.instance.kullaniciAilesiniGetir(user.uid);
        if (mevcutAile != null && mevcutAile.olusturanKullaniciId != null) {
          aileBilgisi = mevcutAile;
        } else {
          if (!kayitOl) {
            // Giriş yapıyor ama aile yok — yeniden kayıt gerekiyor
            throw Exception(
              'Bu e-postaya bağlı ekip bulunamadı. Lütfen "Kayıt Ol" ile ekip oluştur.',
            );
          }
          // Yeni ekip oluştur
          final temizAileAdi = familyName.trim().isEmpty ? '${gorunenAd.split(' ').first} Ekibi' : familyName.trim();
          aileBilgisi = await CloudSyncService.instance.yeniAileOlustur(user.uid, temizAileAdi, gorunenAd);
        }
      }

      // Üye kaydını güncelle
      await CloudSyncService.instance.aileyeKatil(aileBilgisi.aileKodu, user.uid, gorunenAd);

      final session = AuthSession(
        mode: AuthMode.firebase,
        userId: user.uid,
        displayName: gorunenAd,
        email: user.email,
        cloudEnabled: true,
        sharedFarmCode: aileBilgisi.erisimKodu,
        familyId: aileBilgisi.aileKodu,
        familyName: aileBilgisi.aileAdi,
        familyAccessCode: aileBilgisi.erisimKodu,
        isFamilyOwner: aileBilgisi.olusturanKullaniciId == user.uid,
      );
      await setSession(session);

      try {
        final ok = await CloudSyncService.instance.yereldenBulutaSenkronizeEt(aileBilgisi.aileKodu);
        await CloudSyncService.instance.buluttanYereleSenkronizeEt(aileBilgisi.aileKodu, tamEslestir: ok);
      } catch (syncErr, syncSt) {
        AppLogger.w('Yönetici giriş senkronizasyonu başarısız: $syncErr', syncErr, syncSt);
      }
    } catch (e, st) {
      AppLogger.e('Yönetici girişi/kaydı başarısız', e, st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Google ile giriş ve otomatik aile ilişkilendirmesi
  Future<void> googleIleGirisYap() async {
    state = const AsyncValue.loading();
    try {
      if (!bulutDestegiAktif()) throw Exception('Bu cihazda bulut modu desteklenmiyor');

      final sonuc = await FirebaseAuthService.signInWithGoogle();
      final user = sonuc.user;
      if (user == null) throw Exception('Google oturumu açılamadı');

      final googleAd = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email != null ? user.email!.split('@').first : 'Google Uyesi');

      // Firestore'da bu kullaniciya ait aile var mi?
      AileBilgisi aileBilgisi;
      final mevcutAile = await CloudSyncService.instance.kullaniciAilesiniGetir(user.uid);
      if (mevcutAile != null && mevcutAile.olusturanKullaniciId != null) {
        aileBilgisi = mevcutAile;
      } else {
        // Yeni aile olustur
        final temizAileAdi = '${googleAd.split(' ').first} Ailesi';
        aileBilgisi = await CloudSyncService.instance.yeniAileOlustur(user.uid, temizAileAdi, googleAd);
      }

      // Mevcut Firestore uye adini tercih et (diger cihazda guncellenmis olabilir)
      String gorunenAd = googleAd;
      try {
        final prefs = await SharedPreferences.getInstance();
        final kayitliAd = prefs.getString('profil_ad_soyad') ?? '';
        if (kayitliAd.isNotEmpty) {
          gorunenAd = kayitliAd;
        }
      } catch (_) {}

      // Üye kaydını güncelle
      await CloudSyncService.instance.aileyeKatil(aileBilgisi.aileKodu, user.uid, gorunenAd);

      final session = AuthSession(
        mode: AuthMode.firebase,
        userId: user.uid,
        displayName: gorunenAd,
        email: user.email,
        cloudEnabled: true,
        sharedFarmCode: aileBilgisi.erisimKodu,
        familyId: aileBilgisi.aileKodu,
        familyName: aileBilgisi.aileAdi,
        familyAccessCode: aileBilgisi.erisimKodu,
        isFamilyOwner: aileBilgisi.olusturanKullaniciId == user.uid,
      );
      await setSession(session);

      try {
        final ok = await CloudSyncService.instance.yereldenBulutaSenkronizeEt(aileBilgisi.aileKodu);
        await CloudSyncService.instance.buluttanYereleSenkronizeEt(aileBilgisi.aileKodu, tamEslestir: ok);
      } catch (syncErr, syncSt) {
        AppLogger.w('Google giriş senkronizasyonu başarısız: $syncErr', syncErr, syncSt);
      }
    } catch (e, st) {
      AppLogger.e('Google girişi başarısız', e, st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Üye: QR'dan okunan aile erişim koduyla anonim katılım
  Future<void> qrIleUyeKatil({
    required String sharedFarmCode,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      if (!bulutDestegiAktif()) throw Exception('Bu cihazda bulut modu desteklenmiyor');

      final ortakKod = guvenliKodNormalizeEt(sharedFarmCode);
      if (ortakKod.isEmpty) throw Exception('Geçerli bir ekip kodu bulunamadı.');

      final gorunenAd = displayName.trim().isEmpty ? 'Üye' : displayName.trim();

      // Anonim Firebase oturumu aç
      final sonuc = await FirebaseAuthService.signInAnonymously();
      final user = sonuc.user;
      if (user == null) throw Exception('Oturum açılamadı');

      // Aileyi ekip koduyla bul
      final aileBilgisi = await CloudSyncService.instance.erisimKoduIleAileBul(ortakKod);
      if (aileBilgisi == null) {
        throw Exception(
          'Bu QR koda ait ekip bulunamadı. Yöneticiden güncel QR kodu isteyin.',
        );
      }

      // Aileye katıl
      await CloudSyncService.instance.aileyeKatil(aileBilgisi.aileKodu, user.uid, gorunenAd);

      final session = AuthSession(
        mode: AuthMode.firebase,
        userId: user.uid,
        displayName: gorunenAd,
        email: null,
        cloudEnabled: true,
        sharedFarmCode: ortakKod,
        familyId: aileBilgisi.aileKodu,
        familyName: aileBilgisi.aileAdi,
        familyAccessCode: aileBilgisi.erisimKodu,
        isFamilyOwner: false,
      );
      await setSession(session);

      try {
        await CloudSyncService.instance.buluttanYereleSenkronizeEt(aileBilgisi.aileKodu, tamEslestir: false);
      } catch (syncErr, syncSt) {
        AppLogger.w('QR katılım senkronizasyonu başarısız: $syncErr', syncErr, syncSt);
      }
    } catch (e, st) {
      AppLogger.e('QR ile ekibe katılım başarısız', e, st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Şifre sıfırlama maili gönder
  Future<void> sifreSifirlamaGonder(String email) async {
    await FirebaseAuthService.sendPasswordResetEmail(email.trim());
  }

  // Eski uyumluluk için alias
  Future<void> firebaseGirisYap({
    String? email,
    String? password,
    required String displayName,
    required String sharedFarmCode,
    String? familyName,
    required bool kayitOl,
  }) async {
    if (email != null && password != null) {
      await firebaseYoneticiGirisYap(
        email: email,
        password: password,
        displayName: displayName,
        familyName: familyName ?? '',
        kayitOl: kayitOl,
      );
    } else {
      await qrIleUyeKatil(sharedFarmCode: sharedFarmCode, displayName: displayName);
    }
  }
}
