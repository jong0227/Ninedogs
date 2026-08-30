import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/usage_providers.dart';

/// '안 쓰는 구독 찾기' 스위치와 그 한계 안내.
///
/// 이 기능은 폰 사용 기록만 본다. TV·PC 로 보는 건 잡히지 않으므로
/// 켜기 전에 그 점을 분명히 알려야 한다. 안 그러면 매일 TV 로 보는 넷플릭스를
/// "안 쓴다"고 오해하게 된다.
class UsageTrackingTile extends ConsumerWidget {
  const UsageTrackingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = ref.watch(usageTrackingProvider);
    final granted = ref.watch(usagePermissionProvider).value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('한동안 안 연 구독 알려주기'),
          subtitle: Text(
            enabled
                ? (granted ? '폰에서 30일 넘게 안 연 구독을 통계에 표시해요' : '권한이 꺼져 있어요')
                : '폰 사용 기록을 보고 안 쓰는 구독을 찾아드려요',
            style: theme.textTheme.labelMedium,
          ),
          value: enabled,
          activeThumbColor: AppColors.accent,
          onChanged: (on) async {
            await ref.read(usageTrackingProvider.notifier).set(on);
            if (!on) return;

            // 켰는데 권한이 없으면 설정으로 데려다준다.
            final has = await ref.read(usageServiceProvider).hasPermission();
            if (has || !context.mounted) {
              ref.invalidate(usagePermissionProvider);
              return;
            }
            final go = await _explain(context);
            if (go) await ref.read(usageServiceProvider).openSettings();
            ref.invalidate(usagePermissionProvider);
          },
        ),
        if (enabled && !granted)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(usageServiceProvider).openSettings();
                ref.invalidate(usagePermissionProvider);
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('설정에서 사용 정보 접근 켜기'),
            ),
          ),
        if (enabled) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.textTheme.labelMedium?.color,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'TV나 PC로 보는 건 알 수 없어요. 폰에서 안 열었다고 '
                    '안 쓰는 건 아니니 참고만 해주세요.',
                    style: theme.textTheme.labelMedium?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 권한이 왜 필요하고 무엇을 못 보는지 알린 뒤 설정으로 보낼지 묻는다.
  static Future<bool> _explain(BuildContext context) async {
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.history_toggle_off,
          color: AppColors.accent,
          size: 30,
        ),
        title: const Text('사용 정보 접근이 필요해요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '구독 서비스 앱을 마지막으로 언제 열었는지 보려면 안드로이드 '
              '설정에서 직접 켜야 해요.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '설정 → 특별한 앱 접근 → 사용 정보 접근 → Ninedogs',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '읽는 건 앱을 마지막으로 연 시각뿐이에요. 무엇을 봤는지는 '
              '알 수 없고, 이 기기 밖으로 나가지 않아요.',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.labelMedium?.color,
            ),
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
