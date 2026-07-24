import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/catalog/service_catalog.dart';
import '../../widgets/service_icon.dart';
import '../edit/subscription_form_screen.dart';

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

  void _openForm({CatalogService? service, String? customName}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            SubscriptionFormScreen(service: service, customName: customName),
      ),
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
              autofocus: true,
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
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  0,
                  AppSpacing.screenH,
                  AppSpacing.xxl,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.xl,
                  crossAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 0.74,
                ),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final service = results[index];
                  return _PickerTile(
                    service: service,
                    onTap: () => _openForm(service: service),
                  );
                },
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

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.service, required this.onTap});

  final CatalogService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) => ServiceIcon.fromCatalog(
                service,
                size: constraints.maxWidth,
                circular: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: Text(
              service.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: theme.colorScheme.onSurface,
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
