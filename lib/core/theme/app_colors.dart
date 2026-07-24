import 'package:flutter/material.dart';

/// Ninedogs 색상 토큰.
///
/// 검정을 바탕으로 하고 강조는 빨강 하나로만 준다. 금액·선택 상태·주요
/// 버튼처럼 "지금 봐야 할 곳"에만 빨강을 쓰고 나머지는 무채색으로 둔다.
/// 빨강을 남발하면 차분한 느낌이 사라진다.
abstract final class AppColors {
  /// 넷플릭스 레드. 어두운 배경과 밝은 배경 모두에서 대비가 충분하다.
  static const accent = Color(0xFFE50914);
  static const accentPressed = Color(0xFFB20710);

  /// 빨강 위에 올라가는 글자·아이콘 색.
  static const onAccent = Color(0xFFFFFFFF);

  // 구독 상태 표시용
  static const positive = Color(0xFF3FB68B);
  static const negative = Color(0xFFE5484D);

  // Dark — 순수 검정 바탕에 단계별로 살짝만 띄운다
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF121212);
  static const darkSurfaceRaised = Color(0xFF1A1A1C);
  static const darkBorder = Color(0xFF2A2A2E);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF9C9CA4);

  // Light — 검정 글자에 흰 바탕. 강조색은 그대로 빨강.
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF6F6F7);
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE4E4E8);
  static const lightTextPrimary = Color(0xFF0B0B0C);
  static const lightTextSecondary = Color(0xFF6B6B73);
}
