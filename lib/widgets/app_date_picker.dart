import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'date_picker_logic.dart';

/// 앱에서 날짜를 고를 때 쓰는 하나의 입구.
///
/// 기본 [showDatePicker] 를 쓰다가 직접 만들었다. 헤더의 "2026년 7월" 을
/// 눌러도 **연도만** 고를 수 있고 월은 못 골라서 (Flutter 가 월 선택 모드를
/// 제공하지 않는다), 구독 시작일처럼 몇 년 전 날짜를 넣으려면 화살표로
/// 달을 하나씩 넘겨야 했다. 2010년부터면 200번 가까이 눌러야 한다.
///
/// 그래서 세 가지로 나눴다.
/// - 달력: 기본. 최근 날짜는 이게 제일 빠르다.
/// - 연·월 격자: 헤더를 누르면 연도와 달을 함께 고른다. 먼 과거로 한 번에 간다.
/// - 직접 입력: 날짜를 이미 알고 있을 때. 결제 내역에서 확인하고 오는 흐름이라
///   생각보다 자주 쓰인다.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String helpText,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _AppDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    ),
  );
}

enum _Mode { day, yearMonth, input }

class _AppDatePickerDialog extends StatefulWidget {
  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  static final _headline = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');
  static final _monthLabel = DateFormat('yyyy년 M월', 'ko_KR');
  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  late DateTime _selected;
  late DateTime _month;
  late int _year;
  var _mode = _Mode.day;

  final _inputController = TextEditingController();
  String? _inputError;

  DateTime get _first => widget.firstDate;
  DateTime get _last => widget.lastDate;

  @override
  void initState() {
    super.initState();
    // 넘겨받은 날짜가 범위 밖일 수도 있다. 그대로 두면 고를 수 없는 날이
    // 선택된 채로 열린다.
    _selected = clampToMonth(
      widget.initialDate.day,
      DateTime(widget.initialDate.year, widget.initialDate.month),
      _first,
      _last,
    );
    _month = DateTime(_selected.year, _selected.month);
    _year = _selected.year;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _pickMonth(int month) {
    final target = DateTime(_year, month);
    setState(() {
      _month = target;
      _selected = clampToMonth(_selected.day, target, _first, _last);
      _mode = _Mode.day;
    });
  }

  void _toggleInput() {
    setState(() {
      if (_mode == _Mode.input) {
        _mode = _Mode.day;
        return;
      }
      _mode = _Mode.input;
      _inputError = null;
      _inputController.text = DateFormat('yyyyMMdd').format(_selected);
    });
  }

  void _onInputChanged(String text) {
    final parsed = parseCompactDate(text, _first, _last);
    setState(() {
      if (parsed != null) {
        _selected = parsed;
        _month = DateTime(parsed.year, parsed.month);
        _year = parsed.year;
        _inputError = null;
      } else {
        // 8자리를 다 치기 전엔 아직 틀렸다고 다그치지 않는다.
        final digits = text.replaceAll(RegExp(r'\D'), '');
        _inputError = digits.length < 8 ? null : '고를 수 없는 날짜예요';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(theme),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: switch (_mode) {
                  _Mode.day => _dayBody(theme),
                  _Mode.yearMonth => _yearMonthBody(theme),
                  _Mode.input => _inputBody(theme),
                },
              ),
            ),
            _actions(theme),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.helpText, style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _headline.format(_selected),
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleInput,
            tooltip: _mode == _Mode.input ? '달력으로 고르기' : '직접 입력',
            icon: Icon(
              _mode == _Mode.input
                  ? Icons.calendar_today_outlined
                  : Icons.edit_outlined,
              size: 20,
            ),
            color: _mode == _Mode.input
                ? AppColors.accent
                : theme.textTheme.labelMedium?.color,
          ),
        ],
      ),
    );
  }

  /// 달력. 위의 "2019년 3월" 을 누르면 연·월 격자로 넘어간다.
  Widget _dayBody(ThemeData theme) {
    final canBack = canShiftMonth(_month, -1, _first, _last);
    final canForward = canShiftMonth(_month, 1, _first, _last);

    final days = daysInMonth(_month.year, _month.month);
    final blanks = leadingBlanks(_month.year, _month.month);
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  _year = _month.year;
                  _mode = _Mode.yearMonth;
                }),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _monthLabel.format(_month),
                        style: theme.textTheme.titleMedium,
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: canBack ? () => _shiftMonth(-1) : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: '이전 달',
            ),
            IconButton(
              onPressed: canForward ? () => _shiftMonth(1) : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: '다음 달',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _weekdays[i],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: i == 0
                          ? AppColors.negative.withValues(alpha: 0.8)
                          : theme.textTheme.labelMedium?.color,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: blanks + days,
          itemBuilder: (context, index) {
            if (index < blanks) return const SizedBox.shrink();

            final day = index - blanks + 1;
            final date = DateTime(_month.year, _month.month, day);
            final enabled = isDateInRange(date, _first, _last);

            return _DayCell(
              day: day,
              enabled: enabled,
              selected: compareDate(date, _selected) == 0,
              isToday: compareDate(date, today) == 0,
              onTap: () => setState(() => _selected = date),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  /// 연도를 화살표로 옮기고 달은 격자에서 바로 고른다.
  /// 몇 년 전으로 가더라도 두세 번이면 닿는다.
  Widget _yearMonthBody(ThemeData theme) {
    final canBack = _year > _first.year;
    final canForward = _year < _last.year;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: canBack ? () => setState(() => _year--) : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: '이전 해',
            ),
            Text('$_year년', style: theme.textTheme.titleMedium),
            IconButton(
              onPressed: canForward ? () => setState(() => _year++) : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: '다음 해',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.9,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = index + 1;
            final enabled = monthHasSelectableDay(
              DateTime(_year, month),
              _first,
              _last,
            );
            final selected =
                _month.year == _year && _month.month == month;

            return _MonthCell(
              label: '$month월',
              enabled: enabled,
              selected: selected,
              onTap: () => _pickMonth(month),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _inputBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _inputController,
            autofocus: true,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onChanged: _onInputChanged,
            decoration: InputDecoration(
              hintText: '20190315',
              errorText: _inputError,
              helperText: '연월일 8자리',
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            // 입력이 틀린 채로 저장하면 엉뚱한 날이 들어간다.
            onPressed: _inputError != null
                ? null
                : () => Navigator.pop(context, _selected),
            child: const Text('선택'),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.enabled,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool enabled;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 22,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.accent : Colors.transparent,
            border: isToday && !selected
                ? Border.all(color: AppColors.accent, width: 1.2)
                : null,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppColors.onAccent
                  : enabled
                  ? theme.colorScheme.onSurface
                  : theme.textTheme.labelMedium?.color?.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? AppColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppColors.onAccent
                  : enabled
                  ? theme.colorScheme.onSurface
                  : theme.textTheme.labelMedium?.color?.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
