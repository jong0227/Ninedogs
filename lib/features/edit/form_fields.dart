import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/money.dart';

// 구독 편집 화면에서 쓰는 입력 부품들.

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.labelMedium),
  );
}

class DateRow extends StatelessWidget {
  const DateRow({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 18),
              const SizedBox(width: AppSpacing.md),
              Text(value, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(hint, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class CurrencyToggle extends StatelessWidget {
  const CurrencyToggle({
    super.key,
    required this.currency,
    required this.onChanged,
  });

  final String currency;
  final ValueChanged<String> onChanged;

  static const _options = [Money.krw, 'USD'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in _options)
            GestureDetector(
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: option == currency
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md - 1),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: option == currency
                        ? AppColors.accent
                        : theme.textTheme.labelMedium?.color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FormChip extends StatelessWidget {
  const FormChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? AppColors.accent : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.accent : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
