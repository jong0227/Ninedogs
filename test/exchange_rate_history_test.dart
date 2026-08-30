import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/exchange/exchange_rate_history.dart';
import 'package:ninedogs/data/models/money.dart';

void main() {
  // ECB 고시 환율은 영업일에만 있다. 1/13(토)·1/14(일)은 비어 있다.
  final table = RateTable(const {
    '2024-01-11': 1314.64,
    '2024-01-12': 1314.87,
    '2024-01-15': 1322.02,
    '2024-01-16': 1337.0,
  });

  group('그날의 환율 찾기', () {
    test('고시된 날은 그 값을 그대로 쓴다', () {
      expect(table.rateOn(DateTime(2024, 1, 15)), 1322.02);
    });

    test('휴장일은 직전 영업일 값을 쓴다', () {
      // 토요일에 결제됐으면 금요일 환율이 실제 적용 환율에 가깝다.
      expect(table.rateOn(DateTime(2024, 1, 13)), 1314.87);
      expect(table.rateOn(DateTime(2024, 1, 14)), 1314.87);
    });

    test('표보다 이른 날짜는 가장 오래된 값으로 버틴다', () {
      // 모르는 건 맞지만, 빼버리면 그 결제가 통계에서 통째로 사라진다.
      expect(table.rateOn(DateTime(2020, 5, 1)), 1314.64);
    });

    test('표보다 늦은 날짜는 가장 최근 값을 쓴다', () {
      expect(table.rateOn(DateTime(2026, 8, 30)), 1337.0);
    });

    test('시각이 섞여 있어도 날짜만 본다', () {
      expect(table.rateOn(DateTime(2024, 1, 15, 23, 59)), 1322.02);
    });
  });

  group('표가 비었을 때', () {
    test('대략값으로 대신한다', () {
      // 환율을 못 받아왔다고 화면이 비면 안 된다.
      final empty = RateTable(const {}, fallback: 1450.0);
      expect(empty.isEmpty, isTrue);
      expect(empty.rateOn(DateTime(2024, 1, 15)), 1450.0);
    });
  });

  group('원화 환산', () {
    test('그날 환율로 환산한다', () {
      // $9.99 × 1322.02 = 13,206.98... → 13,207원
      final converted = table.toKrwOn(
        const Money(999, currency: 'USD'),
        DateTime(2024, 1, 15),
      );
      expect(converted.currency, Money.krw);
      expect(converted.minor, 13207);
    });

    test('같은 금액도 시점이 다르면 환산액이 다르다', () {
      const amount = Money(999, currency: 'USD');
      final early = table.toKrwOn(amount, DateTime(2024, 1, 11));
      final late = table.toKrwOn(amount, DateTime(2024, 1, 16));

      expect(early.minor, lessThan(late.minor));
    });

    test('원화는 손대지 않는다', () {
      const won = Money(13500);
      expect(table.toKrwOn(won, DateTime(2024, 1, 15)), won);
    });
  });

  group('조회 간격', () {
    test('고정되지 않고 11~13시간 사이에서 흔들린다', () {
      // 초 단위까지 일정한 주기는 자동화 패턴이 드러나서 상대 서버의
      // 봇 탐지나 레이트리밋에 걸리기 쉽다.
      final service = ExchangeRateHistoryService(random: Random(7));
      final gaps = List.generate(50, (_) => service.nextRefreshGap());

      for (final gap in gaps) {
        expect(gap.inMinutes, greaterThanOrEqualTo(11 * 60));
        expect(gap.inMinutes, lessThanOrEqualTo(13 * 60));
      }
      // 매번 같은 값이면 지터가 아니다.
      expect(gaps.toSet().length, greaterThan(1));
    });
  });
}
