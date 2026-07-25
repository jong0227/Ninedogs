import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/money.dart';
import '../providers/app_providers.dart';

/// 통화와 상관없이 원화로 보여준다.
///
/// 달러로 등록한 구독도 원화로 얼마인지 한눈에 들어와야 한다는 요청으로
/// 만들었다. 원화면 그대로, 달러면 환율로 환산한 값을 **주로** 보여주고
/// [showOriginal] 이 true 면 실제 청구 통화(예: $9.99)를 작게 덧붙인다 —
/// 카드 명세서와 맞춰볼 때 필요하다.
///
/// 환율을 아직 못 받아왔으면(앱을 막 켠 순간) 원래 통화 그대로 보여준다.
/// 값이 아예 안 보이는 것보다 낫고, 환율이 오는 대로 다시 그려진다.
class KrwAmountText extends ConsumerWidget {
  const KrwAmountText(
    this.money, {
    super.key,
    this.style,
    this.showOriginal = false,
    this.overflow,
  });

  final Money money;
  final TextStyle? style;
  final bool showOriginal;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (money.currency == Money.krw) {
      return Text(money.format(), style: style, overflow: overflow);
    }

    final rate = ref.watch(exchangeRateProvider).value;
    if (rate == null) {
      return Text(money.format(), style: style, overflow: overflow);
    }

    final krw = money.toKrw(rate);
    final text = showOriginal
        ? '${krw.format()} (${money.format()})'
        : krw.format();
    return Text(text, style: style, overflow: overflow);
  }
}
