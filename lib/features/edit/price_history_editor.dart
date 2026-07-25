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

/// 가격 이력에 과거 시점 하나를 추가하거나 고친다.
///
/// [recordPriceChange]/[correctLatestPrice] 는 "지금" 기준이라, 처음 등록할
/// 때 놓친 과거 변동("이 달부터는 얼마였다")을 나중에 채우려면 이 화면이
/// 필요하다. 날짜를 이미 있는 항목과 같게 고르면 그 항목을 고치는 셈이 된다.
Future<void> showPriceHistoryEditor(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription, {
  PricePoint? existing,
}) async {
  final controller = TextEditingController(
    text: existing == null ? '' : _amountText(existing.amount),
  );
  var pickedDate = existing?.effectiveFrom ?? subscription.startedAt;

  final result = await showDialog<_PriceHistoryResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final theme = Theme.of(dialogContext);

        Future<void> pickDateForPoint() async {
          final picked = await pickDate(
            dialogContext,
            initialDate: pickedDate,
            firstDate: subscription.startedAt,
            lastDate: DateTime.now(),
            helpText: '언제부터의 가격인가요?',
          );
          if (picked != null) setState(() => pickedDate = picked);
        }

        return AlertDialog(
          title: Text(existing == null ? '이전 가격 추가' : '가격 이력 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (existing == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text(
                    '특정 기간엔 다른 금액이었다면 여기서 채워 넣을 수 있어요. '
                    '누적 지출이 그 기간에 맞게 다시 계산돼요.',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              InkWell(
                onTap: pickDateForPoint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: theme.textTheme.labelMedium?.color,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${formatDate(pickedDate)}부터',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: theme.textTheme.labelMedium?.color,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                autofocus: existing == null,
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
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  const _PriceHistoryResult.delete(),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.negative,
                ),
                child: const Text('삭제'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                foregroundColor: theme.textTheme.labelMedium?.color,
              ),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final amount = Money.tryParse(
                  controller.text,
                  currency: subscription.currency,
                );
                if (amount == null) return;
                Navigator.pop(
                  dialogContext,
                  _PriceHistoryResult.save(pickedDate, amount),
                );
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  if (result == null) return;

  final notifier = ref.read(subscriptionsProvider.notifier);
  if (result.delete) {
    await notifier.removePriceHistoryPoint(
      subscription.id,
      existing!.effectiveFrom,
    );
    return;
  }

  await notifier.upsertPriceHistoryPoint(
    subscription.id,
    PricePoint(effectiveFrom: result.date!, amount: result.amount!),
  );
}

class _PriceHistoryResult {
  const _PriceHistoryResult.save(this.date, this.amount) : delete = false;
  const _PriceHistoryResult.delete() : date = null, amount = null, delete = true;

  final DateTime? date;
  final Money? amount;
  final bool delete;
}

String _amountText(Money money) => money.decimalDigits == 0
    ? money.major.toStringAsFixed(0)
    : money.major.toStringAsFixed(2);
