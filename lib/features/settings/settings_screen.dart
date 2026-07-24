import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/update/update_checker.dart';
import '../../providers/app_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/reset_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/vault_providers.dart';
import '../backup/backup_actions.dart';
import '../notifications/reminder_picker.dart';
import '../vault/vault_sheets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _checking = false;
  UpdateResult? _result;

  Future<void> _checkForUpdate() async {
    setState(() {
      _checking = true;
      _result = null;
    });

    final version = await ref.read(appVersionProvider.future);
    final result = await ref.read(updateCheckerProvider).check(version);

    if (mounted) {
      setState(() {
        _checking = false;
        _result = result;
      });
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('브라우저를 열지 못했어요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider);
    final vault = ref.watch(vaultProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          _SectionTitle('앱'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('버전'),
            trailing: Text(
              version.when(
                data: (value) => value,
                loading: () => '...',
                error: (_, _) => '알 수 없음',
              ),
              style: theme.textTheme.labelMedium,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('업데이트 확인'),
            subtitle: Text(
              '새 버전이 나왔는지 알아봐요',
              style: theme.textTheme.labelMedium,
            ),
            trailing: _checking
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onTap: _checking ? null : _checkForUpdate,
          ),
          if (_result != null) _UpdateResultCard(result: _result!, onOpen: _open),

          const SizedBox(height: AppSpacing.xl),
          _SectionTitle('결제 알림'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '결제 며칠 전에 알려드릴까요? 여러 개 고를 수 있어요.',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ReminderDayPicker(
            selected: ref.watch(reminderDaysProvider),
            onToggle: (days) =>
                ref.read(reminderDaysProvider.notifier).toggle(days),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${describeReminders(ref.watch(reminderDaysProvider))} · '
            '구독마다 따로 정할 수도 있어요',
            style: theme.textTheme.labelMedium,
          ),

          const SizedBox(height: AppSpacing.xl),
          _SectionTitle('화면'),
          const SizedBox(height: AppSpacing.sm),
          const _ThemeModePicker(),

          if (vault is! VaultUninitialized) ...[
            const SizedBox(height: AppSpacing.xl),
            _SectionTitle('보안'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('마스터 암호 변경'),
              subtitle: Text(
                '저장된 계정 정보를 새 암호로 다시 암호화해요',
                style: theme.textTheme.labelMedium,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final changed = await showVaultChangePasswordSheet(context);
                if (changed && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('마스터 암호를 바꿨어요')),
                  );
                }
              },
            ),
            if (ref.watch(biometricAvailableProvider).value ?? false)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('지문·얼굴로 열기'),
                subtitle: Text(
                  vault is VaultUnlocked
                      ? '열쇠는 이 기기 안에만 저장돼요'
                      : '금고를 먼저 열어야 켤 수 있어요',
                  style: theme.textTheme.labelMedium,
                ),
                value: ref.watch(biometricEnabledProvider).value ?? false,
                activeThumbColor: AppColors.accent,
                // 켜려면 지금 열려 있어야 한다. 저장할 열쇠가 메모리에 있어야
                // 하기 때문이다. 끄는 건 언제든 된다.
                onChanged:
                    (vault is VaultUnlocked ||
                        (ref.watch(biometricEnabledProvider).value ?? false))
                    ? (on) async {
                        final notifier = ref.read(vaultProvider.notifier);
                        if (on) {
                          await notifier.enableBiometrics();
                        } else {
                          await notifier.disableBiometrics();
                        }
                      }
                    : null,
              ),
            if (vault is VaultUnlocked)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('금고 잠그기'),
                subtitle: Text(
                  '계정 정보를 다시 보려면 암호를 입력해야 해요',
                  style: theme.textTheme.labelMedium,
                ),
                trailing: const Icon(Icons.lock_outline),
                onTap: () {
                  ref.read(vaultProvider.notifier).lock();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('금고를 잠갔어요')),
                  );
                },
              ),
          ],

          const SizedBox(height: AppSpacing.xl),
          _SectionTitle('백업'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('백업 내보내기'),
            subtitle: Text(
              '파일로 만들어 카톡이나 메일로 보내둘 수 있어요',
              style: theme.textTheme.labelMedium,
            ),
            trailing: const Icon(Icons.ios_share),
            onTap: () => showExportSheet(context, ref),
          ),
          const SizedBox(height: AppSpacing.sm),
          const ImportHowTo(),

          const SizedBox(height: AppSpacing.xl),
          _SectionTitle('위험'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '모든 데이터 초기화',
              style: TextStyle(color: AppColors.negative),
            ),
            subtitle: Text(
              '구독 기록과 계정 정보를 전부 지우고 처음 상태로 되돌려요',
              style: theme.textTheme.labelMedium,
            ),
            trailing: const Icon(
              Icons.delete_forever_outlined,
              color: AppColors.negative,
            ),
            onTap: _confirmAndReset,
          ),
        ],
      ),
    );
  }

  /// 실수로 눌러도 바로 지워지지 않도록 두 단계를 둔다.
  /// 확인 창을 띄우고, 거기서 '초기화'를 직접 입력해야 버튼이 활성화된다.
  Future<void> _confirmAndReset() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => const _ResetConfirmDialog(),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    await ref.read(appResetProvider).everything();
    if (!mounted) return;

    // 초기화하면 온보딩부터 다시 시작한다. 쌓아둔 화면들을 걷어내야
    // 지워진 구독의 상세 화면 같은 게 남지 않는다.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ResetConfirmDialog extends ConsumerStatefulWidget {
  const _ResetConfirmDialog();

  @override
  ConsumerState<_ResetConfirmDialog> createState() =>
      _ResetConfirmDialogState();
}

class _ResetConfirmDialogState extends ConsumerState<_ResetConfirmDialog> {
  final _input = TextEditingController();

  /// 손이 미끄러져서 눌리는 일이 없도록 직접 입력하게 하는 문구.
  static const _phrase = '초기화';

  bool get _matches => _input.text.trim() == _phrase;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptions = ref.watch(allSubscriptionsProvider);
    final credentialCount = ref
        .watch(storedCredentialsProvider)
        .value
        ?.length ??
        0;

    return AlertDialog(
      title: const Text('모든 데이터를 지울까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '아래 항목이 모두 사라지고 되돌릴 수 없어요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _Bullet('구독 ${subscriptions.length}개와 지금까지의 누적 지출 기록'),
          if (credentialCount > 0) _Bullet('저장한 계정 정보 $credentialCount개'),
          const _Bullet('마스터 암호 설정'),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "계속하려면 아래에 '$_phrase'라고 입력해주세요.",
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _input,
            autocorrect: false,
            decoration: const InputDecoration(hintText: _phrase),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.negative,
            disabledForegroundColor: theme.disabledColor,
          ),
          child: const Text('영구 삭제'),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('· '),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _ThemeModePicker extends ConsumerWidget {
  const _ThemeModePicker();

  static const _labels = {
    ThemeMode.dark: '어둡게',
    ThemeMode.light: '밝게',
    ThemeMode.system: '시스템 설정',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(themeModeProvider);

    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final entry in _labels.entries)
          GestureDetector(
            onTap: () => ref.read(themeModeProvider.notifier).set(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: entry.key == current
                    ? AppColors.accent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: entry.key == current
                      ? AppColors.accent
                      : theme.dividerColor,
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: entry.key == current
                      ? AppColors.onAccent
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UpdateResultCard extends StatelessWidget {
  const _UpdateResultCard({required this.result, required this.onOpen});

  final UpdateResult result;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: switch (result) {
          UpdateAvailable(:final release) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '새 버전 ${release.version}이 나왔어요',
                style: theme.textTheme.titleMedium,
              ),
              if (release.notes != null && release.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  release.notes!.trim(),
                  style: theme.textTheme.labelMedium,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => onOpen(release.apkUrl ?? release.pageUrl),
                child: const Text('받으러 가기'),
              ),
            ],
          ),
          UpToDate() => Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppColors.positive,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('최신 버전을 쓰고 있어요', style: theme.textTheme.bodyMedium),
            ],
          ),
          UpdateCheckFailed(:final reason) => Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.textTheme.labelMedium?.color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(reason, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
  );
}
