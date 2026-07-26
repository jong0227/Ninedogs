import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/widgets/monthly_amount_text.dart';

Subscription build(BillingCycle cycle, Money price) => Subscription(
  id: 'test',
  name: '테스트',
  cycle: cycle,
  startedAt: DateTime(2026, 1, 1),
  priceHistory: [
    PricePoint(effectiveFrom: DateTime(2026, 1, 1), amount: price),
  ],
);

Future<void> pump(WidgetTester tester, Subscription subscription) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: MonthlyAmountText(subscription)),
      ),
    ),
  );
}

void main() {
  group('목록 금액 표시', () {
    // 통화 기호 표기는 로케일이 정하니 숫자만 본다.
    testWidgets('연간 결제는 월 환산액을 보여주고 월별 라벨을 붙인다', (tester) async {
      // 연 120,000원이면 매달 10,000원 부담이다.
      await pump(tester, build(BillingCycle.yearly, const Money(120000)));

      expect(find.text('월별'), findsOneWidget);
      expect(find.textContaining('10,000'), findsOneWidget);
      // 연 청구액을 그대로 띄우면 매달 나가는 돈으로 오해한다.
      expect(find.textContaining('120,000'), findsNothing);
    });

    testWidgets('월간 결제는 청구액 그대로 두고 라벨을 붙이지 않는다', (tester) async {
      await pump(tester, build(BillingCycle.monthly, const Money(13500)));

      // 청구액과 같은 금액에 '월별' 을 붙이면 군더더기다.
      expect(find.text('월별'), findsNothing);
      expect(find.textContaining('13,500'), findsOneWidget);
    });

    testWidgets('3개월마다 결제도 월 환산한다', (tester) async {
      await pump(tester, build(BillingCycle.quarterly, const Money(30000)));

      expect(find.text('월별'), findsOneWidget);
      expect(find.textContaining('10,000'), findsOneWidget);
    });
  });
}
