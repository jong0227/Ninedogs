import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/catalog_service.dart';
import '../data/catalog/service_catalog.dart';
import '../data/models/money.dart';
import '../data/models/subscription.dart';
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
///
/// 통화가 섞여 있으면 비중 계산이 무의미해지므로 **가장 많이 쓰는 통화**
/// 기준으로만 집계한다. (대부분 원화 하나뿐이다)
final categorySpendProvider = Provider<List<CategorySpend>>((ref) {
  final active = ref.watch(activeSubscriptionsProvider);
  return _bucketByCategory(active, sortByLifetime: false);
});

/// 분야별 **누적** 지출. 해지한 구독도 함께 센다.
///
/// "지금까지 쓴 돈"은 지금 구독 중인지와 상관없다. 작년에 끊은 넷플릭스에
/// 낸 돈도 실제로 나간 돈이므로 빼면 총액이 실제보다 작아진다.
final categoryLifetimeProvider = Provider<List<CategorySpend>>((ref) {
  final all = ref.watch(allSubscriptionsProvider);
  return _bucketByCategory(all, sortByLifetime: true);
});

/// 구독 목록을 분야별로 묶는다.
///
/// 통화가 섞여 있으면 비중 계산이 무의미해지므로 **가장 많이 쓰는 통화**
/// 기준으로만 집계한다. (대부분 원화 하나뿐이다)
List<CategorySpend> _bucketByCategory(
  List<Subscription> subscriptions, {
  required bool sortByLifetime,
}) {
  if (subscriptions.isEmpty) return const [];

  final currency = _dominantCurrency(subscriptions);
  final buckets = <ServiceCategory?, List<Subscription>>{};

  for (final subscription in subscriptions) {
    if (subscription.currency != currency) continue;
    buckets.putIfAbsent(categoryOf(subscription), () => []).add(subscription);
  }

  final result = buckets.entries.map((entry) {
    var monthly = Money.zero(currency);
    var lifetime = Money.zero(currency);
    for (final subscription in entry.value) {
      monthly += subscription.monthlyCost;
      lifetime += subscription.totalSpent;
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

/// 구독 수가 가장 많은 통화. 동률이면 원화를 우선한다.
String _dominantCurrency(List<Subscription> subscriptions) {
  final counts = <String, int>{};
  for (final subscription in subscriptions) {
    counts[subscription.currency] = (counts[subscription.currency] ?? 0) + 1;
  }

  var best = Money.krw;
  var bestCount = -1;
  counts.forEach((currency, count) {
    if (count > bestCount || (count == bestCount && currency == Money.krw)) {
      best = currency;
      bestCount = count;
    }
  });
  return best;
}
