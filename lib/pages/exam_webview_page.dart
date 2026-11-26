import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../constants/app_colors.dart';
import '../services/kiosk_mode_service.dart';

class ExamWebViewPage extends StatefulWidget {
  const ExamWebViewPage({super.key, required this.url});
  final String url;

  @override
  State<ExamWebViewPage> createState() => _ExamWebViewPageState();
}

class _ExamWebViewPageState extends State<ExamWebViewPage>
    with WidgetsBindingObserver {
  late final WebViewController _controller;

  bool _isLoading = true;
  double _progress = 0;
  String? _errorMessage;

  bool _canGoBack = false;
  bool _canGoForward = false;

  bool _isExiting = false;

  int _violationCount = 0;
  int _maxViolations = 3;
  bool _isViolationDialogShowing = false;
  bool _isLockDialogShowing = false;
  bool _isMultiWindowBlocked = false;

  // PIN Pengawas asli (5 digit) - dengan pengecohan input 8 digit di UI
  static const String _secretProctorPin = '55422';

  bool _isProctorPinValid(String input) {
    return input.trim() == _secretProctorPin;
  }

  Timer? _focusLostDebounceTimer;
  DateTime? _examStartTime;
  DateTime? _lastViolationTime;

  @override
  void initState() {
    super.initState();
    _examStartTime = DateTime.now();

    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);

    // Daftarkan listener fokus jendela & event kiosk native
    KioskModeService.instance.onWindowFocusChanged = _onWindowFocusChanged;
    KioskModeService.instance.onMultiWindowDetected = _onMultiWindowDetected;
    KioskModeService.instance.onLockTaskDropped = _onLockTaskDropped;
    KioskModeService.instance.onForceExitAttempt = _onForceExitAttempt;
    KioskModeService.instance.onBackBlocked = _handleBackBlocked;

    // Pastikan flag FLAG_SECURE aktif untuk memblokir screenshot dan screen recording
    KioskModeService.instance.setSecureFlag(true);

    KioskModeService.instance.start();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress / 100);
          },
          onPageStarted: (_) async {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
            await _injectAntiCheatScripts();
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _isLoading = false);
            await _refreshNavState();
            await _injectAntiCheatScripts();
          },
          onNavigationRequest: (NavigationRequest request) {
            final targetUri = Uri.tryParse(request.url);
            final examUri = Uri.tryParse(widget.url);

            if (targetUri != null && examUri != null) {
              if (targetUri.host == examUri.host ||
                  request.url.startsWith('about:blank') ||
                  request.url.startsWith('data:')) {
                return NavigationDecision.navigate;
              }
            }

            _showExternalLinkBlockedSnackBar(request.url);
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _errorMessage =
                  'Gagal memuat halaman ujian.\n(${error.description})';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _focusLostDebounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    KioskModeService.instance.onWindowFocusChanged = null;
    KioskModeService.instance.onMultiWindowDetected = null;
    KioskModeService.instance.onLockTaskDropped = null;
    KioskModeService.instance.onForceExitAttempt = null;
    KioskModeService.instance.onBackBlocked = null;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onMultiWindowDetected() {
    if (_isExiting || !mounted) return;
    if (_examStartTime != null && DateTime.now().difference(_examStartTime!).inSeconds < 5) return;
    setState(() => _isMultiWindowBlocked = true);
    _handleViolation('Mode Belah Layar (Split Screen) atau Jendela Mengambang terdeteksi! Dilarang membagi layar selama ujian.');
  }

  void _onLockTaskDropped() {
    if (_isExiting || !mounted) return;
    if (_examStartTime != null && DateTime.now().difference(_examStartTime!).inSeconds < 5) return;
    _handleViolation('Sematan layar (Kiosk Pinning) terlepas! Tetap berada di aplikasi ExamPrima.');
  }

  void _onForceExitAttempt() {
    if (_isExiting || !mounted) return;
    if (_examStartTime != null && DateTime.now().difference(_examStartTime!).inSeconds < 5) return;
    _handleViolation('Terdeteksi upaya keluar / berpindah dari aplikasi ujian!');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }
    // Hanya picu pelanggaran jika aplikasi benar-benar masuk ke latar belakang (paused)
    // Hindari AppLifecycleState.inactive karena memicu false-positive saat dialog sistem muncul
    if (state == AppLifecycleState.paused && !_isExiting) {
      if (_examStartTime != null && DateTime.now().difference(_examStartTime!).inSeconds < 5) return;
      _handleViolation('Aplikasi ditinggalkan atau berjalan di latar belakang!');
    }
  }

  void _onWindowFocusChanged(bool hasFocus) {
    _focusLostDebounceTimer?.cancel();
    if (hasFocus) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else if (!_isExiting && !_isLockDialogShowing && !_isViolationDialogShowing) {
      if (_examStartTime != null && DateTime.now().difference(_examStartTime!).inSeconds < 5) return;
      // Berikan debounce 1.5 detik agar dialog sistem wajar tidak langsung menghukum
      _focusLostDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted || _isExiting || _isLockDialogShowing) return;
        _handleViolation('Bilah notifikasi atau jendela mengambang terdeteksi dibuka!');
      });
    }
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final bool isCtrl = HardwareKeyboard.instance.isControlPressed;
      final bool isAlt = HardwareKeyboard.instance.isAltPressed;
      final bool isMeta = HardwareKeyboard.instance.isMetaPressed;

      if (isCtrl || isAlt || isMeta) {
        _handleBackBlocked();
        return true;
      }

      if (event.logicalKey == LogicalKeyboardKey.f5 ||
          event.logicalKey == LogicalKeyboardKey.f12 ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        return true;
      }
    }
    return false;
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
                -ms-user-select: none !important;
                user-select: none !important;
                -webkit-touch-callout: none !important;
              }
              input, textarea, [contenteditable="true"] {
                -webkit-user-select: text !important;
                user-select: text !important;
              }
            `;
            if (document.head) {
              document.head.appendChild(style);
            } else if (document.documentElement) {
              document.documentElement.appendChild(style);
            }
          }
        }

        applyAntiCheat();

        // 1. Bersihkan seleksi seketika jika pengguna mencoba menyorot teks
        document.addEventListener('selectionchange', function() {
          var sel = window.getSelection();
          if (sel && sel.toString().length > 0) {
            var el = document.activeElement;
            if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) {
              sel.removeAllRanges();
            }
          }
        }, true);

        // 2. Blokir Menu Konteks (Klik Kanan / Long Press Context Menu)
        document.addEventListener('contextmenu', function(e) {
          var el = e.target;
          if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          }
        }, true);

        // 3. Blokir Copy, Cut, Paste, Drag secara total
        ['copy', 'cut', 'paste', 'dragstart'].forEach(function(evt) {
          document.addEventListener(evt, function(e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          }, true);
        });

        // 4. Blokir SelectStart di luar kolom input
        document.addEventListener('selectstart', function(e) {
          var el = e.target;
          if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          }
        }, true);

        // Terapkan ulang setiap 1 detik jika halaman menggunakan single-page app / dynamic DOM
        if (!window.__examPrimaInterval) {
          window.__examPrimaInterval = window.setInterval(applyAntiCheat, 1000);
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(antiCheatJs);
    } catch (_) {}
  }

  void _showExternalLinkBlockedSnackBar(String url) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            const Icon(Icons.link_off_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Akses ke tautan luar diblokir demi keamanan ujian:\n$url',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleViolation(String reason) async {
    if (_isExiting || !mounted) return;

    // Jika dialog penguncian ujian sedang aktif, cegah penumpukan dialog
    if (_isLockDialogShowing) return;

    // Masa tenggang di awal ujian (5 detik)
    if (_examStartTime != null &&
        DateTime.now().difference(_examStartTime!).inSeconds < 5) {
      return;
    }

    // Rate-limiting / debounce antar pelanggaran (minimal jeda 3.5 detik)
    final now = DateTime.now();
    if (_lastViolationTime != null &&
        now.difference(_lastViolationTime!).inMilliseconds < 3500) {
      return;
    }
    _lastViolationTime = now;

    _violationCount++;
    HapticFeedback.heavyImpact();

    try {
      await KioskModeService.instance.ensureAudibleVolume();
      await KioskModeService.instance.playWarningSiren();
    } catch (_) {}

    if (!mounted) return;

    // JIKA PELANGGARAN MENCAPAI BATAS MAKSIMUM -> KUNCI SESI UJIAN (WAJIB TOKEN/PIN PENGAWAS)
    if (_violationCount >= _maxViolations) {
      _isLockDialogShowing = true;
      final pinController = TextEditingController();
      String? pinError;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (statefulCtx, setDialogState) {
            return PopScope(
              canPop: false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.red, size: 44),
                ),
                title: const Text(
                  'UJIAN DIKUNCI',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Anda telah melakukan pelanggaran sebanyak $_violationCount kali.\n'
                        'Penyebab terakhir: $reason\n\n'
                        'Sesi ujian telah dibekukan. Panggil Pengawas Ruangan untuk memasukkan kode otorisasi pembukaan kunci:',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 8,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Kode Otorisasi Pengawas',
                          hintText: '••••••••',
                          helperText: 'Masukkan 8 digit token pengawas',
                          helperStyle: const TextStyle(fontSize: 11),
                          errorText: pinError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.vpn_key_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text(
                          'Buka Kunci & Lanjut Ujian',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          if (_isProctorPinValid(pinController.text)) {
                            Navigator.of(dialogCtx).pop();
                            setState(() {
                              _violationCount = 0;
                              _maxViolations = 2; // Turun menjadi 2 kali agar lebih jera!
                              _isMultiWindowBlocked = false;
                            });

                            // Kunci ulang perangkat secara paksa
                            await KioskModeService.instance.start();
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sesi ujian dibuka kembali. PERINGATAN: Batas toleransi berikutnya diturunkan menjadi maksimal 2 kali!',
                                ),
                                backgroundColor: Color(0xFF1B7A3D),
                                duration: Duration(seconds: 4),
                              ),
                            );
                          } else {
                            HapticFeedback.heavyImpact();
                            setDialogState(() {
                              pinError = 'Kode token pengawas tidak valid!';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.exit_to_app_rounded),
                        label: const Text('Keluarkan Siswa'),
                        onPressed: () {
                          if (_isProctorPinValid(pinController.text)) {
                            Navigator.of(dialogCtx).pop();
                            _confirmedExit();
                          } else {
                            HapticFeedback.heavyImpact();
                            setDialogState(() {
                              pinError = 'Kode token pengawas salah! Tidak dapat keluar.';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      _isLockDialogShowing = false;
      return;
    }

    if (_isViolationDialogShowing) return;
    _isViolationDialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 44),
          title: Text(
            'PERINGATAN PELANGGARAN ($_violationCount/$_maxViolations)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: Text(
            '$reason\n\n'
            'Dilarang berpindah aplikasi, membuka bilah notifikasi, membagi layar, atau berusaha keluar dari ujian!\n\n'
            'Sisa kesempatan: ${_maxViolations - _violationCount} kali lagi.\n'
            'PERINGATAN: Jika melanggar hingga $_maxViolations kali, sesi ujian akan langsung dikunci dan memerlukan otorisasi Pengawas!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              },
              child: const Text('Saya Mengerti & Lanjut Ujian'),
            ),
          ],
        ),
      ),
    );

    _isViolationDialogShowing = false;
  }

  Future<void> _refreshNavState() async {
    final bool canGoBack = await _controller.canGoBack();
    final bool canGoForward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _controller.reload();
    } catch (_) {
      await _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  Future<void> _handleBack() async {
    if (!_canGoBack) return;
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kembali ke Halaman Sebelumnya?'),
        content: const Text(
          'Pastikan jawaban pada halaman ini telah tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Ya, Kembali'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await _controller.goBack();
      await _refreshNavState();
    }
  }

  Future<void> _handleForward() async {
    if (!_canGoForward) return;
    await _controller.goForward();
    await _refreshNavState();
  }

  Future<void> _handleBackBlocked() async {
    HapticFeedback.mediumImpact();

    try {
      await KioskModeService.instance.ensureAudibleVolume();
      await KioskModeService.instance.playWarningSiren();
    } catch (_) {
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AKSES KELUAR DIBLOKIR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tombol & gestur kembali dinonaktifkan. Anda hanya bisa keluar melalui tombol "Exit" di menu bilah bawah setelah selesai ujian.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmedExit() async {
    if (_isExiting) return;
    _isExiting = true;

    try {
      await KioskModeService.instance.ensureAudibleVolume();
      await KioskModeService.instance.playExitVoice();
    } catch (_) {
    }

    await KioskModeService.instance.stop();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleExitTap() async {
    final bool? exitGranted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 36),
            ),
            title: const Text(
              'Konfirmasi Selesai Ujian',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Apakah Anda yakin ingin mengakhiri sesi ujian dan keluar dari aplikasi?\n\n'
              'Pastikan seluruh lembar jawaban Anda telah terkirim (submit) sebelum keluar.',
              style: TextStyle(fontSize: 13.5, height: 1.45),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.grayBlue,
                ),
                child: const Text('Batal / Lanjut Ujian'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Ya, Selesai & Keluar'),
              ),
            ],
          ),
        );
      },
    );

    if (exitGranted == true) {
      await _confirmedExit();
    }
  }

  Future<void> _showAboutDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBlue.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.softBlue,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/logo_sekolah.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ExamPrima',
                  style: TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Aplikasi Ujian Aman & Terpercaya',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.grayBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ExamPrima adalah aplikasi ujian digital yang '
                  'digunakan untuk membantu pelaksanaan ujian secara '
                  'aman, tertib, dan terpercaya.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.darkBlue.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Versi Aplikasi',
                            style: TextStyle(
                              color: AppColors.grayBlue,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: AppColors.darkBlue,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dikembangkan untuk',
                            style: TextStyle(
                              color: AppColors.grayBlue,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            'SMK PGRI 5 Jember',
                            style: TextStyle(
                              color: AppColors.darkBlue,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleBackBlocked();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    if (_errorMessage == null)
                      WebViewWidget(controller: _controller),

                    if (_isLoading && _errorMessage == null)
                      const Center(child: CircularProgressIndicator()),

                    if (_isLoading && _errorMessage == null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: _progress == 0 ? null : _progress,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          color: AppColors.primaryBlue,
                        ),
                      ),

                    if (_errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 48,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _retry,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      ),

                    Positioned(
                      top: 12,
                      right: 12,
                      child: _ThreeDotMenu(
                        onAbout: _showAboutDialog,
                      ),
                    ),

                    if (_isMultiWindowBlocked)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFFB3261E),
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.splitscreen_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'BELAH LAYAR TERDETEKSI',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Dilarang membuka aplikasi lain atau menggunakan fitur belah layar (Split Screen / Pop-up) selama ujian!\n\nKembalikan ExamPrima ke satu layar penuh untuk melanjutkan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() => _isMultiWindowBlocked = false);
                                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFB3261E),
                                ),
                                child: const Text(
                                  'Saya Sudah Memulihkan Layar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              _BottomControlBar(
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                onExit: _handleExitTap,
                onRefresh: _handleRefresh,
                onBack: _handleBack,
                onForward: _handleForward,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreeDotMenu extends StatelessWidget {
  const _ThreeDotMenu({required this.onAbout});

  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: AppColors.darkBlue, size: 22),
        padding: EdgeInsets.zero,
        splashRadius: 20,
        color: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        offset: const Offset(0, 44),
        onSelected: (value) {
          switch (value) {
            case 'about':
              onAbout();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'about',
            child: _MenuRow(
              icon: Icons.info_outline_rounded,
              label: 'About',
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.darkBlue),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BottomControlBar extends StatelessWidget {
  const _BottomControlBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onExit,
    required this.onRefresh,
    required this.onBack,
    required this.onForward,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onExit;
  final VoidCallback onRefresh;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomBarButton(
              icon: Icons.logout_rounded,
              label: 'Exit',
              enabled: true,
              activeColor: Colors.redAccent,
              onTap: onExit,
            ),
            _BottomBarButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              enabled: true,
              activeColor: AppColors.primaryBlue,
              onTap: onRefresh,
            ),
            _BottomBarButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back',
              enabled: canGoBack,
              activeColor: AppColors.primaryBlue,
              onTap: onBack,
            ),
            _BottomBarButton(
              icon: Icons.arrow_forward_rounded,
              label: 'Forward',
              enabled: canGoForward,
              activeColor: AppColors.primaryBlue,
              onTap: onForward,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  const _BottomBarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = enabled ? activeColor : const Color(0xFFC7D2DE);

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}