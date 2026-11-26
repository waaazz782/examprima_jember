package com.example.examprimajember

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Rect
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

/**
 * MainActivity ExamPrima.
 *
 * Menyediakan MethodChannel "com.examprimajember/kiosk" yang dipanggil
 * dari sisi Flutter untuk beberapa keperluan:
 *
 * 1. Mengaktifkan/menonaktifkan Exam Mode menggunakan mekanisme
 *    Android Lock Task (screen pinning / kiosk mode) - lihat
 *    lib/services/kiosk_mode_service.dart.
 * 2. Membuka halaman "Info Aplikasi" (App Info) sistem Android untuk
 *    aplikasi AI yang dilarang, tempat tombol "Uninstall" berada -
 *    lihat lib/services/app_uninstaller_service.dart.
 * 3. Menaikkan volume stream Alarm/Media jika sedang 0.
 * 4. Memutar suara peringatan (sirene) & suara konfirmasi keluar
 *    LANGSUNG DARI NATIVE (bukan lewat package audioplayers Flutter
 *    lagi) memakai MediaPlayer + LoudnessEnhancer - lihat RIWAYAT
 *    PERUBAHAN SOAL AUDIO di bawah.
 *
 * RIWAYAT PERUBAHAN PENTING (dibaca sebelum mengubah method
 * uninstallApp lagi):
 * - Versi awal memakai Intent.ACTION_DELETE untuk memicu dialog
 *   konfirmasi uninstall PackageInstaller secara langsung. Itu
 *   SECARA TEKNIS berhasil di-resolve ke
 *   com.google.android.packageinstaller/.UninstallerActivity dan
 *   startActivity() tidak pernah melempar exception - TAPI activity-
 *   nya tidak pernah benar-benar tampil di layar pada perangkat
 *   Vivo/Funtouch OS 14, karena lapisan keamanan OEM Vivo diam-diam
 *   membatalkan peluncuran activity tersebut ketika dipicu oleh
 *   aplikasi pihak ketiga (tanpa memberi tahu aplikasi pemanggil
 *   lewat exception apa pun - sudah diverifikasi lewat testing
 *   langsung di perangkat Vivo Y22).
 * - Versi SEKARANG memakai
 *   Settings.ACTION_APPLICATION_DETAILS_SETTINGS untuk membuka
 *   halaman Info Aplikasi milik package tersebut (bukan Settings
 *   umum - tetap spesifik ke satu aplikasi, dan halaman itu punya
 *   tombol "Uninstall" yang jelas). Pendekatan ini jauh lebih jarang
 *   diblokir OEM manapun karena hanya membuka activity Settings
 *   bawaan sistem, bukan langsung memicu proses uninstall privileged.
 *
 * uninstallApp() juga TIDAK menelan (swallow) exception secara
 * diam-diam - kalau gagal, dilaporkan balik ke Flutter lewat
 * result.error() supaya kegagalannya benar-benar terlihat (lihat
 * SnackBar merah di security_check_modal.dart).
 *
 * RIWAYAT PERUBAHAN SOAL AUDIO (sirene & suara exit):
 * - Versi awal memutar suara lewat package audioplayers Flutter
 *   (Dart), dengan AudioContextAndroid usageType.alarm dan
 *   ensureAudibleVolume() menaikkan volume stream Alarm/Media ke
 *   maksimum. Ini terbukti berhasil (volume naik otomatis & suara
 *   kencang) di Vivo, Samsung, Realme, dan POCO.
 * - TAPI di Oppo (ColorOS) dan Redmi (MIUI) tertentu, suaranya tetap
 *   pelan MESKIPUN volume stream sudah dipastikan maksimum - diduga
 *   kuat karena ROM tersebut menerapkan pembatasan volume PER-APLIKASI
 *   yang terpisah dari volume stream sistem biasa, dan tidak
 *   terpengaruh oleh perintah adjustStreamVolume/setStreamVolume biasa
 *   dari aplikasi pihak ketiga.
 * - Solusinya sekarang: audio TIDAK LAGI diputar lewat package
 *   audioplayers Flutter sama sekali untuk 2 suara ini. Sebagai
 *   gantinya, diputar langsung dari native Android memakai MediaPlayer
 *   biasa + efek LoudnessEnhancer (android.media.audiofx) yang
 *   ditempelkan langsung ke audio session pemutaran ini - efek ini
 *   menambahkan gain signifikan (target +20dB) via kompresi dinamis
 *   PADA LEVEL SESI AUDIO ITU SENDIRI, bukan sekadar mengatur angka
 *   volume stream, sehingga berpotensi menembus pembatasan
 *   volume-per-aplikasi milik ROM tertentu karena mekanismenya
 *   fundamental berbeda.
 *
 * CATATAN PENTING SOAL TINGKAT PROTEKSI KIOSK MODE:
 * - Jika aplikasi ini SUDAH didaftarkan sebagai Device Owner di
 *   perangkat (lihat instruksi adb di bawah), startLockTask() akan
 *   masuk ke Lock Task Mode PENUH: Home, Recent Apps, dan notification
 *   shade benar-benar terkunci sampai stopKioskMode() dipanggil.
 * - Jika perangkat BELUM di-provision sebagai Device Owner, Android
 *   tetap mengizinkan startLockTask() berjalan sebagai "Screen
 *   Pinning" biasa.
 *
 * CARA MENDAFTARKAN APLIKASI SEBAGAI DEVICE OWNER (dilakukan sekali
 * oleh admin sekolah lewat komputer + kabel USB, SEBELUM perangkat
 * dipakai siswa, dan HANYA bisa dilakukan saat perangkat belum punya
 * akun Google terdaftar / baru selesai factory reset):
 *
 *   adb shell dpm set-device-owner com.example.examprimajember/.KioskDeviceAdminReceiver
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.examprimajember/kiosk"
    private var methodChannel: MethodChannel? = null

    private var activeMediaPlayer: MediaPlayer? = null
    private var activeLoudnessEnhancer: LoudnessEnhancer? = null

    // Status Exam / Kiosk Mode
    private var isKioskModeActive = false
    private var wasPinned = false
    private var kioskStartTime: Long = 0L
    private var lastLockTaskDropTime: Long = 0L
    private var lastForceExitTime: Long = 0L

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

        @Suppress("DEPRECATION")
        window.decorView.setOnSystemUiVisibilityChangeListener { visibility ->
            if (isKioskModeActive && (visibility and View.SYSTEM_UI_FLAG_FULLSCREEN) == 0) {
                hideSystemUI()
            }
        }
    }

    override fun popSystemNavigator(): Boolean {
        if (isKioskModeActive) {
            playLoudAsset("assets/audio/warning_siren.mp3", null)
            methodChannel?.invokeMethod("onBackBlocked", null)
            return false // Mencegah Flutter menutup aplikasi saat gestur kembali dipicu
        }
        return super.popSystemNavigator()
    }

    override fun commitBackGesture() {
        if (isKioskModeActive) {
            playLoudAsset("assets/audio/warning_siren.mp3", null)
            methodChannel?.invokeMethod("onBackBlocked", null)
            return // Mencegah penyelesaian gestur kembali sistem Android
        }
        super.commitBackGesture()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        if (isKioskModeActive) {
            playLoudAsset("assets/audio/warning_siren.mp3", null)
            methodChannel?.invokeMethod("onBackBlocked", null)
            return
        }
        super.onBackPressed()
    }

    override fun onResume() {
        super.onResume()
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        if (isKioskModeActive) {
            hideSystemUI()
            checkMultiWindow()
        }
    }

    override fun onPause() {
        super.onPause()
        if (isKioskModeActive) {
            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                am.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_NO_USER_ACTION)
            } catch (_: Exception) {}
        }
    }

    override fun onStop() {
        super.onStop()
        if (isKioskModeActive) {
            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                am.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_NO_USER_ACTION)
            } catch (_: Exception) {}
            val bringToFront = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            try {
                startActivity(bringToFront)
            } catch (_: Exception) {}
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
            // Tutup dialog sistem jika status bar ditarik
            try {
                @Suppress("DEPRECATION")
                val closeDialogs = Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
                sendBroadcast(closeDialogs)
            } catch (_: Exception) {}

            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                am.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_NO_USER_ACTION)
            } catch (_: Exception) {}
        }
        // Kirim event fokus ke Flutter hanya jika sudah melewati masa toleransi awal (6 detik)
        if (System.currentTimeMillis() - kioskStartTime > 6000L) {
            methodChannel?.invokeMethod("onWindowFocusChanged", hasFocus)
        }
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
            // Segera paksa task kembali ke paling depan
            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                am.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_NO_USER_ACTION)
            } catch (_: Exception) {}
            val bringToFront = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            try {
                startActivity(bringToFront)
            } catch (_: Exception) {}

            val now = System.currentTimeMillis()
            if (now - lastForceExitTime > 2500L) {
                lastForceExitTime = now
                playLoudAsset("assets/audio/warning_siren.mp3", null)
                methodChannel?.invokeMethod("onForceExitAttempt", null)
            }
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

        // Periksa apakah Lock Task Mode / Screen Pinning terlepas
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val currentMode = am.lockTaskModeState
                if (currentMode != ActivityManager.LOCK_TASK_MODE_NONE) {
                    wasPinned = true
                } else if (wasPinned && System.currentTimeMillis() - kioskStartTime > 6000L) {
                    // Sematan terlepas SETELAH sebelumnya terkonfirmasi tersemat!
                    // Segera sematkan kembali secara paksa:
                    try {
                        startLockTask()
                    } catch (_: Exception) {}

                    val now = System.currentTimeMillis()
                    if (now - lastLockTaskDropTime > 4000L) {
                        lastLockTaskDropTime = now
                        playLoudAsset("assets/audio/warning_siren.mp3", null)
                        methodChannel?.invokeMethod("onLockTaskDropped", null)
                    }
                }
            } catch (_: Exception) {}
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isKioskModeActive) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_BACK,
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_APP_SWITCH,
                KeyEvent.KEYCODE_SEARCH,
                KeyEvent.KEYCODE_WINDOW -> {
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        playLoudAsset("assets/audio/warning_siren.mp3", null)
                        methodChannel?.invokeMethod("onBackBlocked", null)
                    }
                    return true
                }
            }
            if (event.isCtrlPressed || event.isAltPressed || event.isMetaPressed) {
                return true
            }
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
        updateGestureExclusion()
    }

    private fun updateGestureExclusion() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && isKioskModeActive) {
            window.decorView.post {
                try {
                    val displayMetrics = resources.displayMetrics
                    val width = displayMetrics.widthPixels
                    val height = displayMetrics.heightPixels
                    val density = displayMetrics.density
                    val maxExclusionHeight = (200 * density).toInt().coerceAtMost(height)
                    val edgeWidth = (45 * density).toInt().coerceAtMost(width / 4)

                    val rects = mutableListOf<Rect>()
                    // Area bawah (gestur navigasi home & recents)
                    rects.add(Rect(0, height - (80 * density).toInt(), width, height))
                    // Sisi kiri (gestur back tepi layar)
                    rects.add(Rect(0, height / 2 - maxExclusionHeight / 2, edgeWidth, height / 2 + maxExclusionHeight / 2))
                    // Sisi kanan (gestur back tepi layar)
                    rects.add(Rect(width - edgeWidth, height / 2 - maxExclusionHeight / 2, width, height / 2 + maxExclusionHeight / 2))

                    window.decorView.systemGestureExclusionRects = rects
                } catch (_: Exception) {}
            }
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
                    "uninstallApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error(
                                "INVALID_ARGUMENT",
                                "packageName wajib diisi",
                                null,
                            )
                        } else {
                            try {
                                val resolvedBy = uninstallApp(packageName)
                                // Dikembalikan ke Flutter untuk diagnosis:
                                // menunjukkan activity/aplikasi sistem apa
                                // yang sebenarnya menangani intent ini.
                                result.success(resolvedBy)
                            } catch (e: Exception) {
                                result.error(
                                    "UNINSTALL_FAILED",
                                    e.message ?: e.toString(),
                                    null,
                                )
                            }
                        }
                    }
                    "ensureAudibleVolume" -> {
                        ensureAudibleVolume()
                        result.success(null)
                    }
                    "playWarningSiren" -> {
                        // Fire-and-forget - Flutter tidak perlu menunggu
                        // sirene selesai diputar.
                        playLoudAsset("assets/audio/warning_siren.mp3", null)
                        result.success(null)
                    }
                    "playExitVoice" -> {
                        // result.success() SENGAJA baru dipanggil
                        // setelah pemutaran selesai (lewat callback di
                        // bawah) - supaya sisi Flutter yang meng-`await`
                        // pemanggilan ini benar-benar menunggu suara
                        // "Anda keluar dari ExamPrima" selesai diputar
                        // sebelum melanjutkan proses nonaktifkan Exam
                        // Mode & menutup halaman.
                        playLoudAsset("assets/audio/exit_voice.mp3") {
                            result.success(null)
                        }
                    }
                    "isSystemApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error(
                                "INVALID_ARGUMENT",
                                "packageName wajib diisi",
                                null,
                            )
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
        wasPinned = false
        lastLockTaskDropTime = 0L
        lastForceExitTime = 0L
        kioskStartTime = System.currentTimeMillis()
        kioskHandler.removeCallbacks(kioskCheckRunnable)
        kioskHandler.postDelayed(kioskCheckRunnable, 3000)

        hideSystemUI()

        try {
            val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, KioskDeviceAdminReceiver::class.java)

            if (dpm.isDeviceOwnerApp(packageName)) {
                dpm.setLockTaskPackages(adminComponent, arrayOf(packageName))
            }
        } catch (e: Exception) {
            // Abaikan - lanjutkan ke startLockTask() biasa (screen
            // pinning) sebagai fallback jika perangkat belum di-setup
            // sebagai Device Owner.
        }

        try {
            startLockTask()
        } catch (e: Exception) {
            // Diamkan - lihat penjelasan di komentar class di atas.
        }
    }

    private fun stopKioskMode() {
        isKioskModeActive = false
        wasPinned = false
        kioskHandler.removeCallbacks(kioskCheckRunnable)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                window.decorView.systemGestureExclusionRects = emptyList()
            } catch (_: Exception) {}
        }
        try {
            stopLockTask()
        } catch (e: Exception) {
            // Diamkan - mis. jika memang belum pernah masuk lock task
            // mode saat ini.
        }
    }

    /**
     * Membuka halaman "Info Aplikasi" (App Info) bawaan sistem Android
     * untuk [packageName] tertentu - BUKAN Settings umum, melainkan
     * halaman spesifik aplikasi tersebut yang menampilkan tombol
     * "Uninstall" besar dan jelas. Mengembalikan nama komponen
     * (activity) sistem yang menangani intent ini - murni untuk
     * diagnosis di sisi Flutter.
     *
     * Lihat komentar RIWAYAT PERUBAHAN di atas class untuk alasan
     * kenapa pendekatan ini dipakai, bukan Intent.ACTION_DELETE.
     *
     * SENGAJA TIDAK ADA try-catch di sini - biar exception naik ke
     * pemanggil di configureFlutterEngine() dan dilaporkan balik ke
     * Flutter, bukan didiamkan.
     */
    private fun uninstallApp(packageName: String): String {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.parse("package:$packageName")

        val resolvedComponent = intent.resolveActivity(packageManager)
            ?: throw IllegalStateException(
                "Tidak ada halaman info aplikasi yang ditemukan di " +
                    "perangkat ini untuk package $packageName."
            )

        startActivity(intent)

        return resolvedComponent.flattenToShortString()
    }

    /**
     * Menaikkan volume KE MAKSIMUM (100%) pada stream ALARM dan MUSIC,
     * TAPI HANYA untuk stream yang saat ini benar-benar 0 (disenyapkan
     * pengguna) - masing-masing dicek terpisah.
     *
     * Dipakai audioManager.adjustStreamVolume(stream, ADJUST_RAISE, 0)
     * berulang kali (meniru penekanan tombol volume fisik) alih-alih
     * setStreamVolume langsung, karena beberapa ROM OEM diam-diam
     * mengabaikan perintah set volume absolut.
     *
     * Tidak memerlukan izin tambahan apa pun.
     */
    private fun ensureAudibleVolume() {
        for (stream in intArrayOf(AudioManager.STREAM_ALARM, AudioManager.STREAM_MUSIC)) {
            try {
                val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                val currentVolume = audioManager.getStreamVolume(stream)

                if (currentVolume <= 0) {
                    val maxVolume = audioManager.getStreamMaxVolume(stream)
                    var attempts = 0
                    while (
                        audioManager.getStreamVolume(stream) < maxVolume &&
                        attempts < maxVolume + 2
                    ) {
                        audioManager.adjustStreamVolume(
                            stream,
                            AudioManager.ADJUST_RAISE,
                            0,
                        )
                        attempts++
                    }
                }
            } catch (e: Exception) {
                // Diamkan untuk stream ini, lanjutkan ke stream
                // berikutnya.
            }
        }
    }

    /**
     * Memutar file asset Flutter [assetPath] (mis.
     * "assets/audio/warning_siren.mp3") LANGSUNG lewat MediaPlayer
     * native, dengan efek [LoudnessEnhancer] ditempelkan ke audio
     * session pemutaran ini untuk menambah gain signifikan (+20dB)
     * di luar volume stream biasa.
     *
     * [onComplete] dipanggil setelah pemutaran selesai (atau segera
     * kalau terjadi kegagalan) - dipakai oleh handler "playExitVoice"
     * di atas untuk menahan result.success() sampai suara benar-benar
     * selesai diputar. Untuk "playWarningSiren", [onComplete] dikirim
     * null karena sisi Flutter tidak perlu menunggu sirene selesai.
     */
    private fun playLoudAsset(assetPath: String, onComplete: (() -> Unit)?) {
        try {
            stopLoudPlayback()

            val lookupKey = FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset(assetPath)
            val afd = assets.openFd(lookupKey)

            val mediaPlayer = MediaPlayer()
            val audioAttributesBuilder = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)

            // Memaksa suara alarm tetap terdengar kencang & diprioritaskan
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audioAttributesBuilder.setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
            }
            mediaPlayer.setAudioAttributes(audioAttributesBuilder.build())

            // Arahkan ke built-in speaker jika headset/bluetooth terhubung (Android 6+)
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
                } catch (e: Exception) {
                    // Abaikan jika device tidak mengizinkan override preferred device
                }
            }

            mediaPlayer.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            mediaPlayer.prepare()

            // Tempelkan LoudnessEnhancer ke audio session pemutaran
            // ini. +2000 milliBel = +20dB gain tambahan di atas
            // volume normal, lewat kompresi dinamis - bukan sekadar
            // perkalian linear seperti volume biasa, sehingga jauh
            // lebih terasa "kencang" meski dibatasi ROM tertentu.
            try {
                val enhancer = LoudnessEnhancer(mediaPlayer.audioSessionId)
                enhancer.setTargetGain(2000)
                enhancer.enabled = true
                activeLoudnessEnhancer = enhancer
            } catch (e: Exception) {
                // Kalau perangkat tidak mendukung LoudnessEnhancer,
                // lanjutkan tanpa efek tambahan - tetap lebih baik
                // daripada tidak bunyi sama sekali.
            }

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
        } catch (e: Exception) {
            stopLoudPlayback()
            onComplete?.invoke()
        }
    }

    private fun stopLoudPlayback() {
        try {
            activeLoudnessEnhancer?.release()
        } catch (e: Exception) {
            // Diamkan.
        }
        activeLoudnessEnhancer = null

        try {
            activeMediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (e: Exception) {
            // Diamkan.
        }
        activeMediaPlayer = null
    }

    /**
     * Mengecek apakah [packageName] terpasang sebagai aplikasi
     * sistem/bawaan pabrik (ApplicationInfo.FLAG_SYSTEM), yang secara
     * normal TIDAK BISA dihapus pengguna lewat uninstall biasa (hanya
     * bisa dinonaktifkan, atau perlu akses root untuk dihapus paksa).
     *
     * Dipakai supaya aplikasi AI yang memang sudah bawaan pabrik HP
     * (mis. asisten AI bawaan di sebagian merek HP) TIDAK memblokir
     * siswa mengikuti ujian - karena menghapusnya bukan sesuatu yang
     * bisa dilakukan siswa lewat cara normal, dan mewajibkannya hanya
     * akan membuat siswa tersebut tidak pernah bisa lolos pemeriksaan.
     *
     * Mengembalikan false (dianggap BUKAN aplikasi sistem) kalau
     * package tidak ditemukan atau terjadi error apa pun - fail-safe
     * ke arah lebih ketat, supaya tidak ada celah di mana aplikasi AI
     * yang sebenarnya BISA dihapus malah keliru dianggap "bawaan" dan
     * lolos dari pemeriksaan keamanan.
     */
    private fun isSystemApp(packageName: String): Boolean {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
        } catch (e: Exception) {
            false
        }
    }
}