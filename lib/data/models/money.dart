import 'package:intl/intl.dart';

/// 금액. 통화의 최소 단위(원, 센트)를 정수로 담는다.
/// double 로 돈을 다루면 누적 합계에서 오차가 생기므로 정수로 고정한다.
class Money implements Comparable<Money> {
  const Money(this.minor, {this.currency = krw});

  /// 통화의 최소 단위 값. KRW 는 원, USD 는 센트.
  final int minor;
  final String currency;

  static const krw = 'KRW';

  /// 소수점 자리가 없는 통화들.
  static const _zeroDecimalCurrencies = {'KRW', 'JPY', 'VND', 'CLP'};

  int get decimalDigits => _zeroDecimalCurrencies.contains(currency) ? 0 : 2;

  static Money zero([String currency = krw]) => Money(0, currency: currency);

  bool get isZero => minor == 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minor + other.minor, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minor - other.minor, currency: currency);
  }

  Money operator *(int factor) => Money(minor * factor, currency: currency);

  /// 반올림해서 나눈다. 월 환산 금액처럼 딱 떨어지지 않는 계산에 쓴다.
  Money dividedBy(num divisor) =>
      Money((minor / divisor).round(), currency: currency);

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minor.compareTo(other.minor);
  }

  void _assertSameCurrency(Money other) {
    assert(
      other.currency == currency,
      '통화가 다른 금액끼리는 연산할 수 없습니다: $currency vs ${other.currency}',
    );
  }

  /// 사람이 입력·확인하는 단위. KRW 13500 -> 13500.0, USD 999 -> 9.99
  double get major => minor / _pow10(decimalDigits);

  /// 입력창의 문자열을 금액으로. 숫자로 읽을 수 없으면 null.
  static Money? tryParse(String text, {String currency = krw}) {
    final cleaned = text.replaceAll(RegExp(r'[,\s₩$]'), '');
    if (cleaned.isEmpty) return null;

    final value = double.tryParse(cleaned);
    if (value == null || value.isNegative) return null;

    final digits = _zeroDecimalCurrencies.contains(currency) ? 0 : 2;
    return Money((value * _pow10(digits)).round(), currency: currency);
  }

  /// 통화만 바꾼다. 금액의 자릿수 의미가 달라지므로 값도 다시 맞춘다.
  /// (13,500원 -> $135.00 이 아니라 $13,500.00 이 되지 않도록)
  Money convertedTo(String newCurrency) {
    if (newCurrency == currency) return this;
    final newDigits = _zeroDecimalCurrencies.contains(newCurrency) ? 0 : 2;
    return Money(
      (major * _pow10(newDigits)).round(),
      currency: newCurrency,
    );
  }

  String format({String? locale}) {
    return NumberFormat.simpleCurrency(
      locale: locale ?? (currency == krw ? 'ko_KR' : null),
      name: currency,
      decimalDigits: decimalDigits,
    ).format(minor / _pow10(decimalDigits));
  }

  static int _pow10(int exp) {
    var result = 1;
    for (var i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }

  Map<String, Object?> toJson() => {'minor': minor, 'currency': currency};

  factory Money.fromJson(Map<String, Object?> json) => Money(
    (json['minor'] as num).toInt(),
    currency: json['currency'] as String? ?? krw,
  );

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => format();
}
