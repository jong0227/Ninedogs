import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/data/repository/subscription_repository.dart';
import 'package:ninedogs/providers/subscription_providers.dart';

/// 구독을 고칠 때 **건드리지 않은 필드가 조용히 사라지지 않는지** 지킨다.
///
/// 편집 화면에서 구독을 통째로 다시 만들다가 `pastPeriods` 를 빠뜨려,
/// 이름만 바꿔도 구독 이력이 전멸한 적이 있다. 기본값이 있으니 빠뜨려도
/// 컴파일이 되고 테스트도 통과해서 사용자 기기에서야 드러났다.
///
/// 그래서 필드를 하나씩 확인하는 대신 **toJson() 전체를 비교**한다.
/// 나중에 필드를 추가해도 이 테스트가 자동으로 지켜준다.
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

/// 모든 필드가 채워진 구독. 빈 값이 있으면 "사라졌다"를 감지할 수 없다.
Subscription fullyPopulated() => Subscription.create(
  id: 'sub-1',
  serviceId: 'netflix',
  name: '넷플릭스',
  iconUrl: 'https://example.com/netflix.png',
  brandColorValue: 0xFFE50914,
  cycle: BillingCycle.monthly,
  startedAt: DateTime(2025, 6, 1),
  billingAnchor: DateTime(2025, 6, 15),
  canceledAt: DateTime(2026, 3, 20),
  accessEndsAt: DateTime(2026, 4, 14),
  trialEndsAt: DateTime(2025, 6, 8),
  paymentMethod: '신한카드 1234',
  credentialId: 'cred-1',
  memo: '프리미엄',
  reminderDaysBefore: const [7, 1],
  priceHistory: [
    PricePoint(
      effectiveFrom: DateTime(2023, 1, 1),
      amount: const Money(13500),
      cycle: BillingCycle.monthly,
    ),
    PricePoint(
      effectiveFrom: DateTime(2025, 6, 1),
      amount: const Money(17000),
      cycle: BillingCycle.monthly,
    ),
  ],
  pastPeriods: [
    SubscriptionPeriod(
      startedAt: DateTime(2023, 1, 1),
      endedAt: DateTime(2023, 8, 31),
    ),
    SubscriptionPeriod(
      startedAt: DateTime(2024, 2, 1),
      endedAt: DateTime(2024, 11, 30),
    ),
  ],
);

/// [before] 와 [after] 를 견줘서 실제로 달라진 필드 이름만 모은다.
Set<String> changedKeys(Subscription before, Subscription after) {
  final a = before.toJson();
  final b = after.toJson();
  return {
    for (final key in {...a.keys, ...b.keys})
      if (a[key].toString() != b[key].toString()) key,
  };
}

void main() {
  group('copyWith 는 건드리지 않은 필드를 그대로 둔다', () {
    test('아무것도 안 넘기면 아무것도 안 바뀐다', () {
      final before = fullyPopulated();
      expect(changedKeys(before, before.copyWith()), isEmpty);
    });

    test('이름만 바꾸면 이름만 바뀐다', () {
      // 예전 사고가 바로 이 경우였다. 이름을 바꿨는데 pastPeriods 가 날아갔다.
      final before = fullyPopulated();
      final after = before.copyWith(name: '넷플릭스 프리미엄');

      expect(changedKeys(before, after), {'name'});
      expect(after.pastPeriods.length, 2);
      expect(after.reminderDaysBefore, [7, 1]);
    });

    test('필드마다 하나씩 바꿔도 그 필드만 바뀐다', () {
      final before = fullyPopulated();

      final cases = <String, Subscription>{
        'name': before.copyWith(name: '다른 이름'),
        'cycle': before.copyWith(cycle: BillingCycle.yearly),
        'startedAt': before.copyWith(startedAt: DateTime(2025, 7, 1)),
        'serviceId': before.copyWith(serviceId: () => 'disney'),
        'iconUrl': before.copyWith(iconUrl: () => 'https://x.test/i.png'),
        'brandColorValue': before.copyWith(brandColorValue: () => 0xFF000000),
        'billingAnchor': before.copyWith(
          billingAnchor: () => DateTime(2025, 6, 20),
        ),
        'canceledAt': before.copyWith(canceledAt: () => DateTime(2026, 5, 1)),
        'accessEndsAt': before.copyWith(
          accessEndsAt: () => DateTime(2026, 6, 1),
        ),
        'trialEndsAt': before.copyWith(trialEndsAt: () => DateTime(2025, 7, 8)),
        'paymentMethod': before.copyWith(paymentMethod: () => '국민카드 9999'),
        'credentialId': before.copyWith(credentialId: () => 'cred-2'),
        'memo': before.copyWith(memo: () => '스탠다드'),
        'reminderDaysBefore': before.copyWith(
          reminderDaysBefore: () => const [3],
        ),
      };

      cases.forEach((field, after) {
        expect(
          changedKeys(before, after),
          {field},
          reason: '$field 만 바뀌어야 하는데 다른 필드도 함께 변했다',
        );
      });
    });
  });

  group('봉투를 씌우면 값을 비울 수 있다', () {
    test('비울 수 있는 필드는 전부 실제로 비워진다', () {
      final before = fullyPopulated();

      expect(before.copyWith(serviceId: () => null).serviceId, isNull);
      expect(before.copyWith(iconUrl: () => null).iconUrl, isNull);
      expect(
        before.copyWith(brandColorValue: () => null).brandColorValue,
        isNull,
      );
      expect(before.copyWith(billingAnchor: () => null).billingAnchor, isNull);
      expect(before.copyWith(canceledAt: () => null).canceledAt, isNull);
      expect(before.copyWith(accessEndsAt: () => null).accessEndsAt, isNull);
      expect(before.copyWith(trialEndsAt: () => null).trialEndsAt, isNull);
      expect(before.copyWith(paymentMethod: () => null).paymentMethod, isNull);
      expect(before.copyWith(credentialId: () => null).credentialId, isNull);
      expect(before.copyWith(memo: () => null).memo, isNull);
      expect(
        before.copyWith(reminderDaysBefore: () => null).reminderDaysBefore,
        isNull,
      );
    });

    test('비우면 그 필드 하나만 바뀐다', () {
      final before = fullyPopulated();
      expect(changedKeys(before, before.copyWith(memo: () => null)), {'memo'});
    });
  });

  group('저장했다 불러와도 그대로다', () {
    test('JSON 왕복에서 필드가 하나도 안 샌다', () {
      final before = fullyPopulated();
      final after = Subscription.fromJson(before.toJson());
      expect(changedKeys(before, after), isEmpty);
    });
  });

  group('편집 경로가 다른 필드를 건드리지 않는다', () {
    late FakeRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeRepository([fullyPopulated()]);
      container = ProviderContainer.test(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
        ],
      );
    });

    Future<SubscriptionsNotifier> notifier() async {
      await container.read(subscriptionsProvider.future);
      return container.read(subscriptionsProvider.notifier);
    }

    Subscription current() => container.read(allSubscriptionsProvider).single;

    test('카드 결제일을 바꿔도 이력과 무료체험이 남는다', () async {
      // setBillingAnchor 도 예전엔 객체를 다시 만들면서 pastPeriods 와
      // trialEndsAt 을 빠뜨렸다.
      final subject = await notifier();
      final before = current();

      await subject.setBillingAnchor('sub-1', DateTime(2025, 6, 25));

      expect(changedKeys(before, current()), {'billingAnchor'});
    });

    test('카드 결제일을 지워도 다른 건 그대로다', () async {
      final subject = await notifier();
      final before = current();

      await subject.setBillingAnchor('sub-1', null);

      expect(changedKeys(before, current()), {'billingAnchor'});
      expect(current().billingAnchor, isNull);
    });

    test('결제 수단을 지우면 실제로 지워진다', () async {
      // 예전엔 null 을 넘겨도 옛 값이 남았다. 화면 안내와 동작이 달랐다.
      final subject = await notifier();
      final before = current();

      await subject.setPaymentMethod('sub-1', null);

      expect(current().paymentMethod, isNull);
      expect(changedKeys(before, current()), {'paymentMethod'});
    });

    test('알림 설정을 전체 설정 따르기로 되돌려도 다른 건 그대로다', () async {
      final subject = await notifier();
      final before = current();

      await subject.setReminderDays('sub-1', null);

      expect(current().reminderDaysBefore, isNull);
      expect(changedKeys(before, current()), {'reminderDaysBefore'});
    });

    test('해지일만 고쳐도 다른 건 그대로다', () async {
      final subject = await notifier();
      final before = current();

      await subject.setCanceledAt('sub-1', DateTime(2026, 3, 24));

      expect(changedKeys(before, current()), {'canceledAt'});
      expect(current().canceledAt, DateTime(2026, 3, 24));
    });

    test('시작일을 고쳐도 이력이 남는다', () async {
      final subject = await notifier();
      final before = current();

      await subject.setStartedAt('sub-1', DateTime(2025, 5, 1));

      expect(changedKeys(before, current()), {'startedAt'});
      expect(current().pastPeriods.length, 2);
    });
  });
}
