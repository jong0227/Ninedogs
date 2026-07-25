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
      // 다이얼로그를 따로 잡지 않으면 기본 Material 모양(28px 라운드, 옅은
      // 보라 틴트)이 나와서 앱의 나머지와 따로 논다. 카드와 같은 표면색·
      // 테두리·라운드를 쓴다.
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.35,
        ),
        contentTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          letterSpacing: -0.05,
          height: 1.5,
        ),
      ),
      // 바텀시트도 카드와 같은 결로 맞춘다.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: border),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
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
      // 날짜 선택기는 기본 모양이 유독 옛날 Material 처럼 보인다.
      // 표면색·라운드·강조색을 앱과 맞추고, 선택된 날짜만 빨강으로 채운다.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
        headerBackgroundColor: surfaceRaised,
        headerForegroundColor: textSecondary,
        headerHeadlineStyle: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headerHelpStyle: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        weekdayStyle: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        dayStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.onAccent;
          if (states.contains(WidgetState.disabled)) {
            return textSecondary.withValues(alpha: 0.35);
          }
          return textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : Colors.transparent,
        ),
        // 오늘 날짜는 테두리로만 표시한다. 선택된 날과 헷갈리면 안 된다.
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onAccent
              : AppColors.accent,
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : Colors.transparent,
        ),
        todayBorder: const BorderSide(color: AppColors.accent, width: 1.2),
        yearStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onAccent
              : textPrimary,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : Colors.transparent,
        ),
        dividerColor: Colors.transparent,
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: textSecondary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
