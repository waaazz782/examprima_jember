import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../utils/design_scale.dart';

/// Loading card — dibuat premium dengan glassmorphism ringan:
/// background putih semi-transparan, border putih transparan, radius
/// besar, shadow lembut, dan blur halus di baliknya. Lebar ±83% layar
/// (bukan hampir penuh), diposisikan di area bawah hero content.
class SplashLoadingCard extends StatelessWidget {
  const SplashLoadingCard({
    super.key,
    required this.scale,
    required this.progress,
  });

  final DesignScale scale;

  /// Nilai progress 0.0 - 1.0, dianimasikan dari pemanggil.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double cardWidth = scale.w(300);
    final double radius = scale.w(26);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: cardWidth,
          padding: EdgeInsets.symmetric(
            horizontal: scale.w(26),
            vertical: scale.h(22),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkBlue.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Memuat aplikasi...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.darkBlue,
                  fontSize: scale.w(16.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: scale.h(14)),
              _ProgressTrack(scale: scale, progress: progress),
              SizedBox(height: scale.h(10)),
              Text(
                'Loading...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.grayBlue,
                  fontSize: scale.w(13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.scale, required this.progress});

  final DesignScale scale;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double barHeight = scale.w(7).clamp(6, 8);

    return ClipRRect(
      borderRadius: BorderRadius.circular(barHeight),
      child: Container(
        width: double.infinity,
        height: barHeight,
        color: AppColors.softBlue.withValues(alpha: 0.7),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(barHeight),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E9BFA), AppColors.primaryBlue],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
