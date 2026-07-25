import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/app_date_picker.dart';

/// 해지했던 구독을 다시 시작한다.
///
/// 날짜와 금액을 함께 받는다. 다시 구독할 때 요금이 그 사이 올라 있는 경우가
/// 많은데, 예전 금액 그대로 두면 앞으로의 누적 지출이 계속 틀어진다.
Future<void> showResubscribeSheet(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final controller = TextEditingController(
    text: _amountText(subscription.currentPrice),
  );
  var startedAt = DateTime.now();

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      // 키보드가 올라와도 입력칸이 가리지 않게 한다.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setState) {
          final theme = Theme.of(sheetContext);

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
                    '${subscription.name} 다시 구독',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '끊었던 기간은 이력에 남고, 그동안은 결제가 없었던 것으로 계산해요.',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text('다시 시작한 날', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () async {
                      final picked = await pickDate(
                        sheetContext,
                        initialDate: startedAt,
                        // 끊은 날보다 앞설 수는 없다.
                        firstDate: subscription.canceledAt ?? DateTime(2010),
                        lastDate: DateTime.now(),
                        helpText: '다시 구독을 시작한 날',
                      );
                      if (picked != null) setState(() => startedAt = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 18,
                            color: theme.textTheme.labelMedium?.color,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            formatDate(startedAt),
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
                  const SizedBox(height: AppSpacing.lg),

                  Text('지금 구독료', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: controller,
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
                    '그 사이 요금이 올랐다면 새 금액을 넣어주세요. '
                    '예전 기록은 옛 금액 그대로 남아요.',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('다시 구독 시작'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  final price = Money.tryParse(
    controller.text,
    currency: subscription.currency,
  );
  controller.dispose();

  if (confirmed != true) return;

  await ref
      .read(subscriptionsProvider.notifier)
      .resubscribe(subscription.id, startedAt: startedAt, price: price);
}

String _amountText(Money money) => money.decimalDigits == 0
    ? money.major.toStringAsFixed(0)
    : money.major.toStringAsFixed(2);
