# MASTER PROMPT: PENGEMBANGAN DAN HARDENING APLIKASI EXAMBROWSER KIOSK (FLUTTER & ANDROID NATIVE)

Dokumen ini dirancang sebagai **Master Prompt / Spesifikasi Teknis Lengkap** untuk menginstruksikan AI atau pengembang dalam membangun, memperkuat (*security hardening*), dan mengonfigurasi aplikasi **ExamBrowser Kiosk** anti-curang berbasis Flutter dan Android Native (Studi Kasus: ExamPrima).

---

## 1. SISTEM PERSONA & TUJUAN PROYEK

> **Instruksi untuk AI / Pengembang:**
> Anda bertindak sebagai Senior Flutter & Android Security Engineer. Tugas Anda adalah membangun dan mengamankan aplikasi **ExamBrowser Kiosk** untuk pelaksanaan ujian sekolah berbasis komputer/web (CBT). Aplikasi harus mengunci perangkat siswa secara ketat (*kiosk mode*) agar siswa tidak dapat membuka contekan, membelah layar, keluar dari aplikasi, menyalin teks soal, mengambil tangkapan layar, maupun menggunakan kecerdasan buatan (AI) / solver.

### Sasaran Utama Keamanan:
1. **Blokir Belah Layar (Split-Screen / Multi-Window / PiP):** Mencegah siswa membuka dua aplikasi sekaligus.
2. **Blokir Screenshot & Screen Recording:** Mencegah kebocoran soal dan penggunaan *Circle to Search* / Google Lens.
3. **Blokir Salin-Tempel (Anti-Copy / Anti-Paste / Anti-Selection):** Mematikan seleksi teks, klik kanan, dan mengosongkan clipboard secara otomatis.
4. **Blokir Paksa Keluar (Force-Exit / Unpin Bypass):** Mengunci navigasi, mendeteksi pelepasan sematan (*screen pinning*), dan menarik kembali aplikasi jika siswa mencoba ke Beranda (*Home*).
5. **Verifikasi PIN Pengawas:** Tombol keluar di navbar wajib meminta PIN Pengawas (Default: `8899`).
6. **Blokir Tautan Luar:** Membatasi navigasi WebView hanya pada domain / IP server ujian lokal (misal: `http://10.10.2.2`).
7. **Pemeriksaan Pra-Ujian:** Mendeteksi Opsi Pengembang (USB Debugging) dan aplikasi AI solver (ChatGPT, Gemini, Brainly, Photomath, dll.).
8. **Sirene Alarm Pelanggaran:** Memutar suara alarm sirene dengan gain tinggi (+20dB) yang dipaksa keluar lewat speaker fisik HP meskipun headset/Bluetooth terpasang.

---

## 2. ARSITEKTUR KEAMANAN & DETAIL IMPLEMENTASI

### A. Android Native Manifest (`android/app/src/main/AndroidManifest.xml`)
Tambahkan atribut proteksi pada `<application>` dan `<activity>`:
- `android:resizeableActivity="false"`: Mematikan kemampuan multi-window pada level OS.
- `android:supportsPictureInPicture="false"`: Mematikan mode Picture-in-Picture.
- `android:excludeFromRecents="true"`: Menghapus aplikasi dari daftar Recent Apps agar tidak bisa di-swipe atau dimultitask.
- `android:screenOrientation="portrait"`: Mengunci orientasi layar.
- Deklarasi `<queries>` untuk mendeteksi keberadaan aplikasi AI/solver pada Android 11+ (API 30+).

### B. Android Native Kotlin (`MainActivity.kt`)
1. **Window Security Flag:**
   Pasang `window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)` di `onCreate()`, `onResume()`, `onAttachedToWindow()`, dan `onWindowFocusChanged()`.
2. **Intersepsi Multi-Window & PiP:**
   Override `onMultiWindowModeChanged` dan `onPictureInPictureModeChanged`. Jika terdeteksi aktif, bunyikan alarm dan paksa aplikasi kembali ke layar penuh.
3. **Intersepsi Upaya Keluar (`onUserLeaveHint`):**
   Override `onUserLeaveHint()`. Jika siswa menekan tombol Home atau gesture swipe ke Beranda, segera jalankan Intent dengan flag `FLAG_ACTIVITY_REORDER_TO_FRONT` untuk menarik kembali aplikasi ke layar depan seketika.
4. **Pembersihan Clipboard Native:**
   Pasang `addPrimaryClipChangedListener` pada `ClipboardManager`. Jika ujian aktif, kosongkan clipboard seketika menggunakan `clearPrimaryClip()`.
5. **Pencegatan Keyboard Fisik:**
   Override `dispatchKeyEvent()`. Telan kombinasi tombol `Ctrl`, `Alt`, `Meta` (`Windows`), `KEYCODE_APP_SWITCH`, dan `KEYCODE_SEARCH`.
6. **Pemaksaan Speaker Fisik:**
   Gunakan `AudioAttributes.FLAG_AUDIBILITY_ENFORCED` dan `mediaPlayer.preferredDevice = AudioDeviceInfo.TYPE_BUILTIN_SPEAKER` agar alarm sirene tetap terdengar di kelas meski siswa mencolokkan earphone di saku celana.
7. **Deteksi Developer Options:**
   Periksa `Settings.Global.DEVELOPMENT_SETTINGS_ENABLED` dan `Settings.Global.ADB_ENABLED`.

### C. Komunikasi MethodChannel (`KioskModeService.dart`)
Sediakan `MethodChannel('com.examprimajember/kiosk')` dengan fungsi:
- `startKioskMode` / `stopKioskMode`
- `setSecureFlag(bool)`
- `isDevModeEnabled() -> Future<bool>`
- `ensureAudibleVolume()`, `playWarningSiren()`, `playExitVoice()`
- Callback listener dari Native: `onWindowFocusChanged`, `onMultiWindowDetected`, `onLockTaskDropped`, `onForceExitAttempt`.

### D. Halaman WebView Ujian (`lib/pages/exam_webview_page.dart`)
1. **Injeksi Anti-Copy / Anti-Select (CSS & JS):**
   Suntikkan CSS `* { -webkit-user-select: none !important; user-select: none !important; -webkit-touch-callout: none !important; }` (kecuali pada elemen `input` dan `textarea`).
   Pasang event listener JavaScript untuk `selectionchange` (memanggil `window.getSelection().removeAllRanges()`), serta memblokir `contextmenu`, `copy`, `cut`, dan `dragstart`. Jalankan ulang script setiap 1 detik untuk mengantisipasi konten dinamis (SPA/React/Google Forms).
2. **Pembersihan Clipboard Periodik:**
   Gunakan `Timer.periodic` setiap 600 milidetik untuk memanggil `Clipboard.setData(const ClipboardData(text: ''))`.
3. **Pembatasan URL (`onNavigationRequest`):**
   Batasi navigasi hanya ke host server ujian. Tautan eksternal otomatis diblokir dengan notifikasi SnackBar.
4. **Pemantauan Lifecycle & Penghitung Pelanggaran (*Violation Counter*):**
   Gunakan `WidgetsBindingObserver`. Jika status aplikasi menjadi `paused` atau `inactive`, atau kehilangan fokus jendela:
   - Tambah hitungan pelanggaran (`_violationCount++`).
   - Bunyikan sirene peringatan.
   - Tampilkan dialog peringatan. Jika mencapai 3 kali pelanggaran, kunci sesi ujian.
5. **Verifikasi PIN Pengawas:**
   Pada tombol "Exit" di bar kontrol bawah, wajib tampilkan dialog input PIN Pengawas (`8899`). Jika salah, berikan respon getar dan tolak aksi keluar.
6. **Perisai Layar Belah (*Multi-Window Shield*):**
   Jika native mendeteksi belah layar, tutup seluruh WebView dengan overlay layar merah tebal bertuliskan "BELAH LAYAR TERDETEKSI".

---

## 3. KODE LENGKAP ARTIFAK UTAMA

### 1. `android/app/src/main/AndroidManifest.xml`
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:label="Examprima"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:resizeableActivity="false"
        android:networkSecurityConfig="@xml/network_security_config">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:resizeableActivity="false"
            android:supportsPictureInPicture="false"
            android:excludeFromRecents="true"
            android:screenOrientation="portrait"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <receiver
            android:name=".KioskDeviceAdminReceiver"
            android:exported="true"
            android:label="ExamPrima Kiosk Admin"
            android:permission="android.permission.BIND_DEVICE_ADMIN">
            <meta-data
                android:name="android.app.device_admin"
                android:resource="@xml/device_admin_receiver" />
            <intent-filter>
                <action android:name="android.app.action.DEVICE_ADMIN_ENABLED" />
            </intent-filter>
        </receiver>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <queries>
        <package android:name="com.openai.chatgpt" />
        <package android:name="com.google.android.apps.bard" />
        <package android:name="com.microsoft.copilot" />
        <package android:name="com.deepseek.chat" />
        <package android:name="ai.perplexity.app.android" />
        <package android:name="com.anthropic.claude" />
        <package android:name="co.brainly" />
        <package android:name="com.photomath.android" />
        <package android:name="com.questionai.app" />
        <package android:name="com.mathpresso.qanda" />
        <package android:name="com.gauthmath" />
        <package android:name="com.bagatrix.mathway.android" />
        <package android:name="com.google.socratic" />
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.DELETE"/>
            <data android:scheme="package"/>
        </intent>
    </queries>
</manifest>
```

---

### 2. `android/app/src/main/kotlin/com/example/examprimajember/MainActivity.kt`
```kotlin
package com.example.examprimajember

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.audiofx.LoudnessEnhancer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.examprimajember/kiosk"
    private var methodChannel: MethodChannel? = null

    private var activeMediaPlayer: MediaPlayer? = null
    private var activeLoudnessEnhancer: LoudnessEnhancer? = null

    private var isKioskModeActive = false

    private val kioskHandler = Handler(Looper.getMainLooper())
    private val kioskCheckRunnable = object : Runnable {
        override fun run() {
            if (isKioskModeActive) {
                checkAndEnforceKiosk()
                kioskHandler.postDelayed(this, 1200)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        setupClipboardGuard()
    }

    override fun onResume() {
        super.onResume()
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        if (isKioskModeActive) {
            hideSystemUI()
            checkMultiWindow()
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUI()
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        } else if (isKioskModeActive) {
            try {
                @Suppress("DEPRECATION")
                val closeDialogs = Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
                sendBroadcast(closeDialogs)
            } catch (_: Exception) {}
        }
        methodChannel?.invokeMethod("onWindowFocusChanged", hasFocus)
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration?) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        if (isInMultiWindowMode) {
            onSplitScreenDetected()
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            onSplitScreenDetected()
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isKioskModeActive) {
            val bringToFront = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(bringToFront)
            playLoudAsset("assets/audio/warning_siren.mp3", null)
            methodChannel?.invokeMethod("onForceExitAttempt", null)
        }
    }

    private fun checkMultiWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            if (isInMultiWindowMode || isInPictureInPictureMode) {
                onSplitScreenDetected()
            }
        }
    }

    private fun onSplitScreenDetected() {
        playLoudAsset("assets/audio/warning_siren.mp3", null)
        methodChannel?.invokeMethod("onMultiWindowDetected", true)
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
    }

    private fun checkAndEnforceKiosk() {
        if (!isKioskModeActive) return

        checkMultiWindow()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                if (am.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) {
                    try {
                        startLockTask()
                    } catch (_: Exception) {}
                    playLoudAsset("assets/audio/warning_siren.mp3", null)
                    methodChannel?.invokeMethod("onLockTaskDropped", null)
                }
            } catch (_: Exception) {}
        }

        clearSystemClipboard()
    }

    private fun setupClipboardGuard() {
        try {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.addPrimaryClipChangedListener {
                if (isKioskModeActive) {
                    clearSystemClipboard()
                }
            }
        } catch (_: Exception) {}
    }

    private fun clearSystemClipboard() {
        try {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                clipboard.clearPrimaryClip()
            } else {
                clipboard.setPrimaryClip(android.content.ClipData.newPlainText("", ""))
            }
        } catch (_: Exception) {}
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.isCtrlPressed || event.isAltPressed || event.isMetaPressed) {
            return true
        }
        when (event.keyCode) {
            KeyEvent.KEYCODE_APP_SWITCH,
            KeyEvent.KEYCODE_SEARCH,
            KeyEvent.KEYCODE_WINDOW -> return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startKioskMode" -> {
                    startKioskMode()
                    result.success(null)
                }
                "stopKioskMode" -> {
                    stopKioskMode()
                    result.success(null)
                }
                "setSecureFlag" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "isDevModeEnabled" -> {
                    result.success(isDevModeEnabled())
                }
                "uninstallApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "packageName wajib diisi", null)
                    } else {
                        try {
                            val resolvedBy = uninstallApp(packageName)
                            result.success(resolvedBy)
                        } catch (e: Exception) {
                            result.error("UNINSTALL_FAILED", e.message ?: e.toString(), null)
                        }
                    }
                }
                "ensureAudibleVolume" -> {
                    ensureAudibleVolume()
                    result.success(null)
                }
                "playWarningSiren" -> {
                    playLoudAsset("assets/audio/warning_siren.mp3", null)
                    result.success(null)
                }
                "playExitVoice" -> {
                    playLoudAsset("assets/audio/exit_voice.mp3") {
                        result.success(null)
                    }
                }
                "isSystemApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "packageName wajib diisi", null)
                    } else {
                        result.success(isSystemApp(packageName))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        isKioskModeActive = false
        kioskHandler.removeCallbacksAndMessages(null)
        stopLoudPlayback()
        super.onDestroy()
    }

    private fun startKioskMode() {
        isKioskModeActive = true
        kioskHandler.removeCallbacks(kioskCheckRunnable)
        kioskHandler.postDelayed(kioskCheckRunnable, 1000)

        hideSystemUI()

        try {
            val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, KioskDeviceAdminReceiver::class.java)

            if (dpm.isDeviceOwnerApp(packageName)) {
                dpm.setLockTaskPackages(adminComponent, arrayOf(packageName))
            }
        } catch (_: Exception) {}

        try {
            startLockTask()
        } catch (_: Exception) {}
    }

    private fun stopKioskMode() {
        isKioskModeActive = false
        kioskHandler.removeCallbacks(kioskCheckRunnable)
        try {
            stopLockTask()
        } catch (_: Exception) {}
    }

    private fun uninstallApp(packageName: String): String {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.parse("package:$packageName")
        val resolvedComponent = intent.resolveActivity(packageManager)
            ?: throw IllegalStateException("Halaman info aplikasi tidak ditemukan.")
        startActivity(intent)
        return resolvedComponent.flattenToShortString()
    }

    private fun ensureAudibleVolume() {
        for (stream in intArrayOf(AudioManager.STREAM_ALARM, AudioManager.STREAM_MUSIC)) {
            try {
                val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                val currentVolume = audioManager.getStreamVolume(stream)
                if (currentVolume <= 0) {
                    val maxVolume = audioManager.getStreamMaxVolume(stream)
                    var attempts = 0
                    while (audioManager.getStreamVolume(stream) < maxVolume && attempts < maxVolume + 2) {
                        audioManager.adjustStreamVolume(stream, AudioManager.ADJUST_RAISE, 0)
                        attempts++
                    }
                }
            } catch (_: Exception) {}
        }
    }

    private fun playLoudAsset(assetPath: String, onComplete: (() -> Unit)?) {
        try {
            stopLoudPlayback()

            val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            val afd = assets.openFd(lookupKey)

            val mediaPlayer = MediaPlayer()
            val audioAttributesBuilder = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audioAttributesBuilder.setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
            }
            mediaPlayer.setAudioAttributes(audioAttributesBuilder.build())

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    for (device in devices) {
                        if (device.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                            mediaPlayer.preferredDevice = device
                            break
                        }
                    }
                } catch (_: Exception) {}
            }

            mediaPlayer.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            mediaPlayer.prepare()

            try {
                val enhancer = LoudnessEnhancer(mediaPlayer.audioSessionId)
                enhancer.setTargetGain(2000)
                enhancer.enabled = true
                activeLoudnessEnhancer = enhancer
            } catch (_: Exception) {}

            mediaPlayer.setOnCompletionListener {
                stopLoudPlayback()
                onComplete?.invoke()
            }
            mediaPlayer.setOnErrorListener { _, _, _ ->
                stopLoudPlayback()
                onComplete?.invoke()
                true
            }

            activeMediaPlayer = mediaPlayer
            mediaPlayer.start()
        } catch (_: Exception) {
            stopLoudPlayback()
            onComplete?.invoke()
        }
    }

    private fun stopLoudPlayback() {
        try {
            activeLoudnessEnhancer?.release()
        } catch (_: Exception) {}
        activeLoudnessEnhancer = null

        try {
            activeMediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        activeMediaPlayer = null
    }

    private fun isSystemApp(packageName: String): Boolean {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
        } catch (_: Exception) {
            false
        }
    }

    private fun isDevModeEnabled(): Boolean {
        return try {
            val devEnabled = Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) != 0
            val adbEnabled = Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) != 0
            devEnabled || adbEnabled
        } catch (_: Exception) {
            false
        }
    }
}
```

---

### 3. `lib/services/kiosk_mode_service.dart`
```dart
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
      }
    });
  }

  static final KioskModeService instance = KioskModeService._();

  static const MethodChannel _channel =
      MethodChannel('com.examprimajember/kiosk');

  void Function(bool hasFocus)? onWindowFocusChanged;
  void Function()? onMultiWindowDetected;
  void Function()? onLockTaskDropped;
  void Function()? onForceExitAttempt;

  Future<void> start() async {
    try {
      await _channel.invokeMethod('startKioskMode');
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopKioskMode');
    } catch (_) {}
  }

  Future<void> setSecureFlag(bool enabled) async {
    try {
      await _channel.invokeMethod('setSecureFlag', {'enabled': enabled});
    } catch (_) {}
  }

  Future<bool> isDevModeEnabled() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isDevModeEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureAudibleVolume() async {
    try {
      await _channel.invokeMethod('ensureAudibleVolume');
    } catch (_) {}
  }

  Future<void> playWarningSiren() async {
    try {
      await _channel.invokeMethod('playWarningSiren');
    } catch (_) {}
  }

  Future<void> playExitVoice() async {
    try {
      await _channel.invokeMethod('playExitVoice');
    } catch (_) {}
  }
}
```

---

### 4. `lib/pages/exam_webview_page.dart` (Penggalan Kunci Proteksi WebView)
```dart
// Lokasi: lib/pages/exam_webview_page.dart
class _ExamWebViewPageState extends State<ExamWebViewPage> with WidgetsBindingObserver {
  late final WebViewController _controller;
  int _violationCount = 0;
  static const int _maxViolations = 3;
  static const String _defaultProctorPin = '8899';
  bool _isExiting = false;
  bool _isMultiWindowBlocked = false;
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);

    KioskModeService.instance.onWindowFocusChanged = _onWindowFocusChanged;
    KioskModeService.instance.onMultiWindowDetected = _onMultiWindowDetected;
    KioskModeService.instance.onLockTaskDropped = _onLockTaskDropped;
    KioskModeService.instance.onForceExitAttempt = _onForceExitAttempt;

    KioskModeService.instance.setSecureFlag(true);
    KioskModeService.instance.start();

    // Pembersihan clipboard otomatis
    _clipboardTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted || _isExiting) return;
      Clipboard.setData(const ClipboardData(text: ''));
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) async => await _injectAntiCheatScripts(),
          onPageFinished: (_) async => await _injectAntiCheatScripts(),
          onNavigationRequest: (request) {
            final targetUri = Uri.tryParse(request.url);
            final examUri = Uri.tryParse(widget.url);
            if (targetUri != null && examUri != null && targetUri.host == examUri.host) {
              return NavigationDecision.navigate;
            }
            _showExternalLinkBlockedSnackBar(request.url);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _injectAntiCheatScripts() async {
    const String antiCheatJs = '''
      (function() {
        function applyAntiCheat() {
          var style = document.getElementById('examprima-anti-cheat-style');
          if (!style) {
            style = document.createElement('style');
            style.id = 'examprima-anti-cheat-style';
            style.type = 'text/css';
            style.innerHTML = `
              * {
                -webkit-user-select: none !important;
                -moz-user-select: none !important;
                user-select: none !important;
                -webkit-touch-callout: none !important;
              }
              input, textarea {
                -webkit-user-select: text !important;
                user-select: text !important;
              }
            `;
            (document.head || document.documentElement).appendChild(style);
          }
        }
        applyAntiCheat();

        document.addEventListener('selectionchange', function() {
          var sel = window.getSelection();
          if (sel && sel.toString().length > 0) {
            var el = document.activeElement;
            if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) {
              sel.removeAllRanges();
            }
          }
        }, true);

        ['contextmenu', 'copy', 'cut', 'dragstart'].forEach(function(evt) {
          document.addEventListener(evt, function(e) {
            var el = e.target;
            if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA')) return;
            e.preventDefault();
            e.stopPropagation();
            return false;
          }, true);
        });

        if (!window.__examPrimaInterval) {
          window.__examPrimaInterval = window.setInterval(applyAntiCheat, 1000);
        }
      })();
    ''';
    try {
      await _controller.runJavaScript(antiCheatJs);
    } catch (_) {}
  }

  Future<void> _handleExitTap() async {
    final pinController = TextEditingController();
    String? pinError;

    final bool? exitGranted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Verifikasi Pengawas'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Masukkan PIN Pengawas Ruangan untuk keluar:'),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'PIN Pengawas',
                      hintText: 'Default: 8899',
                      errorText: pinError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (pinController.text.trim() == _defaultProctorPin) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      HapticFeedback.heavyImpact();
                      setDialogState(() => pinError = 'PIN Pengawas salah!');
                    }
                  },
                  child: const Text('Konfirmasi Keluar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (exitGranted == true) {
      await _confirmedExit();
    }
  }
}
```

---

## 4. PANDUAN BUILD & MENGATASI GRADLE ERROR

### Mengatasi Masalah Gradle Versi Flutter 3.50+
Jika saat build muncul pesan:
`Your project's Gradle version is lower than Flutter's minimum supported version`

**Solusi:**
1. Pastikan `android/gradle/wrapper/gradle-wrapper.properties` menggunakan:
   ```properties
   distributionUrl=https\://services.gradle.org/distributions/gradle-9.3.1-all.zip
   ```
2. Jalankan perintah build dengan menyertakan flag resmi bypass validasi:
   ```powershell
   flutter clean
   flutter pub get
   flutter run --release --android-skip-build-dependency-validation
   ```
   Atau untuk menghasilkan file APK instalasi:
   ```powershell
   flutter build apk --release --android-skip-build-dependency-validation
   ```

File APK siap pakai akan berada di:
`build/app/outputs/flutter-apk/app-release.apk`
