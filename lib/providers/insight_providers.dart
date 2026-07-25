import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/money.dart';
import '../data/models/subscription.dart';
import 'subscription_providers.dart';

/// 눈여겨볼 만한 것 하나.
///
/// 화면에 그냥 숫자를 늘어놓는 대신, **지금 뭔가 해볼 수 있는 것**만 골라
/// 올린다. 정보가 많을수록 좋은 게 아니라 행동으로 이어져야 의미가 있다.
class Insight {
  const Insight({
    required this.kind,
    required this.title,
    required this.body,
    this.subscriptionId,
  });

  final InsightKind kind;
  final String title;
  final String body;

  /// 누르면 열어볼 구독. 없으면 이동하지 않는다.
  final String? subscriptionId;
}

enum InsightKind {
  /// 같은 서비스를 둘이 따로 결제 중.
  duplicate,

  /// 요금이 올랐다.
  priceIncrease,

  /// 무료 체험이 곧 끝난다.
  trialEnding,

  /// 결제일이 하루에 몰려 있다.
  billingCrowded,
}

/// 지금 알려줄 만한 것들. 급한 순서대로.
final insightsProvider = Provider<List<Insight>>((ref) {
  final all = ref.watch(allSubscriptionsProvider);
  final active = all.where((s) => s.isActive).toList();

  return [
    ..._trialEndings(active),
    ..._duplicates(active),
    ..._priceIncreases(active),
    ..._crowdedBillingDays(active),
  ];
});

/// 무료 체험이 곧 끝나는 것. 놓치면 바로 돈이 나가므로 맨 위에 둔다.
List<Insight> _trialEndings(List<Subscription> subscriptions) {
  final result = <Insight>[];

  for (final subscription in subscriptions) {
    final days = subscription.daysUntilTrialEnds;
    if (days == null || days > 14) continue;

    result.add(
      Insight(
        kind: InsightKind.trialEnding,
        title: days == 0
            ? '${subscription.name} 무료 체험이 오늘 끝나요'
            : '${subscription.name} 무료 체험 $days일 남음',
        body: '그때부터 ${subscription.currentPrice.format()} 결제돼요. '
            '계속 안 쓸 거면 지금 해지하세요.',
        subscriptionId: subscription.id,
      ),
    );
  }

  return result;
}

/// 같은 서비스를 두 건 이상 결제 중인 경우.
///
/// 부부가 각자 넣어둔 걸 합치면 드러난다. 연결하기 전에는 알 수 없던 낭비라
/// 이 앱에서만 찾아줄 수 있다. 0원짜리(번들 포함)는 실제로 돈이 안 나가므로
/// 중복으로 세지 않는다.
List<Insight> _duplicates(List<Subscription> subscriptions) {
  final byService = <String, List<Subscription>>{};

  for (final subscription in subscriptions) {
    if (subscription.currentPrice.isZero) continue;
    // 카탈로그에 있으면 serviceId, 직접 추가한 건 이름으로 묶는다.
    final key = subscription.serviceId ?? 'name:${subscription.name.trim()}';
    byService.putIfAbsent(key, () => []).add(subscription);
  }

  final result = <Insight>[];
  for (final group in byService.values) {
    if (group.length < 2) continue;

    // 겹치는 것 중 싼 쪽을 남기면 그만큼 아낄 수 있다.
    final costs = group.map((s) => s.monthlyCost).toList()
      ..sort((a, b) => a.minor.compareTo(b.minor));
    var wasted = Money.zero(costs.first.currency);
    for (final cost in costs.skip(1)) {
      wasted += cost;
    }

    result.add(
      Insight(
        kind: InsightKind.duplicate,
        title: '${group.first.name}을(를) ${group.length}건 결제 중이에요',
        body: '하나로 합치면 매달 ${wasted.format()}, '
            '1년이면 ${(wasted * 12).format()} 아껴요.',
        subscriptionId: group.first.id,
      ),
    );
  }

  return result;
}

/// 요금이 오른 구독.
///
/// 구독료 인상은 조용히 일어나서 아무도 모른다. 가격 이력을 이미 갖고 있으니
/// 처음 낸 금액과 지금 금액을 견줘 알려준다.
List<Insight> _priceIncreases(List<Subscription> subscriptions) {
  final result = <Insight>[];

  for (final subscription in subscriptions) {
    if (subscription.priceChanges.isEmpty) continue;

    final first = subscription.priceHistory.first.amount;
    final now = subscription.currentPrice;
    if (first.isZero || now.minor <= first.minor) continue;

    final percent = (((now.minor - first.minor) / first.minor) * 100).round();
    if (percent < 5) continue; // 반올림 수준의 변화는 알릴 것이 못 된다

    result.add(
      Insight(
        kind: InsightKind.priceIncrease,
        title: '${subscription.name} 요금이 $percent% 올랐어요',
        body: '${first.format()} → ${now.format()} '
            '(${subscription.priceChanges.length}번 인상)',
        subscriptionId: subscription.id,
      ),
    );
  }

  return result;
}

/// 하루에 결제가 몰려 있는 경우.
///
/// 같은 날 여러 건이 한꺼번에 빠져나가면 통장이 크게 흔들린다.
/// 세 건 이상 겹칠 때만 알린다.
List<Insight> _crowdedBillingDays(List<Subscription> subscriptions) {
  final byDay = <int, List<Subscription>>{};

  for (final subscription in subscriptions) {
    final next = subscription.nextBillingDate();
    if (next == null || subscription.currentPrice.isZero) continue;
    byDay.putIfAbsent(next.day, () => []).add(subscription);
  }

  final result = <Insight>[];
  byDay.forEach((day, group) {
    if (group.length < 3) return;

    var total = Money.zero(group.first.currentPrice.currency);
    for (final subscription in group) {
      total += subscription.currentPrice;
    }

    result.add(
      Insight(
        kind: InsightKind.billingCrowded,
        title: '매달 $day일에 ${group.length}건이 몰려요',
        body: '${total.format()}이 하루에 한꺼번에 빠져나가요.',
      ),
    );
  });

  return result;
}
