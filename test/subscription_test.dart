import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';

Subscription build({
  required DateTime startedAt,
  required List<PricePoint> prices,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? canceledAt,
  DateTime? trialEndsAt,
}) {
  return Subscription(
    id: 'test',
    name: '넷플릭스',
    cycle: cycle,
    startedAt: startedAt,
    priceHistory: prices,
    canceledAt: canceledAt,
    trialEndsAt: trialEndsAt,
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

  group('무료 체험', () {
    // 체험 기간에는 돈이 나가지 않는다. 시작일을 청구 기준으로 삼으면
    // 체험 중에도 결제한 것으로 잡혀 누적 지출이 부풀려진다.
    final prices = [
      PricePoint(
        effectiveFrom: DateTime(2020, 1, 1),
        amount: const Money(13500),
      ),
    ];

    test('체험 중에는 누적 지출이 0원이다', () {
      final subscription = build(
        startedAt: DateTime(2026, 7, 1),
        trialEndsAt: DateTime(2026, 8, 1),
        prices: prices,
      );

      expect(
        subscription.totalSpentUntil(DateTime(2026, 7, 20)),
        Money.zero(),
      );
    });

    test('첫 결제는 체험이 끝나는 날에 일어난다', () {
      final subscription = build(
        startedAt: DateTime(2026, 7, 1),
        trialEndsAt: DateTime(2026, 8, 1),
        prices: prices,
      );

      expect(
        subscription.billingDatesUntil(DateTime(2026, 8, 1)),
        [DateTime(2026, 8, 1)],
      );
      expect(
        subscription.totalSpentUntil(DateTime(2026, 8, 1)),
        const Money(13500),
      );
    });

    test('체험이 끝난 뒤에는 그 날부터 주기가 돈다', () {
      final subscription = build(
        startedAt: DateTime(2026, 7, 10),
        trialEndsAt: DateTime(2026, 8, 10),
        prices: prices,
      );

      // 8/10, 9/10, 10/10 세 번
      expect(
        subscription.totalSpentUntil(DateTime(2026, 10, 15)),
        const Money(13500 * 3),
      );
    });

    test('체험 없이 등록하면 시작일부터 청구된다', () {
      final subscription = build(
        startedAt: DateTime(2026, 7, 1),
        prices: prices,
      );

      expect(
        subscription.totalSpentUntil(DateTime(2026, 7, 20)),
        const Money(13500),
      );
    });

    test('직접 지정한 결제일이 체험 종료일보다 우선한다', () {
      final subscription = Subscription(
        id: 'test',
        name: '넷플릭스',
        cycle: BillingCycle.monthly,
        startedAt: DateTime(2026, 7, 1),
        trialEndsAt: DateTime(2026, 8, 1),
        billingAnchor: DateTime(2026, 8, 15),
        priceHistory: prices,
      );

      expect(
        subscription.billingDatesUntil(DateTime(2026, 8, 20)),
        [DateTime(2026, 8, 15)],
      );
    });

    test('JSON 으로 왕복해도 체험 종료일이 남는다', () {
      final original = build(
        startedAt: DateTime(2026, 7, 1),
        trialEndsAt: DateTime(2026, 8, 1),
        prices: prices,
      );

      final restored = Subscription.fromJson(original.toJson());
      expect(restored.trialEndsAt, DateTime(2026, 8, 1));
    });

    test('clearTrial 로 체험 정보를 지울 수 있다', () {
      final subscription = build(
        startedAt: DateTime(2026, 7, 1),
        trialEndsAt: DateTime(2026, 8, 1),
        prices: prices,
      );

      expect(subscription.copyWith(clearTrial: true).trialEndsAt, isNull);
    });
  });

  group('끊었다 다시 구독한 구간', () {
    // 1~3월 구독(10,000원) -> 끊음 -> 7월부터 다시(13,500원)
    Subscription onOff() => Subscription(
      id: 'test',
      name: '넷플릭스',
      cycle: BillingCycle.monthly,
      pastPeriods: [
        SubscriptionPeriod(
          startedAt: DateTime(2026, 1, 1),
          endedAt: DateTime(2026, 3, 20),
        ),
      ],
      startedAt: DateTime(2026, 7, 1),
      priceHistory: [
        PricePoint(
          effectiveFrom: DateTime(2026, 1, 1),
          amount: const Money(10000),
        ),
        PricePoint(
          effectiveFrom: DateTime(2026, 7, 1),
          amount: const Money(13500),
        ),
      ],
    );

    test('안 쓰던 기간에는 결제가 잡히지 않는다', () {
      final dates = onOff().billingDatesUntil(DateTime(2026, 9, 15));

      // 1/1, 2/1, 3/1 (3/20 해지) 그리고 7/1, 8/1, 9/1
      expect(dates, [
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
        DateTime(2026, 7, 1),
        DateTime(2026, 8, 1),
        DateTime(2026, 9, 1),
      ]);
      // 4,5,6월은 구독하지 않았으므로 빠져야 한다
      expect(dates, isNot(contains(DateTime(2026, 4, 1))));
    });

    test('구간마다 그때의 요금으로 누적 지출을 계산한다', () {
      // 1~3월 10,000 x 3 + 7~9월 13,500 x 3
      expect(
        onOff().totalSpentUntil(DateTime(2026, 9, 15)),
        const Money(10000 * 3 + 13500 * 3),
      );
    });

    test('맨 처음 구독한 날과 지금 구간 시작일을 구분한다', () {
      final subscription = onOff();
      expect(subscription.firstStartedAt, DateTime(2026, 1, 1));
      expect(subscription.startedAt, DateTime(2026, 7, 1));
      expect(subscription.periodCount, 2);
    });

    test('안 쓰던 달의 캘린더에는 결제가 없다', () {
      final subscription = onOff();
      expect(
        subscription.billingDatesBetween(
          DateTime(2026, 5, 1),
          DateTime(2026, 5, 31),
        ),
        isEmpty,
      );
      expect(
        subscription.billingDatesBetween(
          DateTime(2026, 2, 1),
          DateTime(2026, 2, 28),
        ),
        [DateTime(2026, 2, 1)],
      );
    });

    test('구간이 하나뿐이면 예전과 똑같이 동작한다', () {
      final single = build(
        startedAt: DateTime(2026, 1, 1),
        prices: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 1),
            amount: const Money(10000),
          ),
        ],
      );

      expect(single.periodCount, 1);
      expect(single.firstStartedAt, single.startedAt);
      expect(
        single.totalSpentUntil(DateTime(2026, 3, 15)),
        const Money(30000),
      );
    });

    test('JSON 으로 왕복해도 구간이 유지된다', () {
      final restored = Subscription.fromJson(onOff().toJson());

      expect(restored.pastPeriods.length, 1);
      expect(restored.pastPeriods.single.startedAt, DateTime(2026, 1, 1));
      expect(restored.pastPeriods.single.endedAt, DateTime(2026, 3, 20));
      expect(restored.startedAt, DateTime(2026, 7, 1));
    });

    test('이 필드가 없던 예전 데이터도 그대로 읽힌다', () {
      final legacy = {
        'id': 'old',
        'name': '넷플릭스',
        'cycle': 'monthly',
        'startedAt': DateTime(2026, 1, 1).toIso8601String(),
        'priceHistory': [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 1),
            amount: const Money(10000),
          ).toJson(),
        ],
      };

      final restored = Subscription.fromJson(legacy);
      expect(restored.pastPeriods, isEmpty);
      expect(restored.periodCount, 1);
      expect(
        restored.totalSpentUntil(DateTime(2026, 3, 15)),
        const Money(30000),
      );
    });
  });
}
