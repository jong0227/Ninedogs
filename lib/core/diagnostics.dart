import 'package:flutter/foundation.dart';

/// 삼키기로 한 오류를 기록만 해둔다.
///
/// 이 앱에는 실패해도 계속 가야 하는 곳이 여럿 있다 — 환율을 못 받아와도,
/// 아이콘을 못 불러와도 앱은 돌아야 한다. 그래서 `catch (_)` 로 넘기는데,
/// 그러다 보니 **무엇이 왜 실패했는지 알 방법이 전혀 없었다.** 사용자가
/// "아이콘이 안 떠요"라고 하면 짚을 단서가 하나도 없다.
///
/// 릴리즈 빌드에서는 아무것도 하지 않는다([kDebugMode] 로 걸러낸다).
/// 사용자에게 보일 내용이 아니고, 로그가 새 나갈 이유도 없다.
void logIgnored(String what, Object error, [StackTrace? stackTrace]) {
  if (!kDebugMode) return;

  debugPrint('[Ninedogs] $what: $error');
  if (stackTrace != null) debugPrint('$stackTrace');
}
