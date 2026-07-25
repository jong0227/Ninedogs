import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/app_date_picker.dart';

/// 구독 이력 한 구간을 넣거나 고치거나 지운다.
///
/// 끊었다 다시 구독한 기록을 손으로 바로잡을 수 있어야 한다. '다시 구독'
/// 만으로는 잘못 넣은 구간을 되돌릴 방법이 없었다.
///
/// [existing] 을 주면 그 구간을 고치는 것이고, 없으면 새로 넣는 것이다.
Future<void> showPeriodEditor(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription, {
  ({DateTime startedAt, DateTime? endedAt})? existing,
}) async {
  final periods = subscription.allPeriods;
  final isEditing = existing != null;

  var startedAt = existing?.startedAt ?? DateTime.now();
  var endedAt = existing?.endedAt;
  // 새로 넣는 구간은 기본을 '끝난 구간'으로 둔다. 진행 중인 구간은 보통
  // 이미 하나 있고, 과거 기록을 채워 넣는 게 이 화면의 주 용도다.
  var ongoing = isEditing ? existing.endedAt == null : false;

  final priceController = TextEditingController(
    text: _amountText(subscription.priceAt(startedAt)),
  );

  final result = await showModalBottomSheet<_PeriodResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setState) {
          final theme = Theme.of(sheetContext);

          Future<void> pickStart() async {
            final picked = await pickDate(
              sheetContext,
              initialDate: startedAt,
              firstDate: DateTime(2010),
              lastDate: DateTime.now(),
              helpText: '구독을 시작한 날',
            );
            if (picked == null) return;
            setState(() {
              startedAt = picked;
              // 끝이 시작보다 앞서면 말이 안 된다.
              if (endedAt != null && endedAt!.isBefore(picked)) {
                endedAt = picked;
              }
              priceController.text = _amountText(
                subscription.priceAt(picked),
              );
            });
          }

          Future<void> pickEnd() async {
            final picked = await pickDate(
              sheetContext,
              initialDate: endedAt ?? DateTime.now(),
              firstDate: startedAt,
              lastDate: DateTime.now(),
              helpText: '구독을 끊은 날',
            );
            if (picked != null) setState(() => endedAt = picked);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditing ? '구독 이력 수정' : '구독 이력 추가',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '언제부터 언제까지 구독했는지와 그때 요금을 넣어주세요. '
                    '그 기간에만 결제된 것으로 계산해요.',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _DateRow(
                    label: '시작한 날',
                    value: formatDate(startedAt),
                    onTap: pickStart,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('아직 구독 중이에요'),
                    subtitle: Text(
                      ongoing ? '끝나지 않은 구간이에요' : '끊은 날을 정해주세요',
                      style: theme.textTheme.labelMedium,
                    ),
                    value: ongoing,
                    activeThumbColor: AppColors.accent,
                    onChanged: (on) => setState(() {
                      ongoing = on;
                      if (!on) endedAt ??= DateTime.now();
                    }),
                  ),
                  if (!ongoing) ...[
                    _DateRow(
                      label: '끊은 날',
                      value: endedAt == null ? '고르기' : formatDate(endedAt!),
                      onTap: pickEnd,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  Text('이 기간 구독료', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: priceController,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.displaySmall,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      suffixText: subscription.currency,
                      suffixStyle: theme.textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '시작한 날부터 이 금액이 적용돼요. 이후 구간에서 다른 금액을 '
                    '넣으면 그때부터 새 금액으로 바뀌어요.',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  FilledButton(
                    onPressed: (!ongoing && endedAt == null)
                        ? null
                        : () => Navigator.pop(
                            sheetContext,
                            _PeriodResult.save(
                              startedAt,
                              ongoing ? null : endedAt,
                            ),
                          ),
                    child: Text(isEditing ? '저장' : '추가'),
                  ),
                  // 구간이 하나뿐이면 지울 수 없다. 구독에는 최소 한 구간이
                  // 있어야 시작일과 누적 지출을 계산할 수 있다.
                  if (isEditing && periods.length > 1) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        const _PeriodResult.delete(),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.negative,
                      ),
                      child: const Text('이 이력 삭제'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  final price = Money.tryParse(
    priceController.text,
    currency: subscription.currency,
  );
  priceController.dispose();

  if (result == null) return;

  final notifier = ref.read(subscriptionsProvider.notifier);

  // 고치는 경우엔 원래 구간을 빼고 새 값을 넣는다. 시작일로 찾는다 —
  // 같은 날 시작하는 구간이 둘일 수는 없다.
  final next = [
    for (final period in periods)
      if (!(isEditing && _sameDay(period.startedAt, existing.startedAt)))
        period,
    if (!result.delete)
      (startedAt: result.startedAt!, endedAt: result.endedAt),
  ];

  await notifier.setPeriods(subscription.id, next);

  // 구간의 요금은 시작일에 걸린 가격 이력으로 남긴다.
  if (!result.delete && price != null) {
    await notifier.upsertPriceHistoryPoint(
      subscription.id,
      PricePoint(effectiveFrom: result.startedAt!, amount: price),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _PeriodResult {
  const _PeriodResult.save(this.startedAt, this.endedAt) : delete = false;
  const _PeriodResult.delete()
    : startedAt = null,
      endedAt = null,
      delete = true;

  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool delete;
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(label, style: theme.textTheme.labelMedium),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.event_outlined,
              size: 16,
              color: theme.textTheme.labelMedium?.color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(value, style: theme.textTheme.bodyMedium),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.textTheme.labelMedium?.color,
            ),
          ],
        ),
      ),
    );
  }
}

String _amountText(Money money) => money.decimalDigits == 0
    ? money.major.toStringAsFixed(0)
    : money.major.toStringAsFixed(2);
