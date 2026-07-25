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
import '../../providers/sync_providers.dart';
import '../../providers/usage_providers.dart';
import '../../providers/vault_providers.dart';
import '../../widgets/ninedogs_app_bar.dart';
import '../backup/backup_actions.dart';
import '../notifications/reminder_picker.dart';
import '../sync/sync_screen.dart';
import '../vault/vault_sheets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _checking = false;
  UpdateResult? _result;

  // 업데이트 내려받기·설치 진행 상태
  bool _installing = false;
  double _installProgress = 0;
  String? _installError;

  @override
  void initState() {
    super.initState();
    // 설정을 열면(=앱을 켜면) 조용히 새 버전이 있는지 자동으로 확인한다.
    // 결과가 있을 때만 카드로 보여주므로 최신이면 티가 나지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkForUpdate(silent: true);
    });
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    setState(() {
      _checking = true;
      if (!silent) _result = null;
    });

    final version = await ref.read(appVersionProvider.future);
    final result = await ref.read(updateCheckerProvider).check(version);

    if (mounted) {
      setState(() {
        _checking = false;
        // 자동 확인은 새 버전이 있을 때만 카드를 띄운다. 최신이거나 확인
        // 실패면 사용자가 직접 누르기 전까지 조용히 둔다.
        if (!silent || result is UpdateAvailable) _result = result;
      });
    }
  }

  /// 새 APK 를 받아 설치기를 연다. apkUrl 이 없으면 릴리즈 페이지를 대신 연다.
  Future<void> _downloadAndInstall(AppRelease release) async {
    final apkUrl = release.apkUrl;
    if (apkUrl == null) {
      await _open(release.pageUrl);
      return;
    }

    setState(() {
      _installing = true;
      _installProgress = 0;
      _installError = null;
    });

    try {
      await ref.read(apkInstallerProvider).downloadAndInstall(
        apkUrl,
        onProgress: (p) {
          if (mounted) setState(() => _installProgress = p);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _installError = '설치를 시작하지 못했어요. 잠시 뒤 다시 시도해주세요');
      }
    } finally {
      if (mounted) setState(() => _installing = false);
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
      appBar: const NinedogsAppBar(section: '설정'),
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
          if (_result != null)
            _UpdateResultCard(
              result: _result!,
              installing: _installing,
              progress: _installProgress,
              installError: _installError,
              onUpdate: _downloadAndInstall,
              onOpen: _open,
            ),

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
          _SectionTitle('안 쓰는 구독 찾기'),
          const _UsageTrackingTile(),

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
          _SectionTitle('가족 연결'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              ref.watch(syncEnabledProvider) ? '연결됨' : '배우자와 함께 보기',
            ),
            subtitle: Text(
              ref.watch(syncEnabledProvider)
                  ? '한쪽에서 고치면 다른 쪽에도 바로 반영돼요'
                  : '초대 코드 하나면 끝. 로그인·가입 없이 배우자와 함께 봐요',
              style: theme.textTheme.labelMedium,
            ),
            trailing: Icon(
              ref.watch(syncEnabledProvider)
                  ? Icons.link
                  : Icons.person_add_outlined,
              color: ref.watch(syncEnabledProvider)
                  ? AppColors.positive
                  : null,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SyncScreen()),
            ),
          ),

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

/// '안 쓰는 구독 찾기' 스위치와 그 한계 안내.
///
/// 이 기능은 폰 사용 기록만 본다. TV·PC 로 보는 건 잡히지 않으므로
/// 켜기 전에 그 점을 분명히 알려야 한다. 안 그러면 매일 TV 로 보는 넷플릭스를
/// "안 쓴다"고 오해하게 된다.
class _UsageTrackingTile extends ConsumerWidget {
  const _UsageTrackingTile();

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
  const _UpdateResultCard({
    required this.result,
    required this.installing,
    required this.progress,
    required this.installError,
    required this.onUpdate,
    required this.onOpen,
  });

  final UpdateResult result;
  final bool installing;
  final double progress;
  final String? installError;
  final ValueChanged<AppRelease> onUpdate;
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
              Row(
                children: [
                  const Icon(
                    Icons.system_update,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '새 버전 ${release.version}이 나왔어요',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
              if (installing) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surface,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  progress > 0
                      ? '내려받는 중 ${(progress * 100).toInt()}%'
                      : '내려받는 중…',
                  style: theme.textTheme.labelMedium,
                ),
              ] else
                FilledButton.icon(
                  onPressed: () => onUpdate(release),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('업데이트하기'),
                ),
              if (installError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  installError!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.negative,
                  ),
                ),
              ],
              if (release.apkUrl != null && !installing) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => onOpen(release.pageUrl),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '릴리즈 페이지에서 직접 받기',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
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
