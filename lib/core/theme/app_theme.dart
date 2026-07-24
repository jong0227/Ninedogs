import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceRaised: AppColors.darkSurfaceRaised,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceRaised: AppColors.lightSurfaceRaised,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceRaised,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      surface: surface,
      onSurface: textPrimary,
      outline: border,
      error: AppColors.negative,
    );

    final base = ThemeData(brightness: brightness, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      dividerColor: border,
      textTheme: _textTheme(base.textTheme, textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  /// 타입 스케일.
  ///
  /// 한글은 라틴보다 글자폭이 넓어서 자간을 많이 좁히면 답답해 보인다.
  /// 큰 제목에만 음수 자간을 주고 본문은 0 근처에 둔다. 반대로 작은 라벨은
  /// 살짝 벌려야 또렷하게 읽힌다.
  static TextTheme _textTheme(TextTheme base, Color primary, Color secondary) {
    return base
        .copyWith(
          // 온보딩처럼 화면을 여는 큰 제목
          displayMedium: base.displayMedium?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            height: 1.22,
          ),
          // 대시보드의 히어로 금액
          displaySmall: base.displaySmall?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            height: 1.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          // 섹션 제목
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
            height: 1.3,
          ),
          // 목록 항목 이름
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
            height: 1.35,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontSize: 14,
            letterSpacing: -0.05,
            height: 1.5,
          ),
          // 보조 설명·수치 라벨. 작을수록 살짝 벌린다.
          labelMedium: base.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            height: 1.4,
            color: secondary,
          ),
        )
        .apply(bodyColor: primary, displayColor: primary);
  }

  /// 금액처럼 자릿수가 흔들리면 안 되는 숫자에 쓴다.
  /// 고정폭 숫자라 값이 바뀌어도 자리가 움직이지 않는다.
  static const numeric = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: -0.2,
  );
}
