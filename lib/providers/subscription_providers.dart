import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/billing_cycle.dart';
import '../data/models/money.dart';
import '../data/models/subscription.dart';
import '../data/repository/firestore_repositories.dart';
import '../data/repository/subscription_repository.dart';
import 'app_providers.dart';
import 'sync_providers.dart';

/// 연결돼 있으면 household 저장소를, 아니면 이 기기 저장소를 쓴다.
/// 화면과 로직은 어느 쪽인지 몰라도 된다.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final householdId = ref.watch(householdIdProvider);
  if (householdId != null) {
    return FirestoreSubscriptionRepository(householdId: householdId);
  }
  return LocalSubscriptionRepository(ref.watch(sharedPreferencesProvider));
});

class SubscriptionsNotifier extends AsyncNotifier<List<Subscription>> {
  SubscriptionRepository get _repository =>
      ref.read(subscriptionRepositoryProvider);

  @override
  Future<List<Subscription>> build() {
    final repository = ref.watch(subscriptionRepositoryProvider);

    // 상대가 다른 기기에서 고치면 바로 반영된다.
    final stream = repository.watch();
    if (stream != null) {
      final listener = stream.listen((remote) {
        // 첫 불러오기가 끝나기 전에 끼어들면 그 결과에 덮어써진다.
        // 어차피 load() 가 같은 내용을 가져오므로 건너뛰어도 손해가 없다.
        if (state.hasValue) state = AsyncData(remote);
      });
      ref.onDispose(listener.cancel);
    }

    return repository.load();
  }

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

  /// 해지 처리. [canceledAt] 을 주지 않으면 오늘로 본다.
  ///
  /// 날짜를 받는 이유: 해지한 날과 앱에 기록하는 날이 같으리란 법이 없다.
  /// 며칠 지나서 넣는 일이 흔한데, 예전엔 무조건 오늘로 박혀서 고칠 방법도
  /// 없었다. [accessEndsAt] 이후에는 이용 권한도 끝난다.
  Future<void> cancel(
    String id, {
    DateTime? canceledAt,
    DateTime? accessEndsAt,
  }) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id)
          s.copyWith(
            canceledAt: () => canceledAt ?? DateTime.now(),
            accessEndsAt: () => accessEndsAt ?? s.accessValidUntil,
          )
        else
          s,
    ],
  );

  /// 요금제를 바꾼다. 금액과 결제 주기가 함께 달라질 수 있다.
  ///
  /// 주기를 [PricePoint] 에 같이 남기는 게 핵심이다. 구독당 주기를 하나만
  /// 들고 있으면 월간에서 연간으로 갈아탔을 때 과거 결제까지 연간으로 다시
  /// 세어서, 2년간 매달 낸 24번이 3번으로 줄어든다.
  ///
  /// [effectiveFrom] 이 이미 있는 항목과 같은 날이면 그 항목을 덮어쓴다.
  Future<void> changePlan(
    String id, {
    required Money price,
    required BillingCycle cycle,
    required DateTime effectiveFrom,
    String? memo,
  }) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id)
          s.copyWith(
            cycle: cycle,
            priceHistory: [
              ...s.priceHistory.where(
                (p) => !_sameDay(p.effectiveFrom, effectiveFrom),
              ),
              PricePoint(
                effectiveFrom: effectiveFrom,
                amount: price,
                cycle: cycle,
              ),
            ],
            // 요금제 이름을 안 주면 메모는 건드리지 않는다.
            memo: memo == null ? null : () => memo,
          )
        else
          s,
    ],
  );

  /// 이미 해지된 구독의 해지일만 고친다. 잘못 누른 날짜를 바로잡는 용도다.
  Future<void> setCanceledAt(String id, DateTime canceledAt) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id && !s.isActive)
          s.copyWith(canceledAt: () => canceledAt)
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

  /// 상세 화면에서 값 하나만 바로 고칠 때 쓴다.
  /// 편집 화면을 통째로 열지 않아도 되게.
  Future<void> setStartedAt(String id, DateTime startedAt) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id) s.copyWith(startedAt: startedAt) else s,
    ],
  );

  Future<void> setBillingAnchor(String id, DateTime? anchor) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id) s.copyWith(billingAnchor: () => anchor) else s,
    ],
  );

  /// 결제 수단 메모. null 을 주면 지운다.
  ///
  /// 예전엔 null 을 넘겨도 안 지워졌다 — copyWith 가 null 을 "안 바꿈"으로
  /// 읽었기 때문이다. 화면에는 "비워두면 등록하지 않은 것으로 둬요"라고
  /// 적혀 있었는데 실제로는 옛 값이 그대로 남았다.
  Future<void> setPaymentMethod(String id, String? paymentMethod) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id) s.copyWith(paymentMethod: () => paymentMethod) else s,
    ],
  );

  /// 이 구독만의 알림 시점. null 을 주면 전체 설정을 따르게 되돌린다.
  Future<void> setReminderDays(String id, List<int>? days) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id) s.copyWith(reminderDaysBefore: () => days) else s,
    ],
  );

  /// 구독 구간 전체를 갈아끼운다.
  ///
  /// 이력을 직접 고칠 수 있어야 한다 — 잘못 넣은 구간을 지우거나, 예전에
  /// 구독했던 기간을 뒤늦게 채워 넣는 일이 잦다.
  ///
  /// 가장 늦게 시작한 구간이 '지금 구간'([Subscription.startedAt] /
  /// [Subscription.canceledAt])이 되고 나머지는 [Subscription.pastPeriods]
  /// 로 간다. 아직 안 끝난 구간(endedAt == null)은 마지막 하나만 의미가
  /// 있으므로, 그보다 앞선 구간에 끝이 없으면 버린다.
  Future<void> setPeriods(
    String id,
    List<({DateTime startedAt, DateTime? endedAt})> periods,
  ) {
    if (periods.isEmpty) return Future.value(); // 구간이 하나도 없는 구독은 없다

    final sorted = [...periods]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final current = sorted.last;
    final past = <SubscriptionPeriod>[
      for (final period in sorted.take(sorted.length - 1))
        if (period.endedAt != null)
          SubscriptionPeriod(
            startedAt: period.startedAt,
            endedAt: period.endedAt!,
          ),
    ];

    return _mutate(
      (subscriptions) => [
        for (final s in subscriptions)
          if (s.id == id)
            s.copyWith(
              pastPeriods: past,
              startedAt: current.startedAt,
              canceledAt: () => current.endedAt,
            )
          else
            s,
      ],
    );
  }

  /// 해지했던 구독을 다시 시작한다.
  ///
  /// 볼 게 생기면 켰다가 끊는 서비스가 흔하다. 예전 기록을 지우고 새로
  /// 등록하면 그때 낸 돈이 사라지고, 그대로 되살리면 안 쓰던 기간에도
  /// 결제한 것으로 잡힌다. 끊었던 구간을 이력으로 밀어 넣고 새 구간을
  /// 연다. [price] 를 주면 그 날부터 새 금액이 적용된다.
  Future<void> resubscribe(
    String id, {
    required DateTime startedAt,
    Money? price,
  }) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id && !s.isActive)
          s.copyWith(
            pastPeriods: [
              ...s.pastPeriods,
              SubscriptionPeriod(
                startedAt: s.startedAt,
                endedAt: s.canceledAt!,
              ),
            ],
            startedAt: startedAt,
            canceledAt: () => null,
            priceHistory: price == null
                ? s.priceHistory
                : [
                    ...s.priceHistory.where(
                      (p) => !_sameDay(p.effectiveFrom, startedAt),
                    ),
                    PricePoint(
                      effectiveFrom: startedAt,
                      amount: price,
                      cycle: s.cycle,
                    ),
                  ],
          )
        else
          s,
    ],
  );

  /// 가격 이력에 임의의 시점 하나를 넣거나 고친다.
  ///
  /// [recordPriceChange] 는 항상 "지금부터"만 다루지만, 이건 과거 어느
  /// 시점이든 된다 — 처음 등록할 때 놓친 과거의 가격 변동("이 달부터는
  /// 얼마였다")을 나중에 채워 넣을 때 쓴다. 같은 날짜에 이미 항목이 있으면
  /// 그 값을 덮어쓴다. 순서와 상관없이 Subscription 생성자가 시점순으로
  /// 다시 정렬하므로 여기서는 신경 쓰지 않아도 된다.
  Future<void> upsertPriceHistoryPoint(String id, PricePoint point) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id)
          s.copyWith(
            priceHistory: [
              ...s.priceHistory.where(
                (p) => !_sameDay(p.effectiveFrom, point.effectiveFrom),
              ),
              point,
            ],
          )
        else
          s,
    ],
  );

  /// 잘못 추가한 가격 이력 한 점을 지운다. 최소 1개는 남아 있어야 한다.
  Future<void> removePriceHistoryPoint(
    String id,
    DateTime effectiveFrom,
  ) => _mutate(
    (current) => [
      for (final s in current)
        if (s.id == id && s.priceHistory.length > 1)
          s.copyWith(
            priceHistory: s.priceHistory
                .where((p) => !_sameDay(p.effectiveFrom, effectiveFrom))
                .toList(),
          )
        else
          s,
    ],
  );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
    // build() 가 끝나기 전에 state 를 바꾸면, 뒤늦게 끝난 build 결과가
    // 방금 넣은 값을 덮어써 버린다. (온보딩에서 이 화면을 아무도 보지 않은
    // 채로 구독을 추가할 때 실제로 이 순서가 된다)
    final current = await future;

    final next = transform(current);
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

/// 통화가 섞여 있어도 하나의 원화 숫자로 보고 싶을 때 쓴다.
/// 환율을 아직 못 받아왔으면 null — 그때는 화면에서 통화별 합계로 대신 보여준다.
final monthlyTotalKrwProvider = Provider<Money?>(
  (ref) => _combineToKrw(
    ref.watch(monthlyTotalProvider),
    ref.watch(exchangeRateProvider).value,
  ),
);

final lifetimeTotalKrwProvider = Provider<Money?>(
  (ref) => _combineToKrw(
    ref.watch(lifetimeTotalProvider),
    ref.watch(exchangeRateProvider).value,
  ),
);

/// 통화별 합계를 전부 원화로 바꿔 하나로 더한다.
/// KRW·USD 말고 다른 통화가 섞여 있거나 환율이 없으면 null.
Money? _combineToKrw(Map<String, Money> totals, double? usdToKrwRate) {
  if (totals.isEmpty) return Money.zero();

  var combined = 0;
  for (final entry in totals.entries) {
    if (entry.key == Money.krw) {
      combined += entry.value.minor;
    } else if (entry.key == 'USD' && usdToKrwRate != null) {
      combined += entry.value.toKrw(usdToKrwRate).minor;
    } else {
      return null;
    }
  }
  return Money(combined);
}

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
