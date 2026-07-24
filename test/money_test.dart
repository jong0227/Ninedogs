import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/money.dart';

void main() {
  group('Money', () {
    test('같은 통화끼리 더하고 뺀다', () {
      expect(const Money(13500) + const Money(10900), const Money(24400));
      expect(const Money(13500) - const Money(3500), const Money(10000));
    });

    test('나눌 때 반올림한다', () {
      // 연 99,000원 -> 월 8,250원
      expect(const Money(99000).dividedBy(12), const Money(8250));
      // 딱 떨어지지 않으면 반올림
      expect(const Money(10000).dividedBy(3), const Money(3333));
    });

    test('통화별 소수점 자리를 안다', () {
      expect(const Money(1000).decimalDigits, 0);
      expect(const Money(1000, currency: 'USD').decimalDigits, 2);
    });

    test('KRW 는 천 단위 구분 기호로 표시한다', () {
      expect(const Money(13500).format(), contains('13,500'));
    });

    test('USD 는 센트를 소수점으로 표시한다', () {
      expect(const Money(999, currency: 'USD').format(), contains('9.99'));
    });

    test('JSON 으로 왕복해도 값이 같다', () {
      const original = Money(2900, currency: 'USD');
      expect(Money.fromJson(original.toJson()), original);
    });
  });
}
