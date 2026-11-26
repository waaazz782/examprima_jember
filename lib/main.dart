import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants/app_colors.dart';
import 'pages/splash_screen.dart';

void main() {
  runApp(const ExamPrimaApp());
}

class ExamPrimaApp extends StatelessWidget {
  const ExamPrimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamPrima',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const SplashScreen(),
    );
  }
}
