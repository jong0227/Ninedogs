import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/providers/insight_providers.dart';
import 'package:ninedogs/providers/subscription_providers.dart';

Subscription sub({
  required String id,
  required String name,
  String? serviceId,
  int price = 13500,
  List<PricePoint>? history,
  DateTime? trialEndsAt,
  DateTime? canceledAt,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? startedAt,
}) {
  return Subscription(
    id: id,
    serviceId: serviceId,
    name: name,
    cycle: cycle,
    startedAt: startedAt ?? DateTime(2020, 1, 1),
    trialEndsAt: trialEndsAt,
    canceledAt: canceledAt,
    priceHistory:
        history ??
        [
          PricePoint(
            effectiveFrom: DateTime(2020, 1, 1),
            amount: Money(price),
          ),
        ],
  );
}

/// insightsProvider 는 allSubscriptionsProvider 를 본다. 그것만 갈아끼운다.
List<Insight> insightsFor(List<Subscription> subscriptions) {
  final container = ProviderContainer(
    overrides: [allSubscriptionsProvider.overrideWithValue(subscriptions)],
  );
  addTearDown(container.dispose);
  return container.read(insightsProvider);
}

void main() {
  group('중복 구독', () {
    test('같은 서비스를 두 건 결제하면 아낄 수 있는 금액을 알려준다', () {
      final insights = insightsFor([
        sub(id: '1', name: '넷플릭스', serviceId: 'netflix', price: 17000),
        sub(id: '2', name: '넷플릭스', serviceId: 'netflix', price: 17000),
      ]);

      final duplicate = insights.firstWhere(
        (i) => i.kind == InsightKind.duplicate,
      );
      expect(duplicate.title, contains('2건'));
      // 싼 쪽 하나만 남기면 나머지가 절약분이다
      expect(duplicate.body, contains('₩17,000'));
    });

    test('요금이 다르면 싼 쪽을 남긴 만큼만 절약으로 센다', () {
      final insights = insightsFor([
        sub(id: '1', name: '넷플릭스', serviceId: 'netflix', price: 17000),
        sub(id: '2', name: '넷플릭스', serviceId: 'netflix', price: 5500),
      ]);

      final duplicate = insights.firstWhere(
        (i) => i.kind == InsightKind.duplicate,
      );
      expect(duplicate.body, contains('₩17,000'));
    });

    test('0원짜리(번들 포함)는 중복으로 보지 않는다', () {
      final insights = insightsFor([
        sub(id: '1', name: '쿠팡플레이', serviceId: 'coupang_play', price: 7890),
        sub(id: '2', name: '쿠팡플레이', serviceId: 'coupang_play', price: 0),
      ]);

      expect(insights.where((i) => i.kind == InsightKind.duplicate), isEmpty);
    });

    test('직접 추가한 구독은 이름으로 묶는다', () {
      final insights = insightsFor([
        sub(id: '1', name: '헬스장'),
        sub(id: '2', name: '헬스장'),
      ]);

      expect(
        insights.where((i) => i.kind == InsightKind.duplicate),
        isNotEmpty,
      );
    });

    test('해지한 구독은 중복이 아니다', () {
      final insights = insightsFor([
        sub(id: '1', name: '넷플릭스', serviceId: 'netflix'),
        sub(
          id: '2',
          name: '넷플릭스',
          serviceId: 'netflix',
          canceledAt: DateTime(2025, 1, 1),
        ),
      ]);

      expect(insights.where((i) => i.kind == InsightKind.duplicate), isEmpty);
    });
  });

  group('가격 인상', () {
    test('처음 금액 대비 오른 비율을 알려준다', () {
      final insights = insightsFor([
        sub(
          id: '1',
          name: '넷플릭스',
          history: [
            PricePoint(
              effectiveFrom: DateTime(2020, 1, 1),
              amount: const Money(13500),
            ),
            PricePoint(
              effectiveFrom: DateTime(2024, 1, 1),
              amount: const Money(17000),
            ),
          ],
        ),
      ]);

      final increase = insights.firstWhere(
        (i) => i.kind == InsightKind.priceIncrease,
      );
      // 13500 -> 17000 은 약 26%
      expect(increase.title, contains('26%'));
    });

    test('가격이 그대로면 알리지 않는다', () {
      final insights = insightsFor([sub(id: '1', name: '넷플릭스')]);
      expect(
        insights.where((i) => i.kind == InsightKind.priceIncrease),
        isEmpty,
      );
    });

    test('내린 경우는 인상으로 보지 않는다', () {
      final insights = insightsFor([
        sub(
          id: '1',
          name: '넷플릭스',
          history: [
            PricePoint(
              effectiveFrom: DateTime(2020, 1, 1),
              amount: const Money(17000),
            ),
            PricePoint(
              effectiveFrom: DateTime(2024, 1, 1),
              amount: const Money(13500),
            ),
          ],
        ),
      ]);

      expect(
        insights.where((i) => i.kind == InsightKind.priceIncrease),
        isEmpty,
      );
    });

    test('5% 미만의 변화는 알릴 것이 못 된다', () {
      final insights = insightsFor([
        sub(
          id: '1',
          name: '넷플릭스',
          history: [
            PricePoint(
              effectiveFrom: DateTime(2020, 1, 1),
              amount: const Money(10000),
            ),
            PricePoint(
              effectiveFrom: DateTime(2024, 1, 1),
              amount: const Money(10300),
            ),
          ],
        ),
      ]);

      expect(
        insights.where((i) => i.kind == InsightKind.priceIncrease),
        isEmpty,
      );
    });
  });

  group('무료 체험', () {
    test('곧 끝나는 체험을 맨 앞에 알린다', () {
      final insights = insightsFor([
        sub(
          id: '1',
          name: '쿠팡플레이',
          startedAt: DateTime.now(),
          trialEndsAt: DateTime.now().add(const Duration(days: 3)),
        ),
      ]);

      expect(insights.first.kind, InsightKind.trialEnding);
      expect(insights.first.title, contains('무료 체험'));
    });

    test('한참 남은 체험은 아직 알리지 않는다', () {
      final insights = insightsFor([
        sub(
          id: '1',
          name: '쿠팡플레이',
          startedAt: DateTime.now(),
          trialEndsAt: DateTime.now().add(const Duration(days: 60)),
        ),
      ]);

      expect(
        insights.where((i) => i.kind == InsightKind.trialEnding),
        isEmpty,
      );
    });
  });

  group('결제일 몰림', () {
    test('같은 날 세 건 이상이면 알린다', () {
      final start = DateTime(2020, 3, 15);
      final insights = insightsFor([
        sub(id: '1', name: 'A', startedAt: start, price: 10000),
        sub(id: '2', name: 'B', startedAt: start, price: 20000),
        sub(id: '3', name: 'C', startedAt: start, price: 30000),
      ]);

      final crowded = insights.firstWhere(
        (i) => i.kind == InsightKind.billingCrowded,
      );
      expect(crowded.title, contains('15일'));
      expect(crowded.body, contains('₩60,000'));
    });

    test('두 건이면 알리지 않는다', () {
      final start = DateTime(2020, 3, 15);
      final insights = insightsFor([
        sub(id: '1', name: 'A', startedAt: start),
        sub(id: '2', name: 'B', startedAt: start),
      ]);

      expect(
        insights.where((i) => i.kind == InsightKind.billingCrowded),
        isEmpty,
      );
    });
  });

  test('아무 문제 없으면 알릴 것도 없다', () {
    expect(insightsFor([sub(id: '1', name: '넷플릭스')]), isEmpty);
  });
}
