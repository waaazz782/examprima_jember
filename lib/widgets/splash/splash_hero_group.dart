import 'package:flutter/material.dart';

import '../../utils/design_scale.dart';
import 'splash_logo.dart';
import 'splash_tagline.dart';
import 'splash_title.dart';

/// Logo, "ExamPrima", dan tagline dikelompokkan sebagai SATU visual
/// group dengan spacing yang terkontrol — bukan tiga widget yang
/// diposisikan terpisah secara acak. Animasi tetap staggered (logo
/// muncul dulu, lalu judul, lalu tagline) tetapi strukturnya tetap
/// satu kesatuan komposisi.
class SplashHeroGroup extends StatelessWidget {
  const SplashHeroGroup({
    super.key,
    required this.scale,
    required this.logoFade,
    required this.logoScale,
    required this.titleFade,
    required this.taglineFade,
  });

  final DesignScale scale;
  final Animation<double> logoFade;
  final Animation<double> logoScale;
  final Animation<double> titleFade;
  final Animation<double> taglineFade;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: logoScale,
          child: FadeTransition(
            opacity: logoFade,
            child: SplashLogo(scale: scale),
          ),
        ),
        SizedBox(height: scale.h(22)),
        FadeTransition(
          opacity: titleFade,
          child: SplashTitle(scale: scale),
        ),
        SizedBox(height: scale.h(10)),
        FadeTransition(
          opacity: taglineFade,
          child: SplashTagline(scale: scale),
        ),
      ],
    );
  }
}
