import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:ninedogs/data/sync/contract.dart';

/// 두 앱(Ninedogs, family_finance)이 같은 구독 문서를 쓰기 위한 계약.
void main() {
  final sub = Subscription.create(
    id: 's',
    name: 'OTT-A',
    cycle: BillingCycle.monthly,
    startedAt: DateTime(2026, 1, 1),
    priceHistory: [
      PricePoint(effectiveFrom: DateTime(2026, 1, 1), amount: const Money(10000)),
    ],
  );

  test('저장하는 문서에는 계약 버전(cv)이 적힌다', () {
    expect(sub.toJson()['cv'], kContractVersion);
  });

  test('cv 가 없던 예전 문서도 그대로 읽힌다', () {
    final json = sub.toJson()..remove('cv');
    expect(Subscription.fromJson(json).id, 's');
  });

  test('더 높은 cv 를 보면 쓰기를 막는 예외에 버전이 담긴다', () {
    const e = ContractTooNewException(kContractVersion + 1);
    expect(e.seen, greaterThan(kContractVersion));
  });
}
