import 'package:flutter/material.dart';

import '../utils/design_scale.dart';
import '../widgets/splash/splash_background.dart';
import '../widgets/splash/splash_dots.dart';
import '../widgets/splash/splash_hero_group.dart';
import '../widgets/splash/splash_loading_card.dart';
import 'exam_requirement_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _cardFade;
  late final Animation<double> _progress;

  static const double _initialProgress = 0.38;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.58, curve: Curves.easeOut),
    );

    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.40, 0.72, curve: Curves.easeOut),
    );

    _cardFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.82, curve: Curves.easeOut),
    );

    _progress = Tween<double>(begin: _initialProgress, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToExamRequirementPage();
      }
    });
  }

  void _goToExamRequirementPage() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const ExamRequirementPage(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = DesignScale(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [

          const SplashBackground(),

          Positioned(
            top: scale.h(30),
            left: scale.w(24),
            child: SplashDots(scale: scale),
          ),

          Positioned(
            top: scale.h(70),
            left: 0,
            right: 0,
            child: Center(
              child: SplashHeroGroup(
                scale: scale,
                logoFade: _logoFade,
                logoScale: _logoScale,
                titleFade: _titleFade,
                taglineFade: _taglineFade,
              ),
            ),
          ),

          Positioned(
            top: scale.h(392),
            left: 0,
            right: 0,
            child: Center(
              child: FadeTransition(
                opacity: _cardFade,
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) {
                    return SplashLoadingCard(
                      scale: scale,
                      progress: _progress.value,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
