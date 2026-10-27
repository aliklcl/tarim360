import 'screens/screens.dart';
import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_session_service.dart';
import 'cloud_sync_service.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'utils/app_helpers.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  if (bulutDestegiAktif()) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _crashlyticsKurulumuYap();
  }
  await initializeDateFormatting('tr_TR');
  runApp(
    const ProviderScope(
      child: TarlaTakipApp(),
    ),
  );
}

Future<void> _crashlyticsKurulumuYap() async {
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  final oncekiHataYakalayici = FlutterError.onError;
  FlutterError.onError = (details) {
    oncekiHataYakalayici?.call(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

class TarlaTakipApp extends StatelessWidget {
  const TarlaTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ─── Light theme ──────────────────────────────────────────
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2D6A4F),
      primary: const Color(0xFF2D6A4F), // Premium Forest Green
      secondary: const Color(0xFFD4A373), // Warm Sand / Gold
      surface: const Color(0xFFF8F9FA),
    );
    final lightBase = ThemeData(colorScheme: lightScheme, useMaterial3: true);

    // ─── Dark theme ───────────────────────────────────────────
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF10B981),
      brightness: Brightness.dark,
      primary: const Color(0xFF10B981), // Vibrant Emerald Green
      secondary: const Color(0xFFFDB022), // Warm Amber / Gold
      surface: const Color(0xFF0C1612), // Deep Forest Black
    );
    final darkBase = ThemeData(colorScheme: darkScheme, useMaterial3: true, brightness: Brightness.dark);

    return MaterialApp(
      title: 'Tarim360',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],

      // ── LIGHT ──
      theme: lightBase.copyWith(
        textTheme: GoogleFonts.interTextTheme(lightBase.textTheme).copyWith(
          titleLarge: GoogleFonts.inter(
            textStyle: lightBase.textTheme.titleLarge,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
          titleMedium: lightBase.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          bodyMedium: lightBase.textTheme.bodyMedium?.copyWith(fontSize: 14.5, height: 1.35),
          bodySmall: lightBase.textTheme.bodySmall?.copyWith(fontSize: 12.5, height: 1.3),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: Colors.transparent, // Transparent for global background
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1B4332),
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(color: Color(0xFF1B4332), fontSize: 23, fontWeight: FontWeight.w800),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.70), // Glassmorphic effect
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: const Color(0xFF2D6A4F).withValues(alpha: 0.08)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2D6A4F),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2D6A4F),
            side: BorderSide(color: const Color(0xFF2D6A4F).withValues(alpha: 0.24)),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        chipTheme: lightBase.chipTheme.copyWith(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B4332),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.85),
          indicatorColor: const Color(0xFF2D7A4F).withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2D7A4F),
              );
            }
            return TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF2D7A4F), size: 24);
            }
            return IconThemeData(color: Colors.grey.shade500, size: 22);
          }),
        ),
      ),

      // ── DARK ──
      darkTheme: darkBase.copyWith(
        textTheme: GoogleFonts.interTextTheme(darkBase.textTheme).copyWith(
          titleLarge: GoogleFonts.inter(
            textStyle: darkBase.textTheme.titleLarge,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
          titleMedium: darkBase.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          bodyMedium: darkBase.textTheme.bodyMedium?.copyWith(fontSize: 14.5, height: 1.35),
          bodySmall: darkBase.textTheme.bodySmall?.copyWith(fontSize: 12.5, height: 1.3),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: Colors.transparent, // Transparent for global background
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Color(0xFF121E19),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFFE8F5E9),
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(color: Color(0xFFE8F5E9), fontSize: 23, fontWeight: FontWeight.w800),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF101B15).withValues(alpha: 0.75), // Glassmorphic dark emerald
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.15)), // Glowing emerald borders
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF10B981),
            side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        chipTheme: darkBase.chipTheme.copyWith(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF12241C),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0A1A12).withValues(alpha: 0.92),
          indicatorColor: const Color(0xFF10B981).withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981),
              );
            }
            return TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF10B981), size: 24);
            }
            return IconThemeData(color: Colors.grey.shade600, size: 22);
          }),
        ),
      ),

      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Location request on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      acilistaKonumIzniIste(context);
    });

    final authState = ref.watch(authProvider);

    return authState.when(
      data: (oturum) {
        if (oturum == null) {
          return GenelGirisSayfasi(
            bulutDestegi: bulutDestegiAktif(),
            initialSharedFarmCode: '',
          );
        }

        return TarlaListesi(
          aileKodu: oturum.familyId ?? oturum.userId,
          ortakTarlaKodu: oturum.sharedFarmCode ?? '',
          aileAdi: oturum.familyName ?? (oturum.mode == AuthMode.firebase ? 'Ekibim' : 'Yerel hesap'),
          aileErisimKodu: oturum.familyAccessCode ?? oturum.sharedFarmCode ?? oturum.email,
          bulutEtkin: oturum.cloudEnabled,
          kullaniciAdi: oturum.displayName,
          currentKullaniciId: oturum.userId,
          aileSahibiMi: oturum.isFamilyOwner,
          onAileDegistir: () async {
            if (oturum.mode == AuthMode.firebase) {
              await FirebaseAuthService.signOut();
            }
            await ref.read(authProvider.notifier).clearSession();
          },
          onOrtakTarlaKodunuDegistir: (String yeniKod) async {
            final oturum = ref.read(authProvider).value;
            if (oturum != null) {
              await AppSessionService.authBilgisiniKaydet(
                mode: oturum.mode.name,
                userId: oturum.userId,
                email: oturum.email,
                sharedFarmCode: guvenliKodNormalizeEt(yeniKod),
              );
            }
            await ref.read(authProvider.notifier).refreshSession();
          },
          onAileBilgisiniDegistir: ({required String yeniAileAdi, required String yeniKod}) async {
            final oturum = ref.read(authProvider).value;
            if (oturum != null) {
              await AppSessionService.aileAdiniKaydet(yeniAileAdi.trim());
              await AppSessionService.authBilgisiniKaydet(
                mode: oturum.mode.name,
                userId: oturum.userId,
                email: oturum.email,
                sharedFarmCode: guvenliKodNormalizeEt(yeniKod),
              );
              if (oturum.familyId != null) {
                await CloudSyncService.instance.aileBilgisiniGuncelle(
                  oturum.familyId!,
                  aileAdi: yeniAileAdi,
                  erisimKodu: yeniKod,
                );
              }
            }
            await ref.read(authProvider.notifier).refreshSession();
          },
          yerelModBilgisi: null,
          onBulutuTekrarDene: () async {
            ref.read(authProvider.notifier).refreshSession();
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  bulutHataMetni(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).refreshSession();
                  },
                  child: const Text('Tekrar Dene'),
                ),
                TextButton(
                  onPressed: () async {
                    await AppSessionService.authBilgisiniTemizle();
                    ref.read(authProvider.notifier).refreshSession();
                  },
                  child: const Text('Yerel Hesaba Dön'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
