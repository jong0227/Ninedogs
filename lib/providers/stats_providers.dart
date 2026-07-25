import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/catalog_service.dart';
import '../data/catalog/service_catalog.dart';
import '../data/models/money.dart';
import '../data/models/subscription.dart';
import 'app_providers.dart';
import 'subscription_providers.dart';

/// 한 분야의 지출 묶음.
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.monthly,
    required this.lifetime,
    required this.subscriptions,
  });

  /// 직접 추가해서 분야를 알 수 없으면 null.
  final ServiceCategory? category;

  /// 이 분야에 매달 나가는 돈(월 환산).
  final Money monthly;

  /// 지금까지 이 분야에 쓴 총액.
  final Money lifetime;

  final List<Subscription> subscriptions;

  String get label => category?.label ?? '기타';
  int get count => subscriptions.length;
}

/// 구독이 어느 분야인지. 카탈로그에 없으면 null(기타).
ServiceCategory? categoryOf(Subscription subscription) {
  final id = subscription.serviceId;
  if (id == null) return null;
  return ServiceCatalog.byId(id)?.category;
}

/// 구독 중인 것만 분야별로 묶는다. 월 지출이 큰 분야가 앞에 온다.
/// 달러 구독은 환율로 원화 환산해서 함께 집계한다.
final categorySpendProvider = Provider<List<CategorySpend>>((ref) {
  final active = ref.watch(activeSubscriptionsProvider);
  final rate = ref.watch(exchangeRateProvider).value;
  return _bucketByCategory(active, sortByLifetime: false, usdToKrwRate: rate);
});

/// 분야별 **누적** 지출. 해지한 구독도 함께 센다.
///
/// "지금까지 쓴 돈"은 지금 구독 중인지와 상관없다. 작년에 끊은 넷플릭스에
/// 낸 돈도 실제로 나간 돈이므로 빼면 총액이 실제보다 작아진다.
final categoryLifetimeProvider = Provider<List<CategorySpend>>((ref) {
  final all = ref.watch(allSubscriptionsProvider);
  final rate = ref.watch(exchangeRateProvider).value;
  return _bucketByCategory(all, sortByLifetime: true, usdToKrwRate: rate);
});

/// 구독 목록을 분야별로 묶는다.
///
/// 예전엔 통화가 섞이면 "가장 많이 쓰는 통화"만 남기고 나머지는 통째로
/// 뺐다 — 그래서 원화 구독이 많은 사람이 달러로 등록한 서비스 하나를
/// 추가하면 그게 분야 목록·개수·합계 어디에도 안 잡히는 버그가 있었다.
/// 지금은 전부 원화로 환산해서 하나로 합친다. 환율을 아직 못 받아왔으면
/// (앱을 막 켰을 때) 그 구독은 목록에는 보이되 합계에서는 잠깐 빠진다 —
/// 안 보이는 것보다 낫고, 환율이 오는 대로 다시 계산된다.
List<CategorySpend> _bucketByCategory(
  List<Subscription> subscriptions, {
  required bool sortByLifetime,
  required double? usdToKrwRate,
}) {
  if (subscriptions.isEmpty) return const [];

  final buckets = <ServiceCategory?, List<Subscription>>{};
  for (final subscription in subscriptions) {
    buckets.putIfAbsent(categoryOf(subscription), () => []).add(subscription);
  }

  final result = buckets.entries.map((entry) {
    var monthly = Money.zero();
    var lifetime = Money.zero();
    for (final subscription in entry.value) {
      final monthlyKrw = _krwOrNull(subscription.monthlyCost, usdToKrwRate);
      final lifetimeKrw = _krwOrNull(subscription.totalSpent, usdToKrwRate);
      if (monthlyKrw != null) monthly += monthlyKrw;
      if (lifetimeKrw != null) lifetime += lifetimeKrw;
    }
    return CategorySpend(
      category: entry.key,
      monthly: monthly,
      lifetime: lifetime,
      subscriptions: entry.value,
    );
  }).toList();

  result.sort(
    (a, b) => sortByLifetime
        ? b.lifetime.minor.compareTo(a.lifetime.minor)
        : b.monthly.minor.compareTo(a.monthly.minor),
  );
  return result;
}

/// 원화면 그대로, 달러면 환율로 환산해서 돌려준다. 환율이 아직 없는데
/// 달러라서 환산할 수 없으면 null — 그 항목만 합계에서 빠진다.
Money? _krwOrNull(Money money, double? usdToKrwRate) {
  if (money.currency == Money.krw) return money;
  if (usdToKrwRate == null) return null;
  return money.toKrw(usdToKrwRate);
}

/// 통계에 쓰는 기준 통화의 월 합계. 비중(%) 계산의 분모다.
final categoryTotalProvider = Provider<Money>((ref) {
  final spends = ref.watch(categorySpendProvider);
  if (spends.isEmpty) return Money.zero();

  var total = Money.zero(spends.first.monthly.currency);
  for (final spend in spends) {
    total += spend.monthly;
  }
  return total;
});

/// 누적 지출 합계. 누적 보기의 비중(%) 계산 분모다.
final categoryLifetimeTotalProvider = Provider<Money>((ref) {
  final spends = ref.watch(categoryLifetimeProvider);
  if (spends.isEmpty) return Money.zero();

  var total = Money.zero(spends.first.lifetime.currency);
  for (final spend in spends) {
    total += spend.lifetime;
  }
  return total;
});
