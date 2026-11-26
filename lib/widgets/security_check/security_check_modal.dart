import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../constants/forbidden_ai_apps.dart';
import '../../services/ai_app_checker_service.dart';
import '../../services/app_uninstaller_service.dart';
class SecurityCheckGate extends StatefulWidget {
  const SecurityCheckGate({super.key, required this.child});

  final Widget child;

  @override
  State<SecurityCheckGate> createState() => _SecurityCheckGateState();
}

class _SecurityCheckGateState extends State<SecurityCheckGate> {
  @override
  void initState() {
    super.initState();

    if (Platform.isIOS) return;

    // Tampilkan modal setelah frame pertama selesai dibangun.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showSecurityModal();
    });
  }

  Future<void> _showSecurityModal() {
    return showDialog(
      context: context,
      barrierDismissible: false, // tidak bisa ditutup dari luar modal
      barrierColor: AppColors.darkBlue.withValues(alpha: 0.55),
      builder: (context) => const _SecurityCheckModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

enum _CheckStatus { checking, blocked, success }

class _SecurityCheckModal extends StatefulWidget {
  const _SecurityCheckModal();

  @override
  State<_SecurityCheckModal> createState() => _SecurityCheckModalState();
}

class _SecurityCheckModalState extends State<_SecurityCheckModal>
    with WidgetsBindingObserver {
  final _checker = AiAppCheckerService();

  _CheckStatus _status = _CheckStatus.checking;
  List<ForbiddenAiApp> _detected = const [];

  bool _hasCheckedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_runCheck);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _hasCheckedOnce &&
        _status != _CheckStatus.success &&
        mounted) {
      _runCheck();
    }
  }

  Future<void> _runCheck() async {
    setState(() => _status = _CheckStatus.checking);

    final detected = await _checker.findInstalledForbiddenApps();

    if (!mounted) return;
    setState(() {
      _detected = detected;
      _status = detected.isEmpty ? _CheckStatus.success : _CheckStatus.blocked;
      _hasCheckedOnce = true;
    });
  }

  Future<void> _handleDelete(ForbiddenAiApp app) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(
          'Membuka info aplikasi ${app.displayName}...',
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
      ),
    );

    try {
      final String? resolvedBy =
          await AppUninstallerService.instance.uninstall(app.packageName);
      if (!mounted) return;
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B7A3D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            'Diteruskan ke: ${resolvedBy ?? "(tidak diketahui)"}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB3261E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            'Gagal membuka uninstall ${app.displayName}:\n$e',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkBlue.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: switch (_status) {
            _CheckStatus.checking => const _CheckingContent(),
            _CheckStatus.blocked => _BlockedContent(
                detected: _detected,
                onRecheck: _runCheck,
                onDelete: _handleDelete,
              ),
            _CheckStatus.success => _SuccessContent(
                onContinue: () => Navigator.of(context).pop(),
              ),
          },
        ),
      ),
    );
  }
}

/// Status awal: sedang memeriksa (singkat).
class _CheckingContent extends StatelessWidget {
  const _CheckingContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Memeriksa perangkat...',
          style: GoogleFonts.poppins(
            color: AppColors.darkBlue,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BlockedContent extends StatefulWidget {
  const _BlockedContent({
    required this.detected,
    required this.onRecheck,
    required this.onDelete,
  });

  final List<ForbiddenAiApp> detected;
  final VoidCallback onRecheck;
  final Future<void> Function(ForbiddenAiApp app) onDelete;

  @override
  State<_BlockedContent> createState() => _BlockedContentState();
}

class _BlockedContentState extends State<_BlockedContent> {
  bool _rechecking = false;

  Future<void> _handleRecheck() async {
    setState(() => _rechecking = true);
    await Future.sync(widget.onRecheck);
    if (mounted) setState(() => _rechecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1E0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Color(0xFFE8901C),
            size: 32,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Persiapan Sebelum Ujian',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.darkBlue,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Untuk menjaga keamanan dan integritas ujian, perbaiki hal-hal berikut sebelum memulai:',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.grayBlue,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 18),
        if (widget.detected.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6EC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFBE0BB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE8901C),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aplikasi AI / Solver Ditemukan',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFB4650A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final app in widget.detected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Text(
                          '•  ',
                          style: TextStyle(color: AppColors.darkBlue),
                        ),
                        Expanded(
                          child: Text(
                            app.displayName,
                            style: GoogleFonts.poppins(
                              color: AppColors.darkBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _UninstallButton(
                          onTap: () => widget.onDelete(app),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Silakan hapus aplikasi tersebut langsung melalui tombol Hapus di atas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.grayBlue,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _rechecking ? null : _handleRecheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 0,
            ),
            child: _rechecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 19),
                      const SizedBox(width: 8),
                      Text(
                        'Periksa Kembali',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _UninstallButton extends StatelessWidget {
  const _UninstallButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFDEAEA),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFF3C2C2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              size: 14,
              color: Color(0xFFC53E3E),
            ),
            const SizedBox(width: 4),
            Text(
              'Hapus',
              style: GoogleFonts.poppins(
                color: const Color(0xFFC53E3E),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E9BFA), AppColors.primaryBlue],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Perangkat Siap Digunakan',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.darkBlue,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tidak ditemukan aplikasi AI yang dilarang pada perangkat.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.grayBlue,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryBlue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Pemeriksaan berhasil',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryBlue,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 0,
            ),
            child: Text(
              'Lanjutkan',
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}