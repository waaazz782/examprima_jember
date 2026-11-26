import 'package:flutter/services.dart';

class KioskModeService {
  KioskModeService._() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onWindowFocusChanged':
          final bool hasFocus = call.arguments as bool? ?? true;
          onWindowFocusChanged?.call(hasFocus);
          break;
        case 'onMultiWindowDetected':
          onMultiWindowDetected?.call();
          break;
        case 'onLockTaskDropped':
          onLockTaskDropped?.call();
          break;
        case 'onForceExitAttempt':
          onForceExitAttempt?.call();
          break;
        case 'onBackBlocked':
          onBackBlocked?.call();
          break;
      }
    });
  }

  static final KioskModeService instance = KioskModeService._();

  static const MethodChannel _channel =
      MethodChannel('com.examprimajember/kiosk');

  /// Callback saat fokus window berubah (mis. status bar ditarik atau floating app muncul)
  void Function(bool hasFocus)? onWindowFocusChanged;

  /// Callback saat layar dibelah (Split-screen) atau PiP terdeteksi
  void Function()? onMultiWindowDetected;

  /// Callback saat screen pinning / lock task mode terlepas
  void Function()? onLockTaskDropped;

  /// Callback saat siswa mencoba menekan Home / berpindah aplikasi
  void Function()? onForceExitAttempt;

  /// Callback saat tombol / gestur back Android ditekan dan diblokir native
  void Function()? onBackBlocked;

  Future<void> start() async {
    try {
      await _channel.invokeMethod('startKioskMode');
    } catch (_) {
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopKioskMode');
    } catch (_) {
    }
  }

  Future<void> setSecureFlag(bool enabled) async {
    try {
      await _channel.invokeMethod('setSecureFlag', {'enabled': enabled});
    } catch (_) {
    }
  }

  Future<void> ensureAudibleVolume() async {
    try {
      await _channel.invokeMethod('ensureAudibleVolume');
    } catch (_) {
    }
  }

  Future<void> playWarningSiren() async {
    try {
      await _channel.invokeMethod('playWarningSiren');
    } catch (_) {
    }
  }

  Future<void> playExitVoice() async {
    try {
      await _channel.invokeMethod('playExitVoice');
    } catch (_) {
    }
  }
}