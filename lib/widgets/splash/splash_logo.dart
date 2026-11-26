import 'package:flutter/material.dart';

import '../../utils/design_scale.dart';

/// Logo SMK PGRI 5 Jember — identitas utama splash screen, diperbesar
/// secara proporsional (baseline ±126dp untuk layar 360dp) dengan glow
/// biru sangat halus di belakangnya (bukan efek neon).
class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key, required this.scale});

  final DesignScale scale;

  @override
  Widget build(BuildContext context) {
    final double logoSize = scale.w(126).clamp(108, 152);
    final double glowSize = logoSize * 1.55;

    return SizedBox(
      width: glowSize,
      height: glowSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow biru sangat halus.
          Container(
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.55),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF087FF5).withValues(alpha: 0.18),
                  blurRadius: logoSize * 0.35,
                  spreadRadius: logoSize * 0.02,
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/logo_sekolah.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
