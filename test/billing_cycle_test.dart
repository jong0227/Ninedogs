import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';

void main() {
  group('addMonths', () {
    test('말일이 없는 달로 넘어가면 그 달 마지막 날로 맞춘다', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
    });

    test('해를 넘겨도 맞는다', () {
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(addMonths(DateTime(2026, 12, 1), 12), DateTime(2027, 12, 1));
    });

    test('31일 구독은 짧은 달을 지나도 31일로 돌아온다', () {
      // 2월에 28일로 당겨졌다가 3월에 다시 31일이 되는지 확인
      final feb = addMonths(DateTime(2026, 1, 31), 1);
      expect(feb, DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
    });
  });

  group('BillingCycle', () {
    test('월 환산 금액을 계산한다', () {
      expect(
        BillingCycle.yearly.monthlyEquivalent(const Money(120000)),
        const Money(10000),
      );
      expect(
        BillingCycle.monthly.monthlyEquivalent(const Money(13500)),
        const Money(13500),
      );
      expect(
        BillingCycle.quarterly.monthlyEquivalent(const Money(30000)),
        const Money(10000),
      );
    });

    test('다음 결제일을 구한다', () {
      expect(
        BillingCycle.monthly.next(DateTime(2026, 7, 24)),
        DateTime(2026, 8, 24),
      );
      expect(
        BillingCycle.weekly.next(DateTime(2026, 7, 24)),
        DateTime(2026, 7, 31),
      );
      expect(
        BillingCycle.yearly.next(DateTime(2026, 7, 24)),
        DateTime(2027, 7, 24),
      );
    });
  });
}
