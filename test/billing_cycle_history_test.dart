import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';

/// 결제 주기가 중간에 바뀐 구독의 누적 지출.
///
/// 예전엔 주기를 구독당 하나만 들고 있어서, 연간으로 갈아타면 과거 결제까지
/// 연간으로 다시 셌다. 2년간 매달 낸 24번이 3번으로 줄어들어 누적이 통째로
/// 틀어졌다.
void main() {
  group('월간에서 연간으로 갈아탄 구독', () {
    // 2024.01 부터 월 13,500원 → 2026.01 부터 연 162,000원
    final subscription = Subscription.create(
      id: 'netflix',
      name: '넷플릭스',
      // 지금 주기는 연간이다. 예전 코드는 이 값 하나로 과거까지 계산했다.
      cycle: BillingCycle.yearly,
      startedAt: DateTime(2024, 1, 15),
      priceHistory: [
        PricePoint(
          effectiveFrom: DateTime(2024, 1, 15),
          amount: const Money(13500),
          cycle: BillingCycle.monthly,
        ),
        PricePoint(
          effectiveFrom: DateTime(2026, 1, 15),
          amount: const Money(162000),
          cycle: BillingCycle.yearly,
        ),
      ],
    );

    final asOf = DateTime(2026, 8, 30);

    test('그 시절 주기로 결제 횟수를 센다', () {
      // 월간 24번(2024.01~2025.12) + 연간 1번(2026.01)
      expect(subscription.billingDatesUntil(asOf).length, 25);
    });

    test('연간으로 바꾼 뒤로는 해마다 한 번만 센다', () {
      final dates = subscription.billingDatesUntil(asOf);
      final after2026 = dates.where((d) => !d.isBefore(DateTime(2026, 1, 1)));
      expect(after2026.length, 1);
      expect(after2026.single, DateTime(2026, 1, 15));
    });

    test('누적 지출이 실제 낸 돈과 맞는다', () {
      // 24 × 13,500 + 162,000 = 486,000
      expect(subscription.totalSpentUntil(asOf), const Money(486000));
    });

    test('갈아타기 직전까지는 매달 결제된 것으로 본다', () {
      final dates = subscription.billingDatesUntil(asOf);
      final before2026 = dates.where((d) => d.isBefore(DateTime(2026, 1, 1)));
      expect(before2026.length, 24);
    });

    test('시점별로 주기를 되짚을 수 있다', () {
      expect(subscription.cycleAt(DateTime(2024, 6, 1)), BillingCycle.monthly);
      expect(subscription.cycleAt(DateTime(2025, 12, 31)), BillingCycle.monthly);
      expect(subscription.cycleAt(DateTime(2026, 2, 1)), BillingCycle.yearly);
    });
  });

  group('주기가 기록되지 않은 예전 데이터', () {
    // 이 기능이 생기기 전에 저장된 구독에는 PricePoint.cycle 이 없다.
    final legacy = Subscription.create(
      id: 'legacy',
      name: '스포티파이',
      cycle: BillingCycle.monthly,
      startedAt: DateTime(2026, 1, 10),
      priceHistory: [
        PricePoint(
          effectiveFrom: DateTime(2026, 1, 10),
          amount: const Money(10900),
        ),
      ],
    );

    test('구독의 현재 주기를 따른다', () {
      expect(legacy.cycleAt(DateTime(2026, 3, 1)), BillingCycle.monthly);
    });

    test('예전과 똑같이 계산된다', () {
      // 1/10, 2/10, 3/10, 4/10 → 4번
      expect(legacy.billingDatesUntil(DateTime(2026, 4, 30)).length, 4);
      expect(legacy.totalSpentUntil(DateTime(2026, 4, 30)), const Money(43600));
    });

    test('저장했다 불러와도 주기 없음이 유지된다', () {
      final restored = Subscription.fromJson(legacy.toJson());
      expect(restored.priceHistory.single.cycle, isNull);
      expect(restored.cycleAt(DateTime(2026, 3, 1)), BillingCycle.monthly);
    });
  });

  group('연간에서 월간으로 내려온 경우', () {
    // 반대 방향도 틀어진다. 예전 코드는 과거 연간 결제를 매달로 부풀렸다.
    final subscription = Subscription.create(
      id: 'yt',
      name: '유튜브 프리미엄',
      cycle: BillingCycle.monthly,
      startedAt: DateTime(2024, 3, 1),
      priceHistory: [
        PricePoint(
          effectiveFrom: DateTime(2024, 3, 1),
          amount: const Money(129000),
          cycle: BillingCycle.yearly,
        ),
        PricePoint(
          effectiveFrom: DateTime(2026, 3, 1),
          amount: const Money(14900),
          cycle: BillingCycle.monthly,
        ),
      ],
    );

    test('과거 연간 구간은 해마다 한 번만 센다', () {
      final dates = subscription.billingDatesUntil(DateTime(2026, 6, 30));
      final before = dates.where((d) => d.isBefore(DateTime(2026, 3, 1)));
      // 2024.03, 2025.03 두 번
      expect(before.length, 2);
    });

    test('누적이 부풀지 않는다', () {
      // 2024.03 + 2025.03 연간 2번, 2026.03/04/05/06 월간 4번
      expect(
        subscription.totalSpentUntil(DateTime(2026, 6, 30)),
        const Money(129000 * 2 + 14900 * 4),
      );
    });
  });

  group('결제일과 금액을 짝지어 준다', () {
    test('환율을 시점별로 적용하려면 날짜가 필요하다', () {
      final subscription = Subscription.create(
        id: 'usd',
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

      final charges = subscription.chargesUntil(DateTime(2026, 3, 31));
      expect(charges.length, 3);
      expect(charges.first.date, DateTime(2026, 1, 5));
      expect(charges.first.amount, const Money(1000, currency: 'USD'));
    });
  });
}
