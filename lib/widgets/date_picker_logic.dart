/// 날짜 선택기의 계산만 모아둔 곳.
///
/// 격자 배치와 범위 판정은 위젯 없이도 확인할 수 있어야 한다. 말일이나
/// 범위 경계에서 틀리면 고를 수 없는 날이 생기는데, 화면을 띄워야만 알 수
/// 있으면 놓치기 쉽다.
library;

/// 시분초를 뗀 날짜.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// 날짜만 비교한다. 같은 날이면 0.
int compareDate(DateTime a, DateTime b) => dateOnly(a).compareTo(dateOnly(b));

/// [date] 가 [first] 와 [last] 사이(양끝 포함)인지.
bool isDateInRange(DateTime date, DateTime first, DateTime last) =>
    compareDate(date, first) >= 0 && compareDate(date, last) <= 0;

/// 그 달의 날 수. 다음 달 0일이 이번 달 말일이다.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 달력 첫 줄에서 1일 앞에 비워둘 칸 수.
///
/// DateTime 의 weekday 는 월=1..일=7. 일요일 시작 달력이라 7을 0으로 옮긴다.
int leadingBlanks(int year, int month) => DateTime(year, month).weekday % 7;

/// [month] 달에 고를 수 있는 날이 하루라도 있는지.
///
/// 범위 밖의 달은 눌러봐야 고를 게 없으니 흐리게 둔다.
bool monthHasSelectableDay(DateTime month, DateTime first, DateTime last) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(
    month.year,
    month.month,
    daysInMonth(month.year, month.month),
  );
  return compareDate(end, first) >= 0 && compareDate(start, last) <= 0;
}

/// 달을 옮겼을 때 고를 날.
///
/// 원래 고른 날(1월 31일)을 짧은 달(2월)로 가져가면 그 달 말일로 당긴다.
/// 그러고도 범위 밖이면 범위 안쪽 끝으로 민다 — 달을 옮겼는데 아무것도
/// 선택되지 않은 상태가 되면 '선택' 버튼이 무엇을 저장할지 알 수 없다.
DateTime clampToMonth(
  int desiredDay,
  DateTime month,
  DateTime first,
  DateTime last,
) {
  final lastDay = daysInMonth(month.year, month.month);
  final day = desiredDay > lastDay ? lastDay : desiredDay;
  final candidate = DateTime(month.year, month.month, day);

  if (compareDate(candidate, first) < 0) return dateOnly(first);
  if (compareDate(candidate, last) > 0) return dateOnly(last);
  return candidate;
}

/// 앞뒤로 달을 옮길 수 있는지. 범위를 벗어나면 화살표를 죽인다.
bool canShiftMonth(DateTime month, int delta, DateTime first, DateTime last) =>
    monthHasSelectableDay(
      DateTime(month.year, month.month + delta),
      first,
      last,
    );

/// "20190315" 같은 숫자 8자리를 날짜로. 형식이나 범위가 어긋나면 null.
///
/// 달력으로 한참 넘어가는 대신 아는 날짜를 그냥 쳐 넣을 수 있어야 한다.
DateTime? parseCompactDate(String text, DateTime first, DateTime last) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return null;

  final year = int.parse(digits.substring(0, 4));
  final month = int.parse(digits.substring(4, 6));
  final day = int.parse(digits.substring(6, 8));

  if (month < 1 || month > 12) return null;
  if (day < 1 || day > daysInMonth(year, month)) return null;

  final parsed = DateTime(year, month, day);
  return isDateInRange(parsed, first, last) ? parsed : null;
}
