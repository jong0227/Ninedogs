import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/catalog/service_catalog.dart';
import '../../data/models/subscription.dart';

/// 번들에 포함되는 서비스를 어떻게 등록할지.
enum BundleChoice {
  /// 0원으로 등록한다. 목록에는 남지만 합계에는 더하지 않는다.
  included,

  /// 제값으로 따로 등록한다.
  separate,
}

/// [service] 가 이미 등록한 상위 상품에 포함되는지 본다.
///
/// 포함된다면 그 상위 상품을, 아니면 null 을 돌려준다.
/// 해지한 구독은 지금 돈이 나가지 않으므로 세지 않는다.
CatalogService? bundledParentAmong(
  CatalogService service,
  List<Subscription> subscriptions,
) {
  final parent = ServiceCatalog.parentOf(service);
  if (parent == null) return null;

  final owned = subscriptions.any(
    (s) => s.serviceId == parent.id && s.isActive,
  );
  return owned ? parent : null;
}

/// 상위 상품을 이미 쓰고 있을 때 어떻게 등록할지 묻는다.
///
/// 쿠팡플레이를 와우 멤버십과 따로 제값에 등록하면 실제로 내지 않는 7,890원이
/// 매달 합계에 더해진다. 이 앱의 핵심 숫자가 누적 지출이라 그냥 두면 안 된다.
/// 취소하면 null.
Future<BundleChoice?> askBundleChoice(
  BuildContext context, {
  required CatalogService service,
  required CatalogService parent,
}) {
  final theme = Theme.of(context);

  return showDialog<BundleChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.card_giftcard_outlined,
        color: AppColors.accent,
        size: 30,
      ),
      title: Text('${service.name}은(는)\n${parent.name}에 포함돼요'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이미 ${parent.name}을(를) 등록하셨네요. '
            '${service.name}은(는) 거기 딸려오는 혜택이라 따로 돈이 나가지 않아요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '제값으로 등록하면 실제로 내지 않는 돈이 매달 합계에 더해져요.',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, BundleChoice.separate),
          child: const Text('따로 내고 있어요'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, BundleChoice.included),
          child: const Text('0원으로 등록'),
        ),
      ],
    ),
  );
}
