import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../utils/design_scale.dart';

/// Tagline "Aplikasi Ujian Aman & Terpercaya" — lebih kecil & kontras,
/// diberi jarak yang jelas dari "ExamPrima" di atasnya (bukan menempel).
class SplashTagline extends StatelessWidget {
  const SplashTagline({super.key, required this.scale});

  final DesignScale scale;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aplikasi Ujian Aman & Terpercaya',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: AppColors.darkBlue.withValues(alpha: 0.75),
        fontSize: scale.w(16).clamp(14, 18),
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
