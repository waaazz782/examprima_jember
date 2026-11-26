import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/design_scale.dart';

/// Dekorasi titik-titik biru (4 kolom x 3 baris), dibuat kecil dan
/// subtle (opacity ±60%) agar tidak mendominasi — murni elemen visual
/// di area langit kiri atas, tanpa interaksi.
class SplashDots extends StatelessWidget {
  const SplashDots({super.key, required this.scale});

  final DesignScale scale;

  @override
  Widget build(BuildContext context) {
    final double dotSize = scale.w(6);
    final double gap = scale.w(9);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (row) {
        return Padding(
          padding: EdgeInsets.only(bottom: row == 2 ? 0 : gap),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (col) {
              return Padding(
                padding: EdgeInsets.only(right: col == 3 ? 0 : gap),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryBlue.withValues(alpha: 0.55),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
