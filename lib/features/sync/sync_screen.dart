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
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  bool _signingUp = false;
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
    _email.dispose();
    _password.dispose();
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
          else if (service.isSignedIn)
            _pickMode(context)
          else
            _signIn(context),

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

  // ── 1단계: 로그인 ────────────────────────────────────────

  Widget _signIn(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _signingUp ? '계정 만들기' : '로그인',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '두 사람이 같은 구독 목록을 보려면 계정이 필요해요. '
          '연결하지 않으면 이 기기에만 저장돼요.',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            helperText: '6자 이상',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _working
              ? null
              : () => _guard(() async {
                  final service = ref.read(syncServiceProvider);
                  if (_signingUp) {
                    await service.signUp(_email.text, _password.text);
                  } else {
                    await service.signIn(_email.text, _password.text);
                  }
                  if (mounted) setState(() {});
                }),
          child: _working
              ? const _Spinner()
              : Text(_signingUp ? '가입하고 계속' : '로그인'),
        ),
        TextButton(
          onPressed: _working
              ? null
              : () => setState(() {
                  _signingUp = !_signingUp;
                  _error = null;
                }),
          child: Text(_signingUp ? '이미 계정이 있어요' : '계정이 없어요'),
        ),
      ],
    );
  }

  // ── 2단계: 만들기 또는 참여 ───────────────────────────────

  Widget _pickMode(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('어떻게 연결할까요?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '한 사람이 먼저 시작해서 초대 코드를 만들고, '
          '다른 사람이 그 코드로 들어오면 돼요.',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        FilledButton(
          onPressed: _working
              ? null
              : () => _guard(() async {
                  final household = await ref
                      .read(syncCoordinatorProvider)
                      .startSharing();
                  if (mounted) setState(() => _household = household);
                }),
          child: _working ? const _Spinner() : const Text('내가 먼저 시작하기'),
        ),
        const SizedBox(height: AppSpacing.xl),

        Text('초대 코드로 들어가기', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
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
          child: const Text('참여하기'),
        ),
        const SizedBox(height: AppSpacing.xl),

        TextButton(
          onPressed: () async {
            await ref.read(syncServiceProvider).signOut();
            if (mounted) setState(() {});
          },
          child: const Text('로그아웃'),
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
          '${service.email ?? ''} 계정으로 함께 보고 있어요. '
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
            '배우자가 이 코드를 입력하면 함께 보게 돼요 · '
            '지금 ${household.memberUids.length}명',
            style: theme.textTheme.labelMedium,
          ),
        ],

        const SizedBox(height: AppSpacing.xxl),
        Text('계정 정보를 함께 보려면', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '두 사람이 같은 마스터 암호를 써야 해요. 서버에는 암호문만 올라가서 '
          '암호를 모르면 아무도 열 수 없어요.',
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
