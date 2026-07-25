import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/billing_lookup.dart';
import '../../data/catalog/service_catalog.dart';
import '../../data/models/subscription.dart';

/// "이 서비스 언제부터 구독했지?" 를 알아내는 방법을 알려준다.
///
/// 가입일을 기억하는 사람은 거의 없다. 각 서비스 결제 내역의 가장 오래된
/// 항목에서 역추적하는 게 현실적인 방법인데, 그 화면 위치가 서비스마다
/// 다르고 결제 내역 보존 기간도 짧은 곳이 있다. 그 사정을 미리 알려준다.
Future<void> showBillingLookupSheet(
  BuildContext context,
  Subscription subscription,
) async {
  final lookup = billingLookupOf(subscription.serviceId);
  final domain = ServiceCatalog.domainOf(subscription.serviceId);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('가입일 찾기', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${subscription.name}의 결제 내역에서 가장 오래된 항목이 가입한 달이에요.',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.xl),

              if (lookup != null) ...[
                _Step(
                  number: '1',
                  title: '이 순서로 들어가세요',
                  body: lookup.path,
                ),
                _Step(
                  number: '2',
                  title: '볼 수 있는 범위',
                  body: lookup.historyRange,
                ),
                if (lookup.caveat != null)
                  _Step(number: '!', title: '참고', body: lookup.caveat!),
                const SizedBox(height: AppSpacing.lg),
                if (lookup.url != null)
                  FilledButton.icon(
                    onPressed: () => _open(sheetContext, lookup.url!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('결제 내역 열기'),
                  ),
              ] else ...[
                Text(
                  '이 서비스는 아직 정확한 경로를 확인하지 못했어요. '
                  '보통 로그인한 뒤 "계정" 이나 "내 정보" 안의 결제·구독 메뉴에 '
                  '결제 내역이 있어요.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (domain != null)
                  FilledButton.icon(
                    onPressed: () => _open(sheetContext, 'https://$domain'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('서비스 홈페이지 열기'),
                  ),
              ],

              const SizedBox(height: AppSpacing.xl),
              Text('앱스토어로 결제했다면', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '앱 안에서 결제했다면 서비스 사이트에는 내역이 없어요. '
                '결제한 스토어에서 확인하세요.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () =>
                    _open(sheetContext, playStoreSubscriptionsUrl),
                icon: const Icon(Icons.shop_outlined, size: 18),
                label: const Text('Google Play 정기결제'),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => _open(sheetContext, appStoreSubscriptionsUrl),
                icon: const Icon(Icons.apple, size: 18),
                label: const Text('Apple 구독'),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                '결제 내역이 가입일까지 거슬러 가지 않으면, 카드사 명세서나 '
                '가입 확인 메일을 서비스 이름으로 검색해보세요.',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _open(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('브라우저를 열지 못했어요')),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
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
              number,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
