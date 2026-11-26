import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class ExamHeader extends StatelessWidget {
  const ExamHeader({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_sekolah.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Exam',
                          style: GoogleFonts.poppins(
                            color: AppColors.darkBlue,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: 'Prima',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryBlue,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryBlue,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}