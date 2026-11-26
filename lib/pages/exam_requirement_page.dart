import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../widgets/agreement_card.dart';
import '../widgets/exam_header.dart';
import '../widgets/exam_type_card.dart';
import '../widgets/requirement_hero.dart';
import '../widgets/rules_card.dart';
import '../widgets/security_check/security_check_modal.dart';
import '../widgets/start_exam_button.dart';
class ExamRequirementPage extends StatefulWidget {
  const ExamRequirementPage({super.key});

  @override
  State<ExamRequirementPage> createState() => _ExamRequirementPageState();
}

class _ExamRequirementPageState extends State<ExamRequirementPage> {
  bool _isAgreed = false;

  void _onAgreementChanged(bool value) {
    setState(() => _isAgreed = value);
  }

  @override
  Widget build(BuildContext context) {
    return SecurityCheckGate(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const _BackgroundDecoration(),
            SafeArea(
              child: Column(
                children: [
                  const ExamHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 28),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const RequirementHero(),
                          const SizedBox(height: 28),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: ExamTypeCard(),
                          ),
                          const SizedBox(height: 20),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: RulesCard(),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: AgreementCard(
                              isChecked: _isAgreed,
                              onChanged: _onAgreementChanged,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: StartExamButton(isEnabled: _isAgreed),
                          ),
                          const SizedBox(height: 20),
                          const _PaginationDots(activeIndex: 0, dotCount: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -70,
            child: _softCircle(220, AppColors.primaryBlue.withValues(alpha: 0.08)),
          ),
          Positioned(
            top: 90,
            left: -40,
            child: _softCircle(110, AppColors.primaryBlue.withValues(alpha: 0.06)),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _softCircle(260, AppColors.softBlue.withValues(alpha: 0.5)),
          ),
          Positioned(
            bottom: -120,
            right: -90,
            child: _softCircle(240, AppColors.primaryBlue.withValues(alpha: 0.05)),
          ),
          Positioned(
            top: 150,
            right: 24,
            child: _DotGrid(color: AppColors.primaryBlue.withValues(alpha: 0.18)),
          ),
          Positioned(
            bottom: 140,
            left: 18,
            child: _DotGrid(color: AppColors.primaryBlue.withValues(alpha: 0.14)),
          ),
        ],
      ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 30,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: List.generate(
          9,
          (_) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      ),
    );
  }
}

class _PaginationDots extends StatelessWidget {
  const _PaginationDots({required this.activeIndex, required this.dotCount});

  final int activeIndex;
  final int dotCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dotCount, (index) {
        final bool isActive = index == activeIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 9 : 7,
          height: isActive ? 9 : 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primaryBlue : AppColors.softBlue,
          ),
        );
      }),
    );
  }
}
