import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/widgets/date_picker_logic.dart';

void main() {
  final first = DateTime(2010, 1, 1);
  final last = DateTime(2026, 7, 26);

  group('격자 배치', () {
    test('말일이 달마다 다르다', () {
      expect(daysInMonth(2026, 1), 31);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2026, 4), 30);
    });

    test('윤년 2월은 29일이다', () {
      expect(daysInMonth(2024, 2), 29);
    });

    test('1일 앞의 빈 칸은 요일에 맞춘다', () {
      // 2026년 3월 1일은 일요일 → 앞이 비지 않는다.
      expect(leadingBlanks(2026, 3), 0);
      // 2026년 7월 1일은 수요일 → 일·월·화 세 칸이 빈다.
      expect(leadingBlanks(2026, 7), 3);
    });
  });

  group('범위 판정', () {
    test('시분초가 달라도 같은 날이면 범위 안이다', () {
      expect(
        isDateInRange(DateTime(2026, 7, 26, 23, 59), first, last),
        isTrue,
      );
    });

    test('경계 날짜는 포함한다', () {
      expect(isDateInRange(first, first, last), isTrue);
      expect(isDateInRange(last, first, last), isTrue);
    });

    test('범위 밖은 뺀다', () {
      expect(isDateInRange(DateTime(2009, 12, 31), first, last), isFalse);
      expect(isDateInRange(DateTime(2026, 7, 27), first, last), isFalse);
    });
  });

  group('달 이동', () {
    test('범위 안의 달은 고를 수 있다', () {
      expect(monthHasSelectableDay(DateTime(2019, 3), first, last), isTrue);
    });

    test('마지막 달은 하루라도 걸치면 고를 수 있다', () {
      // 2026년 7월은 26일까지만 유효하지만 고를 날이 남아 있다.
      expect(monthHasSelectableDay(DateTime(2026, 7), first, last), isTrue);
    });

    test('범위를 완전히 벗어난 달은 못 고른다', () {
      expect(monthHasSelectableDay(DateTime(2009, 12), first, last), isFalse);
      expect(monthHasSelectableDay(DateTime(2026, 8), first, last), isFalse);
    });

    test('범위 끝에서는 화살표가 막힌다', () {
      expect(canShiftMonth(DateTime(2010, 1), -1, first, last), isFalse);
      expect(canShiftMonth(DateTime(2026, 7), 1, first, last), isFalse);
      expect(canShiftMonth(DateTime(2019, 3), -1, first, last), isTrue);
    });
  });

  group('달을 옮길 때 고른 날', () {
    test('짧은 달로 가면 말일로 당긴다', () {
      // 1월 31일을 보다가 2월로 옮기면 31일이 없다.
      expect(
        clampToMonth(31, DateTime(2026, 2), first, last),
        DateTime(2026, 2, 28),
      );
    });

    test('긴 달로 돌아오면 원래 날을 그대로 쓴다', () {
      expect(
        clampToMonth(31, DateTime(2026, 3), first, last),
        DateTime(2026, 3, 31),
      );
    });

    test('범위 뒤끝을 넘으면 마지막 날로 민다', () {
      // 2026년 7월 31일은 범위 밖(26일까지)이다.
      expect(clampToMonth(31, DateTime(2026, 7), first, last), dateOnly(last));
    });

    test('범위 앞끝보다 이르면 첫 날로 민다', () {
      final narrow = DateTime(2026, 7, 10);
      expect(
        clampToMonth(1, DateTime(2026, 7), narrow, last),
        dateOnly(narrow),
      );
    });
  });

  group('직접 입력', () {
    test('숫자 8자리를 날짜로 읽는다', () {
      expect(parseCompactDate('20190315', first, last), DateTime(2019, 3, 15));
    });

    test('점이나 하이픈이 섞여도 읽는다', () {
      expect(
        parseCompactDate('2019.03.15', first, last),
        DateTime(2019, 3, 15),
      );
    });

    test('덜 쳤으면 아직 날짜가 아니다', () {
      expect(parseCompactDate('2019', first, last), isNull);
    });

    test('없는 달이나 없는 날은 거른다', () {
      expect(parseCompactDate('20191315', first, last), isNull);
      // 2019년 2월은 28일까지다.
      expect(parseCompactDate('20190230', first, last), isNull);
    });

    test('범위 밖이면 거른다', () {
      expect(parseCompactDate('20091231', first, last), isNull);
      expect(parseCompactDate('20260727', first, last), isNull);
    });
  });
}
