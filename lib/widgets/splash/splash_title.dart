import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../utils/design_scale.dart';

/// Tulisan "ExamPrima" — branding utama setelah logo. Dibuat jauh lebih
/// besar & tegas (38-44px pada baseline 360dp), dua warna dalam satu
/// baris, dengan letter-spacing negatif tipis agar terasa seperti
/// wordmark/brand, bukan teks biasa.
class SplashTitle extends StatelessWidget {
  const SplashTitle({super.key, required this.scale});

  final DesignScale scale;

  @override
  Widget build(BuildContext context) {
    final double fontSize = scale.w(41).clamp(36, 46);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Exam',
            style: GoogleFonts.poppins(
              color: AppColors.darkBlue,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.0,
            ),
          ),
          TextSpan(
            text: 'Prima',
            style: GoogleFonts.poppins(
              color: AppColors.primaryBlue,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
