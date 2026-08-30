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

  @override
  Future<List<Subscription>> load() async => stored;

  @override
  Future<void> save(List<Subscription> subscriptions) async =>
      stored = subscriptions;

  @override
  Stream<List<Subscription>>? watch() => null;
}

Subscription netflix() => Subscription.create(
  id: 'netflix',
  name: '넷플릭스',
  cycle: BillingCycle.monthly,
  startedAt: DateTime(2025, 1, 15),
  memo: '스탠다드',
  priceHistory: [
    PricePoint(
      effectiveFrom: DateTime(2025, 1, 15),
      amount: const Money(13500),
      cycle: BillingCycle.monthly,
    ),
  ],
  pastPeriods: [
    SubscriptionPeriod(
      startedAt: DateTime(2023, 3, 1),
      endedAt: DateTime(2023, 9, 30),
    ),
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

  group('요금제 변경', () {
    test('금액과 주기를 시점과 함께 기록한다', () async {
      final subject = await notifier();

      await subject.changePlan(
        'netflix',
        price: const Money(162000),
        cycle: BillingCycle.yearly,
        effectiveFrom: DateTime(2026, 1, 15),
        memo: '프리미엄 연간',
      );

      final after = current();
      expect(after.cycle, BillingCycle.yearly);
      expect(after.priceHistory.length, 2);
      expect(after.priceHistory.last.cycle, BillingCycle.yearly);
      expect(after.memo, '프리미엄 연간');
    });

    test('바꾸기 전 기간은 옛 주기로 계산된다', () async {
      // 이게 핵심이다. 주기를 구독당 하나만 들고 있으면 과거 결제까지
      // 연간으로 다시 세어서 누적이 통째로 틀어진다.
      final subject = await notifier();

      await subject.changePlan(
        'netflix',
        price: const Money(162000),
        cycle: BillingCycle.yearly,
        effectiveFrom: DateTime(2026, 1, 15),
      );

      final after = current();
      expect(after.cycleAt(DateTime(2025, 6, 1)), BillingCycle.monthly);
      expect(after.cycleAt(DateTime(2026, 6, 1)), BillingCycle.yearly);
    });

    test('요금제를 바꿔도 구독 이력이 남는다', () async {
      final subject = await notifier();

      await subject.changePlan(
        'netflix',
        price: const Money(17000),
        cycle: BillingCycle.monthly,
        effectiveFrom: DateTime(2026, 2, 1),
      );

      expect(current().pastPeriods.length, 1);
    });

    test('요금제 이름을 안 주면 메모를 건드리지 않는다', () async {
      final subject = await notifier();

      await subject.changePlan(
        'netflix',
        price: const Money(17000),
        cycle: BillingCycle.monthly,
        effectiveFrom: DateTime(2026, 2, 1),
      );

      expect(current().memo, '스탠다드');
    });

    test('같은 날 두 번 바꾸면 덮어쓴다', () async {
      final subject = await notifier();

      await subject.changePlan(
        'netflix',
        price: const Money(17000),
        cycle: BillingCycle.monthly,
        effectiveFrom: DateTime(2026, 2, 1),
      );
      await subject.changePlan(
        'netflix',
        price: const Money(19000),
        cycle: BillingCycle.monthly,
        effectiveFrom: DateTime(2026, 2, 1),
      );

      final after = current();
      expect(after.priceHistory.length, 2);
      expect(after.priceHistory.last.amount, const Money(19000));
    });
  });

  group('해지 날짜', () {
    test('해지한 날을 직접 정할 수 있다', () async {
      // 해지한 날과 앱에 기록하는 날이 같으리란 법이 없다.
      final subject = await notifier();

      await subject.cancel('netflix', canceledAt: DateTime(2026, 3, 24));

      expect(current().canceledAt, DateTime(2026, 3, 24));
      expect(current().isActive, isFalse);
    });

    test('날짜를 안 주면 오늘로 본다', () async {
      final subject = await notifier();

      await subject.cancel('netflix');

      final canceled = current().canceledAt!;
      final now = DateTime.now();
      expect(canceled.year, now.year);
      expect(canceled.month, now.month);
      expect(canceled.day, now.day);
    });

    test('해지일을 나중에 고칠 수 있다', () async {
      // 예전엔 상세 화면의 '해지일' 줄에 onTap 이 없어 고칠 길이 아예 없었다.
      final subject = await notifier();
      await subject.cancel('netflix', canceledAt: DateTime(2026, 3, 24));

      await subject.setCanceledAt('netflix', DateTime(2026, 3, 20));

      expect(current().canceledAt, DateTime(2026, 3, 20));
    });

    test('구독 중인 건 해지일이 생기지 않는다', () async {
      final subject = await notifier();

      await subject.setCanceledAt('netflix', DateTime(2026, 3, 20));

      expect(current().canceledAt, isNull);
      expect(current().isActive, isTrue);
    });

    test('해지해도 구독 이력이 남는다', () async {
      final subject = await notifier();

      await subject.cancel('netflix', canceledAt: DateTime(2026, 3, 24));

      expect(current().pastPeriods.length, 1);
    });
  });
}
