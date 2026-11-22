import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/people.dart';
import 'package:ninedogs/data/models/subscription.dart';

Subscription _sub({String? owner}) => Subscription.create(
  id: 's',
  name: 'OTT-A',
  cycle: BillingCycle.monthly,
  startedAt: DateTime(2026, 1, 1),
  priceHistory: [
    PricePoint(effectiveFrom: DateTime(2026, 1, 1), amount: const Money(10000)),
  ],
  owner: owner,
);

void main() {
  test('주인은 저장했다 읽어도 그대로다', () {
    final s = Subscription.fromJson(_sub(owner: 'b').toJson());
    expect(s.owner, 'b');
  });

  test('주인 필드가 없던 예전 데이터는 공동(null)으로 읽는다', () {
    final json = _sub(owner: 'a').toJson()..remove('owner');
    expect(Subscription.fromJson(json).owner, isNull);
  });

  test('copyWith 로 주인을 바꾸거나 지울 수 있다', () {
    final s = _sub(owner: 'a');
    expect(s.copyWith(owner: () => 'b').owner, 'b');
    expect(s.copyWith(owner: () => null).owner, isNull);
    expect(s.copyWith(name: 'x').owner, 'a');
  });

  test('사람 이름은 비어 있으면 기본값', () {
    final p = People.fromJson({'names': {'a': '가나', 'b': '  '}});
    expect(p.nameOf('a'), '가나');
    expect(p.nameOf('b'), People.defaults.nameOf('b'));
    expect(People.fromJson(null).nameOf('a'), People.defaults.nameOf('a'));
  });
}
