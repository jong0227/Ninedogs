import 'package:flutter/material.dart';

/// 앱에서 날짜를 고를 때 쓰는 하나의 입구.
///
/// 기본 [showDatePicker] 는 헤더에 연필 아이콘이 붙어 '직접 입력' 모드로
/// 넘어갈 수 있는데, 이 앱에서 고르는 날짜(구독 시작일·결제일)는 달력에서
/// 짚는 편이 훨씬 빠르다. 아이콘만 사라져도 화면이 한결 정돈된다.
///
/// 모양(색·라운드·타이포)은 `AppTheme.datePickerTheme` 에서 잡는다.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String helpText,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    confirmText: '선택',
    cancelText: '취소',
    initialEntryMode: DatePickerEntryMode.calendarOnly,
  );
}
