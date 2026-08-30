import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/save_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/backup/snapshot_store.dart';
import '../../providers/subscription_providers.dart';

/// 최근 편집을 되돌린다.
///
/// 이 앱의 데이터는 손으로 넣은 것이라 날아가면 재입력 말고는 방법이 없다.
/// 실제로 편집 화면 버그로 구독 이력이 통째로 사라진 적이 있는데 복구 경로가
/// 아예 없었다. 코드 버그는 고쳤지만 잘못 지우거나 잘못 초기화하는 실수는
/// 여전히 남는다.
Future<void> showRestoreSheet(BuildContext context, WidgetRef ref) async {
  final snapshots = await ref.read(snapshotsProvider.future);
  if (!context.mounted) return;

  if (snapshots.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('되돌릴 지점이 아직 없어요')));
    return;
  }

  final picked = await showModalBottomSheet<SubscriptionSnapshot>(
    context: context,
    builder: (sheetContext) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('되돌리기', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '고르면 그때의 구독 목록으로 돌아가요. 지금 상태도 되돌릴 지점으로 '
                '남겨두니까 다시 앞으로 올 수 있어요.',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final snapshot in snapshots) ...[
                _SnapshotRow(
                  snapshot: snapshot,
                  onTap: () => Navigator.pop(sheetContext, snapshot),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      );
    },
  );

  if (picked == null || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('이 지점으로 되돌릴까요?'),
      content: Text(
        '${_when(picked.savedAt)}의 구독 ${picked.count}개로 돌아가요. '
        '그 뒤에 넣거나 고친 내용은 사라져요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('되돌리기'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final ok = await guardSave(
    context,
    () => ref.read(subscriptionsProvider.notifier).restore(picked),
  );

  if (ok) {
    messenger.showSnackBar(
      SnackBar(content: Text('구독 ${picked.count}개로 되돌렸어요')),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.snapshot, required this.onTap});

  final SubscriptionSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 18,
                color: theme.textTheme.labelMedium?.color,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '구독 ${snapshot.count}개',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _when(snapshot.savedAt),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// 얼마나 전인지. 오늘이면 시각만, 그 전이면 날짜까지.
String _when(DateTime at) {
  final now = DateTime.now();
  final elapsed = now.difference(at);

  if (elapsed.inMinutes < 1) return '방금';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}분 전';

  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  if (sameDay) return '오늘 ${DateFormat('HH:mm').format(at)}';

  return DateFormat('M월 d일 HH:mm', 'ko_KR').format(at);
}
