import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/catalog/catalog_service.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/data/repository/subscription_repository.dart';
import 'package:ninedogs/providers/app_providers.dart';
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

  @override
  Stream<List<Subscription>>? watch() => null;
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

ProviderContainer containerWith(
  List<Subscription> subscriptions, {
  double? usdToKrwRate,
}) => ProviderContainer.test(
  overrides: [
    subscriptionRepositoryProvider.overrideWithValue(
      FakeRepository(subscriptions),
    ),
    // 실제 환율 API를 부르지 않도록 고정값으로 대신한다. 지정하지 않으면
    // 이 provider 는 계속 로딩 상태로 남는데, 원화 전용 테스트는 환율을
    // 아예 안 보므로 상관없다.
    if (usdToKrwRate != null)
      exchangeRateProvider.overrideWith((ref) async => usdToKrwRate),
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

  test('통화가 섞이면 환율로 원화 환산해서 하나로 합친다', () async {
    // 예전엔 "가장 많이 쓰는 통화"만 남기고 나머지 통화는 통째로 뺐다.
    // 지금은 환율로 전부 원화로 바꿔서 합친다.
    final container = containerWith(
      [
        sub('netflix', 'netflix', 13500),
        sub('spotify', 'spotify', 10900),
        sub('chatgpt', 'chatgpt', 2000, currency: 'USD'), // $20
      ],
      usdToKrwRate: 1400,
    );
    await container.read(subscriptionsProvider.future);
    await container.read(exchangeRateProvider.future);

    final total = container.read(categoryTotalProvider);
    expect(total.currency, Money.krw);
    // 13500 + 10900 + (20 * 1400 = 28000) = 52400
    expect(total, const Money(52400));
  });

  test('달러 하나뿐이어도 분야 목록·개수에서 빠지지 않는다', () async {
    // 실제로 있었던 버그: 원화 구독 없이 달러 구독 하나만 있으면
    // "가장 많이 쓰는 통화"가 USD 가 되므로 우연히 통과했었지만,
    // 원화 구독과 섞이면 그 즉시 사라졌었다.
    final container = containerWith(
      [
        sub('netflix', 'netflix', 13500),
        sub('chatgpt', 'chatgpt', 2000, currency: 'USD'),
      ],
      usdToKrwRate: 1400,
    );
    await container.read(subscriptionsProvider.future);
    await container.read(exchangeRateProvider.future);

    final spends = container.read(categorySpendProvider);
    final totalCount = spends.fold(0, (sum, s) => sum + s.count);
    expect(totalCount, 2, reason: '달러 구독도 분야 목록에 보여야 한다');

    final productivity = spends.firstWhere(
      (s) => s.category == ServiceCategory.productivity,
    );
    expect(productivity.monthly, const Money(28000));
  });

  test('환율을 아직 못 받아왔으면 달러 항목은 합계에서만 빠진다', () async {
    // exchangeRateProvider 를 오버라이드하지 않으면 로딩 상태로 남는다.
    // 그래도 목록에는 보여야 한다 — 안 보이는 것보다 0원으로 합산에서
    // 빠지는 편이 낫다.
    final container = containerWith([
      sub('netflix', 'netflix', 13500),
      sub('chatgpt', 'chatgpt', 2000, currency: 'USD'),
    ]);
    await container.read(subscriptionsProvider.future);

    final spends = container.read(categorySpendProvider);
    final totalCount = spends.fold(0, (sum, s) => sum + s.count);
    expect(totalCount, 2);

    final productivity = spends.firstWhere(
      (s) => s.category == ServiceCategory.productivity,
    );
    expect(productivity.monthly, Money.zero());
  });

  test('구독이 없으면 빈 목록이다', () async {
    final container = containerWith([]);
    await container.read(subscriptionsProvider.future);

    expect(container.read(categorySpendProvider), isEmpty);
    expect(container.read(categoryTotalProvider), Money.zero());
  });
}
