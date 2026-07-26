import 'package:flutter/material.dart';

import '../data/models/billing_cycle.dart';
import '../data/models/subscription.dart';
import 'krw_amount_text.dart';

/// 목록에서 구독 하나의 금액을 **월 부담액 기준**으로 보여준다.
///
/// 연간 결제하는 구독이 큰 금액(예: 119,000원)으로 찍히면 매달 나가는 돈처럼
/// 읽혀서 다른 줄과 나란히 놓고 비교가 안 된다. 주기가 제각각이어도 월로
/// 환산해두면 어느 게 더 부담인지 바로 보인다.
///
/// 다만 환산한 값은 실제로 청구되는 금액이 아니다. 카드 명세서에 없는
/// 숫자를 그냥 띄우면 오해하니까, 월 결제가 아닌 구독에만 위에 '월별' 이라고
/// 작게 붙여서 환산값임을 알린다. 매월 결제는 붙이지 않는다 — 그 금액이
/// 곧 청구액이라 라벨이 군더더기다.
class MonthlyAmountText extends StatelessWidget {
  const MonthlyAmountText(this.subscription, {super.key});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final converted = subscription.cycle != BillingCycle.monthly;

    final amount = KrwAmountText(
      converted ? subscription.monthlyCost : subscription.currentPrice,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    if (!converted) return amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '월별',
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: 10,
            // 금액이 주인공이라 라벨은 한 단계 물러나 있어야 한다.
            color: theme.textTheme.labelMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        amount,
      ],
    );
  }
}
