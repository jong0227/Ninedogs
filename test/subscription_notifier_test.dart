import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/data/repository/subscription_repository.dart';
import 'package:ninedogs/providers/app_providers.dart';
import 'package:ninedogs/providers/subscription_providers.dart';

class FakeRepository implements SubscriptionRepository {
  FakeRepository([this.stored = const []]);

  List<Subscription> stored;
  int saveCount = 0;

  /// 불러오기를 일부러 늦춰서 실제 기기의 순서를 재현할 때 쓴다.
  Duration loadDelay = Duration.zero;

  @override
  Future<List<Subscription>> load() async {
    if (loadDelay > Duration.zero) await Future<void>.delayed(loadDelay);
    return stored;
  }

  @override
  Future<void> save(List<Subscription> subscriptions) async {
    stored = subscriptions;
    saveCount++;
  }

  @override
  Stream<List<Subscription>>? watch() => null;
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

  test('불러오기가 끝나기 전에 추가해도 사라지지 않는다', () async {
    // 온보딩에서 실제로 이 순서가 된다. 구독 목록을 아무도 보지 않은 채로
    // 추가하면, 뒤늦게 끝난 build 결과가 방금 넣은 구독을 덮어썼다.
    repository.loadDelay = const Duration(milliseconds: 40);

    final subject = container.read(subscriptionsProvider.notifier);
    await subject.addAll([
      Subscription(
        id: 'spotify-1',
        name: '스포티파이',
        cycle: BillingCycle.monthly,
        startedAt: DateTime(2026, 1, 1),
        priceHistory: [
          PricePoint(
            effectiveFrom: DateTime(2026, 1, 1),
            amount: const Money(10900),
          ),
        ],
      ),
    ]);

    await container.read(subscriptionsProvider.future);

    expect(container.read(allSubscriptionsProvider).length, 2);
    expect(repository.stored.length, 2);
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

  group('원화 통합 합계', () {
    test('환율이 있으면 통화가 섞여도 하나의 원화 숫자로 합쳐진다', () async {
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
              amount: const Money(2000, currency: 'USD'), // $20
            ),
          ],
        ),
      );

      final krwContainer = ProviderContainer.test(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
          exchangeRateProvider.overrideWith((ref) async => 1400),
        ],
      );
      addTearDown(krwContainer.dispose);
      await krwContainer.read(subscriptionsProvider.future);
      await krwContainer.read(exchangeRateProvider.future);

      // 10,000(넷플릭스) + 20*1400=28,000(ChatGPT) = 38,000
      expect(
        krwContainer.read(monthlyTotalKrwProvider),
        const Money(38000),
      );
    });

    test('환율을 못 받아왔으면 null 이라 화면이 통화별 표시로 돌아간다', () async {
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

      // exchangeRateProvider 를 오버라이드하지 않으면 로딩 상태로 남는다.
      expect(container.read(monthlyTotalKrwProvider), isNull);
    });
  });

  group('다시 구독', () {
    test('끊었던 구간이 이력으로 넘어가고 새 구간이 열린다', () async {
      final subject = await notifier();
      await subject.cancel('netflix-1');

      await subject.resubscribe(
        'netflix-1',
        startedAt: DateTime(2026, 7, 1),
        price: const Money(13500),
      );

      final updated = current();
      expect(updated.isActive, isTrue);
      expect(updated.periodCount, 2);
      expect(updated.startedAt, DateTime(2026, 7, 1));
      expect(updated.firstStartedAt, DateTime(2026, 1, 1));
      expect(updated.currentPrice, const Money(13500));
    });

    test('안 쓰던 기간은 누적 지출에서 빠진다', () async {
      final subject = await notifier();
      // 3/20 에 끊은 것으로 만든다
      await subject.replace(
        current().copyWith(canceledAt: DateTime(2026, 3, 20)),
      );
      await subject.resubscribe(
        'netflix-1',
        startedAt: DateTime(2026, 7, 1),
        price: const Money(13500),
      );

      // 1,2,3월 10,000 + 7,8,9월 13,500. 4~6월은 없다.
      expect(
        current().totalSpentUntil(DateTime(2026, 9, 15)),
        const Money(10000 * 3 + 13500 * 3),
      );
    });

    test('금액을 안 주면 예전 요금 그대로 이어간다', () async {
      final subject = await notifier();
      await subject.cancel('netflix-1');

      await subject.resubscribe('netflix-1', startedAt: DateTime(2026, 7, 1));

      expect(current().currentPrice, const Money(10000));
      expect(current().priceHistory.length, 1);
    });

    test('구독 중인 것에는 아무 일도 일어나지 않는다', () async {
      final subject = await notifier();

      await subject.resubscribe('netflix-1', startedAt: DateTime(2026, 7, 1));

      expect(current().periodCount, 1);
      expect(current().startedAt, DateTime(2026, 1, 1));
    });
  });

  group('구독 이력 직접 편집', () {
    test('구간을 추가하면 가장 늦게 시작한 것이 지금 구간이 된다', () async {
      final subject = await notifier();

      await subject.setPeriods('netflix-1', [
        (startedAt: DateTime(2025, 1, 1), endedAt: DateTime(2025, 5, 1)),
        (startedAt: DateTime(2026, 1, 1), endedAt: null),
      ]);

      final updated = current();
      expect(updated.periodCount, 2);
      expect(updated.startedAt, DateTime(2026, 1, 1));
      expect(updated.isActive, isTrue);
      expect(updated.pastPeriods.single.startedAt, DateTime(2025, 1, 1));
    });

    test('잘못 넣은 구간을 빼면 원래대로 돌아간다', () async {
      final subject = await notifier();
      await subject.setPeriods('netflix-1', [
        (startedAt: DateTime(2025, 1, 1), endedAt: DateTime(2025, 5, 1)),
        (startedAt: DateTime(2026, 1, 1), endedAt: null),
      ]);
      expect(current().periodCount, 2);

      // 실수로 넣은 2025 구간만 빼고 다시 넣는다
      await subject.setPeriods('netflix-1', [
        (startedAt: DateTime(2026, 1, 1), endedAt: null),
      ]);

      final updated = current();
      expect(updated.periodCount, 1);
      expect(updated.pastPeriods, isEmpty);
      expect(updated.startedAt, DateTime(2026, 1, 1));
      expect(updated.isActive, isTrue);
    });

    test('지금 구간을 끝난 것으로 바꾸면 해지 상태가 된다', () async {
      final subject = await notifier();

      await subject.setPeriods('netflix-1', [
        (startedAt: DateTime(2026, 1, 1), endedAt: DateTime(2026, 6, 1)),
      ]);

      final updated = current();
      expect(updated.isActive, isFalse);
      expect(updated.canceledAt, DateTime(2026, 6, 1));
    });

    test('해지 상태에서 끝을 지우면 다시 구독 중이 된다', () async {
      final subject = await notifier();
      await subject.cancel('netflix-1');
      expect(current().isActive, isFalse);

      await subject.setPeriods('netflix-1', [
        (startedAt: DateTime(2026, 1, 1), endedAt: null),
      ]);

      expect(current().isActive, isTrue);
      expect(current().canceledAt, isNull);
    });

    test('빈 목록을 주면 아무것도 바꾸지 않는다', () async {
      final subject = await notifier();

      await subject.setPeriods('netflix-1', []);

      // 구간이 하나도 없는 구독은 있을 수 없다
      expect(current().periodCount, 1);
      expect(current().startedAt, DateTime(2026, 1, 1));
    });

    test('끝나지 않은 구간이 여럿이면 가장 늦은 것만 남는다', () async {
      final subject = await notifier();

      await subject.setPeriods('netflix-1', [
        (startedAt: DateTime(2025, 1, 1), endedAt: null), // 앞선 열린 구간
        (startedAt: DateTime(2026, 1, 1), endedAt: null),
      ]);

      final updated = current();
      // 앞선 열린 구간은 뒤 구간과 겹치므로 버려진다
      expect(updated.periodCount, 1);
      expect(updated.startedAt, DateTime(2026, 1, 1));
    });
  });

  group('가격 이력 직접 편집', () {
    test('과거 시점에 없던 항목을 추가하면 이력에 끼워 들어간다', () async {
      final subject = await notifier();

      await subject.upsertPriceHistoryPoint(
        'netflix-1',
        PricePoint(
          effectiveFrom: DateTime(2026, 6, 1),
          amount: const Money(13500),
        ),
      );

      final history = current().priceHistory;
      expect(history.length, 2);
      expect(history[0].amount, const Money(10000)); // 1월부터
      expect(history[1].amount, const Money(13500)); // 6월부터
    });

    test('같은 날짜에 다시 넣으면 그 항목을 덮어쓴다', () async {
      final subject = await notifier();

      await subject.upsertPriceHistoryPoint(
        'netflix-1',
        PricePoint(
          effectiveFrom: DateTime(2026, 1, 1), // 시작일과 같은 날
          amount: const Money(9900),
        ),
      );

      final history = current().priceHistory;
      expect(history.length, 1);
      expect(history.single.amount, const Money(9900));
    });

    test('중간에 끼워 넣은 과거 시점이 누적 지출 계산에 반영된다', () async {
      final subject = await notifier();
      // 원래: 1월부터 10,000원. 실제로는 4월부터 13,500원으로 올랐다고 뒤늦게 기록.
      await subject.upsertPriceHistoryPoint(
        'netflix-1',
        PricePoint(
          effectiveFrom: DateTime(2026, 4, 1),
          amount: const Money(13500),
        ),
      );

      final updated = current();
      // 1,2,3월은 10,000원씩, 4,5,6월은 13,500원씩
      final total = updated.totalSpentUntil(DateTime(2026, 6, 15));
      expect(total, const Money(10000 * 3 + 13500 * 3));
    });

    test('항목을 지우면 이력에서 빠진다', () async {
      final subject = await notifier();
      await subject.upsertPriceHistoryPoint(
        'netflix-1',
        PricePoint(
          effectiveFrom: DateTime(2026, 6, 1),
          amount: const Money(13500),
        ),
      );

      await subject.removePriceHistoryPoint('netflix-1', DateTime(2026, 6, 1));

      final history = current().priceHistory;
      expect(history.length, 1);
      expect(history.single.amount, const Money(10000));
    });

    test('마지막 하나 남은 항목은 지울 수 없다', () async {
      final subject = await notifier();

      await subject.removePriceHistoryPoint('netflix-1', DateTime(2026, 1, 1));

      // 아무 일도 일어나지 않아야 한다 — 가격 이력이 하나도 없는 구독은 안 된다.
      expect(current().priceHistory.length, 1);
    });
  });
}
