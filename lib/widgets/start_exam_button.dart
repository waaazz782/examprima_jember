import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../pages/exam_webview_page.dart';

class StartExamButton extends StatelessWidget {
  const StartExamButton({super.key, required this.isEnabled});

  final bool isEnabled;

  static const String _examUrl = 'http://10.10.2.2';

  Future<void> _openExam(BuildContext context) async {
    if (Platform.isIOS) {
      final bool proceed = await _showGuidedAccessReminder(context);
      if (!proceed) return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExamWebViewPage(url: _examUrl),
      ),
    );
  }

  Future<bool> _showGuidedAccessReminder(BuildContext context) async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Aktifkan Guided Access'),
          content: const Text(
            'Untuk keamanan maksimal selama ujian, disarankan '
            'mengaktifkan Guided Access terlebih dahulu:\n\n'
            '1. Tiga kali klik cepat tombol Side/Home\n'
            '2. Ketuk "Mulai" pada layar Guided Access\n\n'
            'Setelah itu, kembali ke ExamPrima dan lanjutkan ujian.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal', style: TextStyle(color: AppColors.grayBlue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Lanjutkan',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    return proceed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? () => _openExam(context) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: isEnabled
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF2E9BFA),
                    AppColors.primaryBlue,
                  ],
                )
              : null,
          color: isEnabled ? null : const Color(0xFFBFDDF9),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              height: 20,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            Flexible(
              child: Text(
                'Saya Mengerti, Mulai Ujian',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}