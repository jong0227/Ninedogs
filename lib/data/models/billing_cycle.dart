import 'money.dart';

/// 결제 주기.
enum BillingCycle {
  weekly('매주', 7, 0),
  monthly('매월', 0, 1),
  quarterly('3개월마다', 0, 3),
  semiAnnual('6개월마다', 0, 6),
  yearly('매년', 0, 12);

  const BillingCycle(this.label, this.days, this.months);

  final String label;

  /// 일 단위 주기. months 가 0 일 때만 쓴다.
  final int days;

  /// 월 단위 주기. 0 이면 days 를 쓴다.
  final int months;

  /// 1년에 몇 번 청구되는지. 월 환산에 쓴다.
  double get chargesPerYear => months > 0 ? 12 / months : 365.25 / days;

  /// 이 주기로 [amount] 를 낼 때 월 평균 부담액.
  Money monthlyEquivalent(Money amount) =>
      amount.dividedBy(12 / chargesPerYear);

  /// [from] 다음 결제일.
  DateTime next(DateTime from) =>
      months > 0 ? addMonths(from, months) : from.add(Duration(days: days));
}

/// [months] 개월 뒤 날짜. 말일이 없는 달로 넘어가면 그 달의 마지막 날로 맞춘다.
/// (예: 1월 31일 + 1개월 = 2월 28일)
DateTime addMonths(DateTime date, int months) {
  final totalMonths = date.month - 1 + months;
  final year = date.year + (totalMonths ~/ 12);
  final month = totalMonths % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    date.day > lastDay ? lastDay : date.day,
    date.hour,
    date.minute,
  );
}
