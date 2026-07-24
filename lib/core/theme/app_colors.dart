import 'package:flutter/material.dart';

/// Ninedogs 색상 토큰.
///
/// 따뜻한 앰버 액센트 + 차분한 중성 배경. 화면 대부분은 중성색이고
/// 액센트는 금액·강조 지점에만 쓴다.
abstract final class AppColors {
  static const accent = Color(0xFFF2A93B);
  static const accentPressed = Color(0xFFD98F22);

  // 구독 상태 표시용
  static const positive = Color(0xFF3FB68B);
  static const negative = Color(0xFFE5645E);

  // Dark
  static const darkBackground = Color(0xFF111214);
  static const darkSurface = Color(0xFF1A1C1F);
  static const darkSurfaceRaised = Color(0xFF23262A);
  static const darkBorder = Color(0xFF2E3237);
  static const darkTextPrimary = Color(0xFFF4F5F7);
  static const darkTextSecondary = Color(0xFF9BA1A9);

  // Light
  static const lightBackground = Color(0xFFF7F7F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE3E4E8);
  static const lightTextPrimary = Color(0xFF16181C);
  static const lightTextSecondary = Color(0xFF6B7079);
}
