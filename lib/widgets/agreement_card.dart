import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AgreementCard extends StatelessWidget {
  const AgreementCard({
    super.key,
    required this.isChecked,
    required this.onChanged,
  });

  final bool isChecked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isChecked),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.softBlue, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBlue.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: AppColors.primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sebelum Mulai',
                    style: GoogleFonts.poppins(
                      color: AppColors.darkBlue,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Saya sudah membaca dan memahami semua ketentuan ujian.',
                    style: GoogleFonts.poppins(
                      color: AppColors.grayBlue,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            Container(
              width: 1,
              height: 36,
              color: AppColors.softBlue,
              margin: const EdgeInsets.symmetric(horizontal: 6),
            ),
            _CustomCheckbox(isChecked: isChecked),
          ],
        ),
      ),
    );
  }
}

class _CustomCheckbox extends StatelessWidget {
  const _CustomCheckbox({required this.isChecked});

  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isChecked ? AppColors.primaryBlue : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecked ? AppColors.primaryBlue : AppColors.softBlue,
          width: 2,
        ),
      ),
      child: isChecked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : null,
    );
  }
}
