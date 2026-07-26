import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/features/shell/back_exit.dart';

void main() {
  final now = DateTime(2026, 7, 26, 12, 0, 0);

  BackAction decide({
    int tabIndex = 0,
    bool hasOpenDetail = false,
    DateTime? lastBackPressedAt,
  }) => decideBackAction(
    tabIndex: tabIndex,
    hasOpenDetail: hasOpenDetail,
    lastBackPressedAt: lastBackPressedAt,
    now: now,
  );

  group('뒤로가기', () {
    test('첫 탭에서 처음 누르면 알리기만 한다', () {
      expect(decide(), BackAction.warn);
    });

    test('짧은 시간 안에 다시 누르면 끈다', () {
      expect(
        decide(
          lastBackPressedAt: now.subtract(const Duration(milliseconds: 800)),
        ),
        BackAction.exit,
      );
    });

    test('한참 전에 누른 건 안 친다', () {
      // 아까 눌러둔 게 살아 있다가 갑자기 꺼지면 안 된다.
      expect(
        decide(lastBackPressedAt: now.subtract(const Duration(seconds: 30))),
        BackAction.warn,
      );
    });

    test('경계 시각은 종료로 치지 않는다', () {
      expect(
        decide(lastBackPressedAt: now.subtract(const Duration(seconds: 2))),
        BackAction.warn,
      );
    });

    test('다른 탭에서는 끄지 않고 첫 탭으로 간다', () {
      // 설정에서 뒤로가기를 눌렀을 때 기대하는 건 종료가 아니라 목록이다.
      for (final tab in [1, 2, 3]) {
        expect(decide(tabIndex: tab), BackAction.goToFirstTab);
      }
    });

    test('다른 탭이면 직전에 눌렀더라도 끄지 않는다', () {
      expect(
        decide(
          tabIndex: 3,
          lastBackPressedAt: now.subtract(const Duration(milliseconds: 100)),
        ),
        BackAction.goToFirstTab,
      );
    });

    test('캘린더에서 날짜를 골랐으면 탭이나 종료보다 먼저 그것부터 닫는다', () {
      // 예: 캘린더에서 날짜를 선택한 채 뒤로가기 — 탭 전환도, 종료도 아니고
      // 전체 목록으로 돌아가야 한다.
      expect(decide(hasOpenDetail: true), BackAction.closeDetail);
    });

    test('날짜를 고른 채 다른 탭에 있어도 상세부터 닫는다', () {
      expect(
        decide(tabIndex: 2, hasOpenDetail: true),
        BackAction.closeDetail,
      );
    });

    test('날짜를 고른 채 직전에 눌렀어도 종료로 치지 않는다', () {
      expect(
        decide(
          hasOpenDetail: true,
          lastBackPressedAt: now.subtract(const Duration(milliseconds: 100)),
        ),
        BackAction.closeDetail,
      );
    });
  });
}
