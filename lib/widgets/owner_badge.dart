import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/people.dart';
import '../providers/people_providers.dart';

/// 구독 이름 오른쪽 위에 붙는 작은 사람 이름표.
///
/// 주인이 없으면(공동·미지정) 아무것도 그리지 않는다.
class OwnerBadge extends ConsumerWidget {
  const OwnerBadge(this.owner, {super.key});

  final String? owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = owner;
    if (key == null) return const SizedBox.shrink();
    final color = People.colorOf(key);
    final name = ref.watch(peopleProvider).nameOf(key);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
