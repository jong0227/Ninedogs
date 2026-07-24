import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/data/repository/subscription_repository.dart';
import 'package:ninedogs/providers/subscription_providers.dart';

class FakeRepository implements SubscriptionRepository {
  FakeRepository([this.stored = const []]);

  List<Subscription> stored;
  int saveCount = 0;

  @override
  Future<List<Subscription>> load() async => stored;

  @override
  Future<void> save(List<Subscription> subscriptions) async {
    stored = subscriptions;
    saveCount++;
  }
}

Subscription netflix() => Subscription(
  id: 'netflix-1',
  name: '넷플릭스',
  cycle: BillingCycle.monthly,
  startedAt: DateTime(2026, 1, 1),
  priceHistory: [
    PricePoint(effectiveFrom: DateTime(2026, 1, 1), amount: const Money(10000)),
  ],
);

void main() {
  late FakeRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeRepository([netflix()]);
    container = ProviderContainer.test(
      overrides: [subscriptionRepositoryProvider.overrideWithValue(repository)],
    );
  });

  Future<SubscriptionsNotifier> notifier() async {
    await container.read(subscriptionsProvider.future);
    return container.read(subscriptionsProvider.notifier);
  }

  Subscription current() => container.read(allSubscriptionsProvider).single;

  test('저장소에서 불러온다', () async {
    await container.read(subscriptionsProvider.future);
    expect(container.read(allSubscriptionsProvider).length, 1);
  });

  test('요금 인상은 이력에 쌓이고 이전 결제는 옛 금액으로 남는다', () async {
    final subject = await notifier();
    await subject.recordPriceChange(
      'netflix-1',
      const Money(12000),
      effectiveFrom: DateTime(2026, 4, 1),
    );

    final updated = current();
    expect(updated.priceHistory.length, 2);
    expect(updated.priceAt(DateTime(2026, 2, 1)), const Money(10000));
    expect(updated.priceAt(DateTime(2026, 5, 1)), const Money(12000));

    // 1~3월 @10,000 + 4~6월 @12,000
    expect(updated.totalSpentUntil(DateTime(2026, 6, 15)), const Money(66000));
  });

  test('오타 정정은 이력을 늘리지 않고 누적 지출을 다시 계산한다', () async {
    final subject = await notifier();
    await subject.correctLatestPrice('netflix-1', const Money(13500));

    final updated = current();
    expect(updated.priceHistory.length, 1);

    // 처음부터 13,500원이었던 것으로 6개월치 재계산
    expect(updated.totalSpentUntil(DateTime(2026, 6, 15)), const Money(81000));
  });

  test('해지하면 구독 중 목록에서 빠지고 기록은 남는다', () async {
    final subject = await notifier();
    await subject.cancel('netflix-1');

    expect(container.read(activeSubscriptionsProvider), isEmpty);
    expect(container.read(canceledSubscriptionsProvider).length, 1);
    expect(container.read(allSubscriptionsProvider).length, 1);
  });

  test('삭제하면 완전히 사라지고 저장소에도 반영된다', () async {
    final subject = await notifier();
    await subject.remove('netflix-1');

    expect(container.read(allSubscriptionsProvider), isEmpty);
    expect(repository.stored, isEmpty);
    expect(repository.saveCount, 1);
  });

  test('월 합계는 주기가 다른 구독을 월 환산해서 더한다', () async {
    final subject = await notifier();
    await subject.add(
      Subscription(
        id: 'millie-1',
        name: '밀리의서재',
        cycle: BillingCycle.yearly,
        startedAt: DateTime(2026, 1, 1),
        priceHistory: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 1),
            amount: const Money(120000),
          ),
        ],
      ),
    );

    // 월 10,000 + 연 120,000(월 환산 10,000) = 20,000
    expect(container.read(monthlyTotalProvider)['KRW'], const Money(20000));
  });

  test('통화가 섞이면 통화별로 나눠서 합산한다', () async {
    final subject = await notifier();
    await subject.add(
      Subscription(
        id: 'chatgpt-1',
        name: 'ChatGPT',
        cycle: BillingCycle.monthly,
        startedAt: DateTime(2026, 1, 1),
        priceHistory: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 1),
            amount: const Money(2000, currency: 'USD'),
          ),
        ],
      ),
    );

    final totals = container.read(monthlyTotalProvider);
    expect(totals['KRW'], const Money(10000));
    expect(totals['USD'], const Money(2000, currency: 'USD'));
  });
}
