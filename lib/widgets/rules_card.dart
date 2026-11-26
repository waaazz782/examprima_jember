import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class RulesCard extends StatelessWidget {
  const RulesCard({super.key});

  static const List<String> _rules = [
    'Pastikan koneksi internet stabil.',
    'Gunakan perangkat yang mendukung ujian dengan baik.',
    'Kerjakan ujian secara mandiri dan jujur.',
    'Dilarang membuka aplikasi atau tab lain selama ujian.',
    'Jangan meninggalkan halaman ujian sebelum selesai.',
    'Pastikan baterai perangkat mencukupi.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Ketentuan Ujian',
                style: GoogleFonts.poppins(
                  color: AppColors.darkBlue,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _rules.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NumberBadge(number: i + 1),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _rules[i],
                        style: GoogleFonts.poppins(
                          color: AppColors.darkBlue,
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != _rules.length - 1)
              const Divider(
                color: AppColors.dividerBlue,
                thickness: 1,
                height: 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E9BFA),
            AppColors.primaryBlue,
          ],
        ),
      ),
      child: Text(
        '$number',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
