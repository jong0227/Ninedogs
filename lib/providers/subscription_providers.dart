import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/money.dart';
import '../data/models/subscription.dart';
import '../data/repository/subscription_repository.dart';
import 'app_providers.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => LocalSubscriptionRepository(ref.watch(sharedPreferencesProvider)),
);

class SubscriptionsNotifier extends AsyncNotifier<List<Subscription>> {
  SubscriptionRepository get _repository =>
      ref.read(subscriptionRepositoryProvider);

  @override
  Future<List<Subscription>> build() => _repository.load();

  Future<void> addAll(Iterable<Subscription> subscriptions) =>
      _mutate((current) => [...current, ...subscriptions]);

  Future<void> add(Subscription subscription) => addAll([subscription]);

  /// 같은 id 의 구독을 통째로 갈아끼운다.
  Future<void> replace(Subscription subscription) => _mutate(
    (current) => [
      for (final s in current) if (s.id == subscription.id) subscription else s,
    ],
  );

  Future<void> remove(String id) =>
      _mutate((current) => current.where((s) => s.id != id).toList());

  /// 해지 처리. [accessEndsAt] 이후에는 이용 권한도 끝난다.
  Future<void> cancel(String id, {DateTime? accessEndsAt}) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id)
          s.copyWith(
            canceledAt: DateTime.now(),
            accessEndsAt: accessEndsAt ?? s.accessValidUntil,
          )
        else
          s,
    ],
  );

  /// 가격 변동 기록. [effectiveFrom] 부터 새 금액이 적용된다.
  Future<void> recordPriceChange(
    String id,
    Money newPrice, {
    DateTime? effectiveFrom,
  }) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id)
          s.copyWith(
            priceHistory: [
              ...s.priceHistory,
              PricePoint(
                effectiveFrom: effectiveFrom ?? DateTime.now(),
                amount: newPrice,
              ),
            ],
          )
        else
          s,
    ],
  );

  /// 금액을 잘못 적었을 때 쓰는 정정. 가격이 바뀐 게 아니므로 이력을 늘리지
  /// 않고 마지막 항목을 교체한다. 누적 지출도 새 금액 기준으로 다시 계산된다.
  Future<void> correctLatestPrice(String id, Money price) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id)
          s.copyWith(
            priceHistory: [
              ...s.priceHistory.take(s.priceHistory.length - 1),
              PricePoint(
                effectiveFrom: s.priceHistory.last.effectiveFrom,
                amount: price,
              ),
            ],
          )
        else
          s,
    ],
  );

  Future<void> _mutate(
    List<Subscription> Function(List<Subscription> current) transform,
  ) async {
    final next = transform(state.value ?? const []);
    state = AsyncData(next);
    await _repository.save(next);
  }
}

final subscriptionsProvider =
    AsyncNotifierProvider<SubscriptionsNotifier, List<Subscription>>(
      SubscriptionsNotifier.new,
    );

/// 로딩 중이면 빈 목록. 화면에서 AsyncValue 를 매번 풀지 않아도 되게 한다.
final allSubscriptionsProvider = Provider<List<Subscription>>(
  (ref) => ref.watch(subscriptionsProvider).value ?? const [],
);

/// id 로 한 건 찾기. 삭제된 뒤에는 null 이므로 화면에서 그대로 닫으면 된다.
final subscriptionByIdProvider = Provider.family<Subscription?, String>((
  ref,
  id,
) {
  for (final subscription in ref.watch(allSubscriptionsProvider)) {
    if (subscription.id == id) return subscription;
  }
  return null;
});

final activeSubscriptionsProvider = Provider<List<Subscription>>(
  (ref) => ref.watch(allSubscriptionsProvider).where((s) => s.isActive).toList(),
);

final canceledSubscriptionsProvider = Provider<List<Subscription>>(
  (ref) => ref.watch(allSubscriptionsProvider).where((s) => !s.isActive).toList(),
);

/// 구독 중인 서비스의 월 환산 합계. 통화별로 나눠서 돌려준다.
final monthlyTotalProvider = Provider<Map<String, Money>>(
  (ref) => _sumByCurrency(
    ref.watch(activeSubscriptionsProvider).map((s) => s.monthlyCost),
  ),
);

/// 지금까지 구독에 쓴 전체 금액. 해지한 구독도 포함한다.
final lifetimeTotalProvider = Provider<Map<String, Money>>(
  (ref) => _sumByCurrency(ref.watch(allSubscriptionsProvider).map((s) => s.totalSpent)),
);

/// 결제일이 가까운 순서대로 정렬한 구독 목록.
final upcomingBillingsProvider = Provider<List<Subscription>>((ref) {
  final active = [...ref.watch(activeSubscriptionsProvider)];
  active.sort((a, b) {
    final aDate = a.nextBillingDate();
    final bDate = b.nextBillingDate();
    if (aDate == null || bDate == null) return 0;
    return aDate.compareTo(bDate);
  });
  return active;
});

Map<String, Money> _sumByCurrency(Iterable<Money> amounts) {
  final totals = <String, Money>{};
  for (final amount in amounts) {
    final running = totals[amount.currency];
    totals[amount.currency] = running == null ? amount : running + amount;
  }
  // 금액이 큰 통화가 앞에 오게 한다. 화면에서 첫 항목을 크게 보여준다.
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.minor.compareTo(a.value.minor));
  return Map.fromEntries(sorted);
}
