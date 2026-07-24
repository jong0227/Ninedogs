import 'package:intl/intl.dart';

final _date = DateFormat('yyyy.MM.dd', 'ko_KR');
final _monthDay = DateFormat('M월 d일', 'ko_KR');

String formatDate(DateTime date) => _date.format(date);

String formatMonthDay(DateTime date) => _monthDay.format(date);

/// 남은 일수를 사람이 읽는 말로. 예: "오늘", "내일", "3일 뒤"
String formatDaysAway(int days) {
  if (days == 0) return '오늘';
  if (days == 1) return '내일';
  if (days < 0) return '${-days}일 지남';
  return '$days일 뒤';
}

/// 구독을 유지한 기간. 예: "1년 2개월째"
String formatDuration(DateTime since, [DateTime? until]) {
  final end = until ?? DateTime.now();
  var months =
      (end.year - since.year) * 12 + (end.month - since.month);
  if (end.day < since.day) months -= 1;
  if (months < 1) return '${end.difference(since).inDays}일째';

  final years = months ~/ 12;
  final remainder = months % 12;
  if (years == 0) return '$remainder개월째';
  if (remainder == 0) return '$years년째';
  return '$years년 $remainder개월째';
}
