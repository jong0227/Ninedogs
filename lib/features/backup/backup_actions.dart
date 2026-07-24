import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/backup/backup_file.dart';
import '../../providers/backup_providers.dart';

/// 백업 파일을 만들어 공유 시트로 넘긴다. 카톡 '나에게 보내기' 로 보내두면
/// 나중에 그 파일을 눌러서 그대로 복원할 수 있다.
Future<void> exportBackup(
  BuildContext context,
  WidgetRef ref, {
  required bool includeCredentials,
}) async {
  final backup = await ref
      .read(backupServiceProvider)
      .export(includeCredentials: includeCredentials);

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/${backup.suggestedFileName}');
  await file.writeAsString(backup.encode());

  if (!context.mounted) return;

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Ninedogs 백업 ${formatDate(backup.exportedAt)}',
    ),
  );
}

/// 내보낼 때 계정 정보를 넣을지 고른다.
///
/// 기본은 넣지 않는 쪽이다. 카톡으로 주고받는 파일이라 계정 정보가 들어가면
/// 대화방에 암호문이 남는다. 암호화돼 있어도 굳이 흘릴 이유가 없다.
Future<void> showExportSheet(BuildContext context, WidgetRef ref) async {
  final theme = Theme.of(context);

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('백업 내보내기', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '파일로 만들어서 카톡이나 메일로 보내둘 수 있어요. '
              '나중에 그 파일을 누르면 이 앱에서 바로 복원돼요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.labelMedium?.color,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('구독 목록만'),
              subtitle: Text(
                '계정 정보는 빼요. 주고받기에 안전해요',
                style: theme.textTheme.labelMedium,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                exportBackup(context, ref, includeCredentials: false);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: const Text('계정 정보까지'),
              subtitle: Text(
                '암호화된 상태로 담겨요. 복원하려면 마스터 암호가 필요해요',
                style: theme.textTheme.labelMedium,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                exportBackup(context, ref, includeCredentials: true);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// 백업 내용을 받아 확인을 거친 뒤 합친다.
///
/// 기존 데이터를 지우지 않는다. 같은 구독은 갱신하고 없던 것만 추가한다.
Future<void> confirmAndImport(
  BuildContext context,
  WidgetRef ref,
  String raw,
) async {
  final BackupFile backup;
  try {
    backup = BackupFile.decode(raw);
  } on BackupFormatException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return;
  }

  if (!context.mounted) return;

  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: const Text('백업을 가져올까요?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatDate(backup.exportedAt)}에 만든 백업이에요.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('· 구독 ${backup.subscriptions.length}개'),
                if (backup.includesCredentials)
                  Text('· 계정 정보 ${backup.credentials.length}개'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '지금 있는 데이터는 지우지 않아요. 같은 구독은 백업 내용으로 '
                  '바뀌고, 없던 것만 새로 추가돼요.',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('가져오기'),
              ),
            ],
          );
        },
      ) ??
      false;

  if (!confirmed || !context.mounted) return;

  final result = await ref.read(backupServiceProvider).import(backup);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.summary), duration: const Duration(seconds: 3)),
  );

  final skipped = result.credentialsSkippedReason;
  if (skipped != null && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('계정 정보는 가져오지 못했어요'),
        content: Text(skipped),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

/// 설정 화면에서 복원 방법을 알려주는 안내.
class ImportHowTo extends StatelessWidget {
  const ImportHowTo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.download_outlined,
            size: 18,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('복원하는 방법', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '카톡이나 메일에서 백업 파일(.json)을 누르고 '
                  'Ninedogs로 열기를 선택하면 돼요.',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
