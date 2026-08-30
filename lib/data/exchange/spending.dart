import '../models/money.dart';
import '../models/subscription.dart';
import 'exchange_rate_history.dart';

/// "이 구독에 지금까지 쓴 돈"을 원화로 답하는 **한 곳**.
///
/// 예전엔 이 계산이 두 갈래였다. 홈 화면은 통화별 합계를 오늘 환율로
/// 환산했고, 통계 화면은 따로 계산했다. 달러 구독이 있으면 두 화면이 같은
/// 질문에 다른 숫자를 내놨다. 어느 쪽이 맞는지 사용자가 알 방법이 없다.
///
/// [rates] 가 있으면 **결제마다 그날 환율**을 적용한다. 2024년에 낸 $9.99 를
/// 오늘 환율로 환산하면 실제 빠져나간 원화와 다르다. 환율이 1,300원에서
/// 1,450원으로 움직인 구간이 있으면 몇 년치가 통째로 어긋난다.
///
/// [rates] 를 아직 못 받아왔으면 [todayRate] 로 근사한다. 그마저 없으면
/// null — 그 구독만 합계에서 잠깐 빠진다. 안 보이는 것보다 낫고, 환율이
/// 오는 대로 다시 계산된다.
/// [asOf] 를 주면 그 시점까지만 센다. 안 주면 지금까지.
Money? lifetimeInKrw(
  Subscription subscription, {
  required RateTable? rates,
  required double? todayRate,
  DateTime? asOf,
}) {
  final until = asOf ?? DateTime.now();

  // 원화만 쓰는 구독은 환율이 필요 없다. 대부분이 여기로 빠진다.
  if (subscription.currency == Money.krw && !subscription.hasMixedCurrency) {
    return subscription.totalSpentUntil(until);
  }

  if (rates != null && !rates.isEmpty) {
    var total = Money.zero();
    for (final charge in subscription.chargesUntil(until)) {
      total += rates.toKrwOn(charge.amount, charge.date);
    }
    return total;
  }

  if (todayRate == null) return null;

  // 통화가 섞인 이력은 항목마다 따로 환산해야 한다. 합쳐 놓고 한 번에
  // 바꾸면 Money 의 통화 검사에 걸린다 — 그마저 assert 라 릴리즈에서는
  // 조용히 13,500원을 $135.00 로 더해버린다.
  var total = Money.zero();
  for (final charge in subscription.chargesUntil(until)) {
    total += charge.amount.toKrw(todayRate);
  }
  return total;
}

/// 여러 구독의 누적 지출을 원화로 합친다.
///
/// 환율을 몰라 환산할 수 없는 구독은 빼고 더한다.
Money lifetimeTotalInKrw(
  Iterable<Subscription> subscriptions, {
  required RateTable? rates,
  required double? todayRate,
  DateTime? asOf,
}) {
  var total = Money.zero();
  for (final subscription in subscriptions) {
    final amount = lifetimeInKrw(
      subscription,
      rates: rates,
      todayRate: todayRate,
      asOf: asOf,
    );
    if (amount != null) total += amount;
  }
  return total;
}
