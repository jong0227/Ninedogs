import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/sync/household.dart';
import '../../data/sync/sync_service.dart';
import '../../providers/sync_providers.dart';

/// 배우자와 데이터를 함께 보도록 연결하는 화면.
///
/// 연결은 **직접 시작해야만** 이뤄진다. 앱을 깔기만 해서는 아무와도 묶이지
/// 않으므로, 같은 앱을 친구에게 줘도 서로의 구독이 섞이지 않는다.
///
/// 로그인(이메일·비밀번호)은 없앴다. "먼저 시작하기 → 코드 공유 → 코드 입력"
/// 세 동작으로 끝난다. 서버 접속은 익명으로 조용히 처리한다([SyncService]).
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _code = TextEditingController();

  bool _working = false;
  String? _error;
  Household? _household;

  @override
  void initState() {
    super.initState();
    _loadHousehold();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadHousehold() async {
    final id = ref.read(householdIdProvider);
    if (id == null) return;

    final found = await ref.read(syncServiceProvider).fetchHousehold(id);
    if (mounted) setState(() => _household = found);
  }

  /// 실패 메시지를 화면에 남기면서 작업을 돌린다.
  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _error = null;
      _working = true;
    });

    try {
      await action();
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '문제가 생겼어요. 잠시 뒤 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(syncServiceProvider);
    final householdId = ref.watch(householdIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('가족 연결')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.lg,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          if (householdId != null)
            _connected(context, service)
          else
            _startOrJoin(context),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.negative),
            ),
          ],
        ],
      ),
    );
  }

  // ── 연결 시작 (먼저 만들기 / 코드로 들어가기) ──────────────────

  Widget _startOrJoin(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('배우자와 함께 보기', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '연결하면 두 사람이 같은 구독 목록을 함께 관리해요. '
          '한쪽에서 고치면 다른 쪽에도 바로 반영돼요. '
          '연결하지 않으면 지금처럼 이 기기에만 저장돼요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _HowItWorks(),
        const SizedBox(height: AppSpacing.xl),

        // 한 사람만 누른다. 코드가 만들어지고, 그걸 배우자에게 준다.
        Text(
          '내가 먼저 시작하기',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '누르면 바로 초대 코드가 만들어져요. 그 코드를 배우자에게 알려주세요.',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _working
              ? null
              : () => _guard(() async {
                  final household = await ref
                      .read(syncCoordinatorProvider)
                      .startSharing();
                  if (mounted) setState(() => _household = household);
                }),
          icon: _working
              ? const _Spinner()
              : const Icon(Icons.qr_code_2_outlined, size: 20),
          label: const Text('초대 코드 만들기'),
        ),

        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(child: Divider(color: theme.dividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('또는', style: theme.textTheme.labelMedium),
            ),
            Expanded(child: Divider(color: theme.dividerColor)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // 배우자가 이미 코드를 만들었으면 그 코드를 넣는다.
        Text(
          '받은 코드로 들어가기',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '배우자가 먼저 만들었다면, 받은 6자리 코드를 여기에 입력하세요.',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: const InputDecoration(hintText: '예: K7M2QP'),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: _working
              ? null
              : () => _guard(() async {
                  final household = await ref
                      .read(syncCoordinatorProvider)
                      .joinSharing(_code.text);
                  if (mounted) setState(() => _household = household);
                }),
          child: const Text('코드로 연결하기'),
        ),
      ],
    );
  }

  // ── 연결된 뒤 ────────────────────────────────────────────

  Widget _connected(BuildContext context, SyncService service) {
    final theme = Theme.of(context);
    final household = _household;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.link, size: 18, color: AppColors.positive),
            const SizedBox(width: AppSpacing.sm),
            Text('연결됨', style: theme.textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '이제 두 사람이 같은 목록을 함께 봐요. '
          '한쪽에서 고치면 다른 쪽에도 바로 반영돼요.',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        if (household != null) ...[
          Text('초대 코드', style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    household.inviteCode,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 4,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: household.inviteCode),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('초대 코드를 복사했어요')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '아직 안 들어온 사람은 이 코드를 입력하면 함께 보게 돼요 · '
            '지금 ${household.memberUids.length}명',
            style: theme.textTheme.labelMedium,
          ),
        ],

        const SizedBox(height: AppSpacing.xxl),
        Text('계정 정보(금고)도 함께 보려면', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '두 사람이 같은 마스터 암호를 써야 해요. 서버에는 암호문만 올라가서, '
          '마스터 암호를 모르면 아무도 열 수 없어요.',
          style: theme.textTheme.labelMedium,
        ),

        const SizedBox(height: AppSpacing.xxl),
        TextButton(
          onPressed: _working
              ? null
              : () => _guard(() async {
                  await ref.read(syncCoordinatorProvider).stopSharing();
                  if (mounted) setState(() => _household = null);
                }),
          style: TextButton.styleFrom(foregroundColor: AppColors.negative),
          child: const Text('연결 끊기'),
        ),
        Text(
          '끊어도 지금까지 내용은 이 기기에 남아요',
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}

/// 연결이 어떻게 이뤄지는지 두 단계로 미리 보여준다.
///
/// 예전엔 이메일·비밀번호로 로그인을 시켰는데 "왜 로그인하지?" 하고 멈칫하게
/// 됐다. 지금은 로그인 없이 코드만 주고받으면 된다는 걸 먼저 알려준다.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '어떻게 연결되나요?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _Step(
            n: '1',
            title: '한 명이 코드 만들기',
            body: '한 사람이 "초대 코드 만들기"를 누르면 6자리 코드가 나와요. '
                '로그인도, 가입도 필요 없어요.',
          ),
          const _Step(
            n: '2',
            title: '다른 한 명이 코드 입력',
            body: '카톡 등으로 코드를 보내고, 배우자가 그 코드를 입력하면 끝. '
                '이제 같은 목록을 함께 봐요.',
            last: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '구독 목록은 이렇게 바로 공유돼요. 다만 아이디·비번을 넣어둔 '
                    '"금고"까지 함께 보려면, 두 사람이 같은 마스터 암호를 써야 해요. '
                    '(서버엔 암호문만 올라가요)',
                    style: theme.textTheme.labelMedium?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.body,
    this.last = false,
  });

  final String n;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: const TextStyle(
                color: AppColors.onAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.labelMedium?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: Theme.of(context).colorScheme.onPrimary,
    ),
  );
}
