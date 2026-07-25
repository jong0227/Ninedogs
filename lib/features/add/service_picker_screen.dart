import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/catalog/service_catalog.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/service_browser.dart';
import '../edit/subscription_form_screen.dart';
import 'bundle_notice.dart';

/// 구독을 추가할 때 먼저 서비스를 고르는 화면.
///
/// 카탈로그에 없는 서비스도 검색어를 그대로 이름으로 삼아 추가할 수 있다.
/// 이 경우에도 아이콘은 App Store 검색으로 찾아본다.
class ServicePickerScreen extends ConsumerStatefulWidget {
  const ServicePickerScreen({super.key});

  @override
  ConsumerState<ServicePickerScreen> createState() =>
      _ServicePickerScreenState();
}

class _ServicePickerScreenState extends ConsumerState<ServicePickerScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openForm({
    CatalogService? service,
    String? customName,
    CatalogPlan? initialPlan,
  }) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SubscriptionFormScreen(
          service: service,
          customName: customName,
          initialPlan: initialPlan,
        ),
      ),
    );
  }

  /// 상위 상품에 포함되는 서비스라면 어떻게 등록할지 먼저 묻는다.
  ///
  /// 와우 멤버십을 이미 등록한 사람이 쿠팡플레이를 제값으로 넣으면 실제로
  /// 내지 않는 돈이 매달 합계에 더해진다.
  Future<void> _pickService(CatalogService service) async {
    final parent = bundledParentAmong(
      service,
      ref.read(allSubscriptionsProvider),
    );

    if (parent == null) {
      _openForm(service: service);
      return;
    }

    final choice = await askBundleChoice(
      context,
      service: service,
      parent: parent,
    );
    if (choice == null || !mounted) return;

    _openForm(
      service: service,
      initialPlan: choice == BundleChoice.included
          ? ServiceCatalog.includedPlanOf(service)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ServiceCatalog.search(_query);
    final trimmed = _query.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('구독 추가')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.lg,
            ),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '서비스 이름 검색',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (results.isEmpty && trimmed.isNotEmpty)
            _CustomServicePrompt(
              name: trimmed,
              onTap: () => _openForm(customName: trimmed),
            )
          else
            Expanded(
              child: ServiceBrowser(
                query: _query,
                // 이미 등록한 서비스를 흐리게 + '구독 중' 배지로 알린다.
                // 해지한 건 다시 넣을 수 있어야 하므로 구독 중인 것만 센다.
                subscribedIds: {
                  for (final s in ref.watch(activeSubscriptionsProvider))
                    if (s.serviceId != null) s.serviceId!,
                },
                onTap: _pickService,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                0,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              child: TextButton.icon(
                onPressed: () => _openForm(
                  customName: trimmed.isEmpty ? null : trimmed,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  trimmed.isEmpty ? '목록에 없는 구독 직접 추가' : "'$trimmed' 직접 추가",
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.textTheme.labelMedium?.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomServicePrompt extends StatelessWidget {
  const _CustomServicePrompt({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '목록에 없는 서비스예요',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.labelMedium?.color,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(200, 48),
                ),
                child: Text("'$name' 추가하기"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
