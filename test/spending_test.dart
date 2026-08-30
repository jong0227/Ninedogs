import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/exchange/exchange_rate_history.dart';
import 'package:ninedogs/data/exchange/spending.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';

/// "지금까지 쓴 돈"을 답하는 한 곳.
///
/// 예전엔 홈 화면과 통계 화면이 이 계산을 따로 갖고 있어서, 달러 구독이
/// 있으면 같은 질문에 두 화면이 다른 숫자를 내놨다.
void main() {
  // 시점을 고정한다. DateTime.now() 에 기대면 오늘이 언제냐에 따라
  // 결제 횟수가 달라져서 테스트가 흔들린다.
  final asOf = DateTime(2026, 3, 10);

  // 환율이 오르는 구간. 시점을 무시하면 결과가 달라진다.
  final rates = RateTable(const {
    '2026-01-05': 1300.0,
    '2026-02-05': 1400.0,
    '2026-03-05': 1500.0,
  });

  // 1/5 부터 매달 $10.00 → asOf 까지 1/5, 2/5, 3/5 세 번
  Subscription usdMonthly() => Subscription.create(
    id: 'notion',
    name: 'Notion',
    cycle: BillingCycle.monthly,
    startedAt: DateTime(2026, 1, 5),
    priceHistory: [
      PricePoint(
        effectiveFrom: DateTime(2026, 1, 5),
        amount: const Money(1000, currency: 'USD'),
        cycle: BillingCycle.monthly,
      ),
    ],
  );

  Subscription krwMonthly() => Subscription.create(
    id: 'netflix',
    name: '넷플릭스',
    cycle: BillingCycle.monthly,
    startedAt: DateTime(2026, 1, 15),
    priceHistory: [
      PricePoint(
        effectiveFrom: DateTime(2026, 1, 15),
        amount: const Money(13500),
        cycle: BillingCycle.monthly,
      ),
    ],
  );

  group('결제마다 그날 환율을 적용한다', () {
    test('환율이 오른 구간이 그대로 반영된다', () {
      // 1/5 $10×1300 + 2/5 $10×1400 + 3/5 $10×1500
      // = 13,000 + 14,000 + 15,000 = 42,000
      expect(
        lifetimeInKrw(
          usdMonthly(),
          rates: rates,
          todayRate: 1500.0,
          asOf: asOf,
        ),
        const Money(42000),
      );
    });

    test('오늘 환율 하나로 뭉뚱그린 값과 다르다', () {
      // 오늘 환율(1500)로만 계산하면 $30 × 1500 = 45,000.
      // 실제로 빠져나간 42,000 원과 3,000 원 차이다.
      final historical = lifetimeInKrw(
        usdMonthly(),
        rates: rates,
        todayRate: 1500.0,
        asOf: asOf,
      );
      final flat = lifetimeInKrw(
        usdMonthly(),
        rates: null,
        todayRate: 1500.0,
        asOf: asOf,
      );

      expect(flat, const Money(45000));
      expect(historical, isNot(flat));
    });

    test('원화 구독은 환율을 타지 않는다', () {
      expect(
        lifetimeInKrw(
          krwMonthly(),
          rates: rates,
          todayRate: 1500.0,
          asOf: asOf,
        ),
        krwMonthly().totalSpentUntil(asOf),
      );
    });
  });

  group('환율을 아직 못 받아왔을 때', () {
    test('오늘 환율로라도 답한다', () {
      expect(
        lifetimeInKrw(
          usdMonthly(),
          rates: null,
          todayRate: 1500.0,
          asOf: asOf,
        ),
        const Money(45000),
      );
    });

    test('빈 표도 없는 것으로 친다', () {
      expect(
        lifetimeInKrw(
          usdMonthly(),
          rates: RateTable(const {}),
          todayRate: 1500.0,
          asOf: asOf,
        ),
        const Money(45000),
      );
    });

    test('환율을 아예 모르면 답하지 않는다', () {
      // 틀린 숫자를 총액이라고 보여주느니 잠깐 비우는 게 낫다.
      expect(
        lifetimeInKrw(
          usdMonthly(),
          rates: null,
          todayRate: null,
          asOf: asOf,
        ),
        isNull,
      );
    });

    test('원화 구독은 환율을 몰라도 답할 수 있다', () {
      expect(
        lifetimeInKrw(
          krwMonthly(),
          rates: null,
          todayRate: null,
          asOf: asOf,
        ),
        isNotNull,
      );
    });
  });

  group('여러 구독 합계', () {
    test('원화와 달러를 한 숫자로 합친다', () {
      final total = lifetimeTotalInKrw(
        [krwMonthly(), usdMonthly()],
        rates: rates,
        todayRate: 1500.0,
        asOf: asOf,
      );

      expect(total.currency, Money.krw);
      expect(total, krwMonthly().totalSpentUntil(asOf) + const Money(42000));
    });

    test('환산할 수 없는 구독은 빼고 더한다', () {
      // 통째로 0 을 내놓기보다 아는 것만이라도 더한다.
      expect(
        lifetimeTotalInKrw(
          [krwMonthly(), usdMonthly()],
          rates: null,
          todayRate: null,
          asOf: asOf,
        ),
        krwMonthly().totalSpentUntil(asOf),
      );
    });

    test('구독이 없으면 0원이다', () {
      final total = lifetimeTotalInKrw(
        const [],
        rates: rates,
        todayRate: 1500,
        asOf: asOf,
      );
      expect(total.isZero, isTrue);
      expect(total.currency, Money.krw);
    });
  });
}
