import 'package:flutter/material.dart';

class DesignScale {
  DesignScale(BuildContext context)
      : screenWidth = MediaQuery.of(context).size.width,
        screenHeight = MediaQuery.of(context).size.height;

  static const double baseWidth = 360;
  static const double baseHeight = 740;

  final double screenWidth;
  final double screenHeight;

  double w(double baselinePx) => baselinePx / baseWidth * screenWidth;

  double h(double baselinePx) => baselinePx / baseHeight * screenHeight;
}
