import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'app_helpers.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.dateAndTime,
    ),
  );

  static void d(String message) {
    if (kDebugMode) {
      _logger.d(message);
    }
  }

  static void i(String message) {
    _logger.i(message);
    if (bulutDestegiAktif()) {
      try {
        FirebaseCrashlytics.instance.log('INFO: $message');
      } catch (_) {}
    }
  }

  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    if (bulutDestegiAktif()) {
      try {
        FirebaseCrashlytics.instance.log('WARNING: $message');
        if (error != null) {
          FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message, fatal: false);
        }
      } catch (_) {}
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    if (bulutDestegiAktif()) {
      try {
        FirebaseCrashlytics.instance.log('ERROR: $message');
        FirebaseCrashlytics.instance.recordError(
          error ?? Exception(message),
          stackTrace,
          reason: message,
          fatal: true,
        );
      } catch (_) {}
    }
  }
}
