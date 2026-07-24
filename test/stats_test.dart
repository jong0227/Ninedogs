import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/catalog/catalog_service.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/data/repository/subscription_repository.dart';
import 'package:ninedogs/providers/stats_providers.dart';
import 'package:ninedogs/providers/subscription_providers.dart';

class FakeRepository implements SubscriptionRepository {
  FakeRepository(this.stored);
  List<Subscription> stored;

  @override
  Future<List<Subscription>> load() async => stored;

  @override
  Future<void> save(List<Subscription> subscriptions) async =>
      stored = subscriptions;
}

Subscription sub(
  String id,
  String? serviceId,
  int priceKrw, {
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? canceledAt,
  String currency = Money.krw,
}) {
  final start = DateTime(2026, 1, 1);
  return Subscription(
    id: id,
    serviceId: serviceId,
    name: id,
    cycle: cycle,
    startedAt: start,
    canceledAt: canceledAt,
    priceHistory: [
      PricePoint(
        effectiveFrom: start,
        amount: Money(priceKrw, currency: currency),
      ),
    ],
  );
}

ProviderContainer containerWith(List<Subscription> subscriptions) =>
    ProviderContainer.test(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(
          FakeRepository(subscriptions),
        ),
      ],
    );

void main() {
  test('분야별로 묶고 월 지출이 큰 순서로 정렬한다', () async {
    final container = containerWith([
      sub('netflix', 'netflix', 13500), // 영상
      sub('tving', 'tving', 13500), // 영상
      sub('spotify', 'spotify', 10900), // 음악
    ]);
    await container.read(subscriptionsProvider.future);

    final spends = container.read(categorySpendProvider);

    expect(spends.first.category, ServiceCategory.video);
    expect(spends.first.monthly, const Money(27000));
    expect(spends.first.count, 2);

    expect(spends[1].category, ServiceCategory.music);
    expect(spends[1].monthly, const Money(10900));
  });

  test('연간 구독도 월 환산해서 합산한다', () async {
    final container = containerWith([
      sub('millie', 'millie', 120000, cycle: BillingCycle.yearly), // 독서
    ]);
    await container.read(subscriptionsProvider.future);

    expect(
      container.read(categorySpendProvider).single.monthly,
      const Money(10000),
    );
  });

  test('카탈로그에 없는 구독은 기타로 묶는다', () async {
    final container = containerWith([sub('직접입력', null, 5000)]);
    await container.read(subscriptionsProvider.future);

    final spend = container.read(categorySpendProvider).single;
    expect(spend.category, isNull);
    expect(spend.label, '기타');
  });

  test('해지한 구독은 분석에서 빠진다', () async {
    final container = containerWith([
      sub('netflix', 'netflix', 13500),
      sub('watcha', 'watcha', 7900, canceledAt: DateTime(2026, 3, 1)),
    ]);
    await container.read(subscriptionsProvider.future);

    final spends = container.read(categorySpendProvider);
    expect(spends.single.count, 1);
    expect(spends.single.monthly, const Money(13500));
  });

  test('총합은 분야 합계와 같다', () async {
    final container = containerWith([
      sub('netflix', 'netflix', 13500),
      sub('spotify', 'spotify', 10900),
      sub('notion', 'notion', 14000),
    ]);
    await container.read(subscriptionsProvider.future);

    expect(container.read(categoryTotalProvider), const Money(38400));
  });

  test('통화가 섞이면 많이 쓰는 통화만 집계한다', () async {
    // 비중(%)은 같은 통화끼리만 의미가 있다
    final container = containerWith([
      sub('netflix', 'netflix', 13500),
      sub('spotify', 'spotify', 10900),
      sub('chatgpt', 'chatgpt', 2000, currency: 'USD'),
    ]);
    await container.read(subscriptionsProvider.future);

    final total = container.read(categoryTotalProvider);
    expect(total.currency, Money.krw);
    expect(total, const Money(24400));
  });

  test('구독이 없으면 빈 목록이다', () async {
    final container = containerWith([]);
    await container.read(subscriptionsProvider.future);

    expect(container.read(categorySpendProvider), isEmpty);
    expect(container.read(categoryTotalProvider), Money.zero());
  });
}
