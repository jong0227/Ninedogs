import 'package:intl/intl.dart';

/// 통화가 다른 금액끼리 연산하려 했을 때.
///
/// 버그를 드러내려고 있는 것이지 사용자에게 보여주려고 있는 게 아니다.
/// 이게 던져졌다면 환산 없이 더한 자리가 어딘가 있다는 뜻이다.
class CurrencyMismatchError extends Error {
  CurrencyMismatchError(this.left, this.right);

  final String left;
  final String right;

  @override
  String toString() => '통화가 다른 금액끼리는 연산할 수 없습니다: $left vs $right';
}

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

  /// 통화가 다르면 **던진다.** 예전엔 assert 였다.
  ///
  /// assert 는 릴리즈 빌드에서 통째로 제거된다. 개발 중에는 크래시로 잡히니
  /// 안전해 보였지만, 정작 사용자 기기에서는 검사 자체가 사라져서 13,500원과
  /// $1.00 를 더해 13,501원을 내놓았다. 아무 경고 없이 숫자만 틀린다.
  ///
  /// 돈 계산은 조용히 틀리느니 드러나게 실패하는 편이 낫다. 통화가 섞일 수
  /// 있는 자리(누적 지출 등)는 애초에 환율로 환산해서 더한다.
  void _assertSameCurrency(Money other) {
    if (other.currency == currency) return;
    throw CurrencyMismatchError(currency, other.currency);
  }

  /// 사람이 입력·확인하는 단위. KRW 13500 -> 13500.0, USD 999 -> 9.99
  double get major => minor / _pow10(decimalDigits);

  /// 금액 입력창에 채워 넣을 문자열. 통화 기호도 천 단위 구분도 없는 숫자만.
  ///
  /// 원화는 소수점을 붙이지 않고(13500), 달러는 두 자리를 붙인다(9.99).
  /// 편집 화면마다 똑같은 함수를 복사해 두고 있었다.
  String get inputText =>
      decimalDigits == 0 ? major.toStringAsFixed(0) : major.toStringAsFixed(2);

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
    return Money((major * _pow10(newDigits)).round(), currency: newCurrency);
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

  /// 실제 환율로 원화 환산한 값. [usdToKrwRate] 는 "1달러 = 원화 얼마".
  ///
  /// [convertedTo] 와 다르다 — 그건 숫자는 그대로 두고 통화 표기만 바꾸는
  /// 것이고, 이건 환율을 곱해 실제 가치를 옮긴다. 이미 원화면 그대로 둔다.
  /// 이 앱이 실제로 받는 통화는 KRW·USD 뿐이라 USD 만 다룬다.
  Money toKrw(double usdToKrwRate) {
    if (currency == krw) return this;
    if (currency != 'USD') return this;
    return Money((major * usdToKrwRate).round(), currency: krw);
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
