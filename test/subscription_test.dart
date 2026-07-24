import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';

Subscription build({
  required DateTime startedAt,
  required List<PricePoint> prices,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? canceledAt,
}) {
  return Subscription(
    id: 'test',
    name: '넷플릭스',
    cycle: cycle,
    startedAt: startedAt,
    priceHistory: prices,
    canceledAt: canceledAt,
  );
}

void main() {
  group('누적 지출', () {
    test('시작일부터 오늘까지의 결제 횟수만큼 합산한다', () {
      final subscription = build(
        startedAt: DateTime(2026, 1, 1),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 1),
            amount: const Money(13500),
          ),
        ],
      );

      // 1/1 ~ 6/15 사이에 1,2,3,4,5,6월 = 6번 결제
      expect(subscription.billingDatesUntil(DateTime(2026, 6, 15)).length, 6);
      expect(
        subscription.totalSpentUntil(DateTime(2026, 6, 15)),
        const Money(81000),
      );
    });

    test('가격이 오르면 오른 시점 이후 결제부터 새 금액을 쓴다', () {
      final subscription = build(
        startedAt: DateTime(2026, 1, 1),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 1),
            amount: const Money(10000),
          ),
          PricePoint(
            effectiveFrom: DateTime(2026, 4, 1),
            amount: const Money(12000),
          ),
        ],
      );

      // 1,2,3월 @10,000 + 4,5,6월 @12,000
      expect(
        subscription.totalSpentUntil(DateTime(2026, 6, 15)),
        const Money(66000),
      );
    });

    test('해지한 뒤로는 더 청구되지 않는다', () {
      final subscription = build(
        startedAt: DateTime(2026, 1, 1),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 1),
            amount: const Money(10000),
          ),
        ],
        canceledAt: DateTime(2026, 3, 10),
      );

      // 1,2,3월 = 3번에서 멈춘다
      expect(
        subscription.totalSpentUntil(DateTime(2026, 12, 31)),
        const Money(30000),
      );
    });

    test('연간 구독은 1년에 한 번만 청구된다', () {
      final subscription = build(
        startedAt: DateTime(2024, 5, 1),
        cycle: BillingCycle.yearly,
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2024, 5, 1),
            amount: const Money(99000),
          ),
        ],
      );

      // 2024/5, 2025/5, 2026/5 = 3번
      expect(
        subscription.totalSpentUntil(DateTime(2026, 7, 24)),
        const Money(297000),
      );
    });
  });

  group('가격 조회', () {
    final subscription = build(
      startedAt: DateTime(2026, 1, 1),
      prices: [
        PricePoint(
          effectiveFrom: DateTime(2026, 1, 1),
          amount: const Money(10000),
        ),
        PricePoint(
          effectiveFrom: DateTime(2026, 4, 1),
          amount: const Money(12000),
        ),
      ],
    );

    test('시점에 맞는 가격을 돌려준다', () {
      expect(subscription.priceAt(DateTime(2026, 2, 1)), const Money(10000));
      expect(subscription.priceAt(DateTime(2026, 4, 1)), const Money(12000));
      expect(subscription.priceAt(DateTime(2026, 9, 1)), const Money(12000));
    });

    test('가격 변동 목록에는 최초 등록가가 빠진다', () {
      expect(subscription.priceChanges.length, 1);
      expect(subscription.priceChanges.first.amount, const Money(12000));
    });
  });

  group('결제일', () {
    test('다음 결제일은 기준 시점 이후 첫 청구일이다', () {
      final subscription = build(
        startedAt: DateTime(2026, 1, 15),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 15),
            amount: const Money(10000),
          ),
        ],
      );

      expect(
        subscription.nextBillingDate(DateTime(2026, 7, 24)),
        DateTime(2026, 8, 15),
      );
    });

    test('해지한 구독은 다음 결제일이 없다', () {
      final subscription = build(
        startedAt: DateTime(2026, 1, 15),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 15),
            amount: const Money(10000),
          ),
        ],
        canceledAt: DateTime(2026, 3, 1),
      );

      expect(subscription.nextBillingDate(DateTime(2026, 7, 24)), isNull);
    });
  });

  group('기간 내 결제일', () {
    test('그 달에 걸린 결제일만 돌려준다', () {
      final subscription = build(
        startedAt: DateTime(2026, 1, 15),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 15),
            amount: const Money(10000),
          ),
        ],
      );

      final july = subscription.billingDatesBetween(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31),
      );
      expect(july, [DateTime(2026, 7, 15)]);
    });

    test('시작 전 달에는 결제일이 없다', () {
      final subscription = build(
        startedAt: DateTime(2026, 7, 15),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 7, 15),
            amount: const Money(10000),
          ),
        ],
      );

      expect(
        subscription.billingDatesBetween(
          DateTime(2026, 6, 1),
          DateTime(2026, 6, 30),
        ),
        isEmpty,
      );
    });

    test('해지한 뒤 달에는 결제일이 없다', () {
      final subscription = build(
        startedAt: DateTime(2026, 1, 15),
        canceledAt: DateTime(2026, 3, 20),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 15),
            amount: const Money(10000),
          ),
        ],
      );

      expect(
        subscription.billingDatesBetween(
          DateTime(2026, 5, 1),
          DateTime(2026, 5, 31),
        ),
        isEmpty,
      );
    });

    test('주간 구독은 한 달에 네다섯 번 걸린다', () {
      final subscription = build(
        startedAt: DateTime(2026, 7, 1),
        cycle: BillingCycle.weekly,
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 7, 1),
            amount: const Money(3000),
          ),
        ],
      );

      final july = subscription.billingDatesBetween(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31),
      );
      expect(july.length, 5); // 1, 8, 15, 22, 29
    });
  });

  group('알림 설정', () {
    Subscription withReminders(List<int>? days) => Subscription(
      id: 'r',
      name: '넷플릭스',
      cycle: BillingCycle.monthly,
      startedAt: DateTime(2026, 1, 1),
      reminderDaysBefore: days,
      priceHistory: [
        PricePoint(
          effectiveFrom: DateTime(2026, 1, 1),
          amount: const Money(13500),
        ),
      ],
    );

    test('따로 정하지 않았으면 전체 설정을 따른다', () {
      expect(withReminders(null).effectiveReminderDays([3]), [3]);
    });

    test('따로 정했으면 그 값을 쓴다', () {
      expect(withReminders([7, 1]).effectiveReminderDays([3]), [7, 1]);
    });

    test('빈 목록은 이 구독만 알림을 끈 것이다', () {
      // null(전체 따름)과 빈 목록(끔)은 다른 뜻이어야 한다
      expect(withReminders([]).effectiveReminderDays([3]), isEmpty);
    });

    test('JSON 으로 왕복해도 유지된다', () {
      expect(
        Subscription.fromJson(withReminders([7, 1]).toJson())
            .reminderDaysBefore,
        [7, 1],
      );
      expect(
        Subscription.fromJson(withReminders(null).toJson()).reminderDaysBefore,
        isNull,
      );
      expect(
        Subscription.fromJson(withReminders([]).toJson()).reminderDaysBefore,
        isEmpty,
      );
    });

    test('copyWith 로 전체 설정 따르기로 되돌릴 수 있다', () {
      final custom = withReminders([7]);
      expect(custom.copyWith(clearReminders: true).reminderDaysBefore, isNull);
    });
  });

  test('JSON 으로 왕복해도 값이 유지된다', () {
    final original = Subscription(
      id: 'abc',
      serviceId: 'netflix',
      name: '넷플릭스',
      cycle: BillingCycle.monthly,
      startedAt: DateTime(2026, 1, 1),
      priceHistory: [
        PricePoint(
          effectiveFrom: DateTime(2026, 1, 1),
          amount: const Money(13500),
        ),
      ],
      paymentMethod: '신한카드 1234',
      brandColorValue: 0xFFE50914,
    );

    final restored = Subscription.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.serviceId, original.serviceId);
    expect(restored.startedAt, original.startedAt);
    expect(restored.currentPrice, original.currentPrice);
    expect(restored.paymentMethod, original.paymentMethod);
    expect(restored.brandColorValue, original.brandColorValue);
  });
}
