/// 뒤로가기를 눌렀을 때 할 일.
enum BackAction {
  /// 탭 안에서 열어둔 상세 상태(예: 캘린더의 날짜 선택)부터 닫는다.
  closeDetail,

  /// 첫 탭(구독)으로 돌아간다.
  goToFirstTab,

  /// 한 번 더 눌러야 꺼진다고 알린다.
  warn,

  /// 앱을 끈다.
  exit,
}

/// 뒤로가기 한 번에 앱이 꺼지는 걸 막는다.
///
/// 목록을 보다 실수로 뒤로가기를 스치면 앱이 그대로 닫혀버린다. 안드로이드
/// 앱들이 흔히 쓰는 대로, 짧은 시간 안에 두 번 눌러야만 끄도록 한다.
///
/// 탭 안에 화면을 새로 push 하지 않고도 상세 상태로 들어가는 경우가 있다
/// (예: 캘린더에서 날짜를 고르면 그날 결제만 보여준다). 그런 상태가 열려
/// 있으면 뒤로가기는 그것부터 닫아야 한다 — 안 그러면 날짜를 고른 채로
/// 뒤로가기를 눌렀을 때 탭 이동이나 종료로 튀어서 전체 목록으로 못 돌아간다.
///
/// 그 다음이 탭 전환이다. 다른 탭에 있을 때는 끄지 않고 첫 탭으로 돌아간다.
/// 설정 화면에서 뒤로가기를 눌렀을 때 기대하는 건 앱 종료가 아니라 원래
/// 보던 목록이다.
///
/// [window] 안에 다시 눌러야 종료로 친다. 너무 길면 한참 전에 누른 게
/// 살아 있다가 갑자기 꺼지고, 너무 짧으면 두 번 눌러도 안 꺼진다.
BackAction decideBackAction({
  required int tabIndex,
  required bool hasOpenDetail,
  required DateTime? lastBackPressedAt,
  required DateTime now,
  Duration window = const Duration(seconds: 2),
}) {
  if (hasOpenDetail) return BackAction.closeDetail;
  if (tabIndex != 0) return BackAction.goToFirstTab;

  final last = lastBackPressedAt;
  if (last != null && now.difference(last) < window) return BackAction.exit;

  return BackAction.warn;
}
