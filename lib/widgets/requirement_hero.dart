import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class RequirementHero extends StatelessWidget {
  const RequirementHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(),
                const SizedBox(height: 18),
                _GradientTitle(),
                const SizedBox(height: 6),
                // Garis dekorasi kecil di bawah judul.
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pastikan kamu sudah memenuhi semua persyaratan '
                  'berikut sebelum memulai ujian.',
                  style: GoogleFonts.poppins(
                    color: AppColors.grayBlue,
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: AspectRatio(
              aspectRatio: 560 / 430,
              child: Image.asset(
                'assets/images/exam_illustration.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.description_rounded,
            color: AppColors.primaryBlue,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Syarat & Ketentuan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AppColors.primaryBlue,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Syarat ',
            style: GoogleFonts.poppins(
              color: AppColors.darkBlue,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          TextSpan(
            text: 'Ujian',
            style: GoogleFonts.poppins(
              color: AppColors.primaryBlue,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}