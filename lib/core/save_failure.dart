import 'package:flutter/material.dart';

import '../data/sync/contract.dart';

/// 구독 저장이 실패했을 때.
///
/// 저장에 실패하면 화면은 바뀌기 전으로 되돌아간다. 그런데 **왜** 되돌아갔는지
/// 말해주지 않으면, 사용자 눈에는 입력이 슬쩍 사라진 것으로만 보인다.
/// 앱이 고장 난 줄 알거나, 자기가 잘못 눌렀다고 생각한다.
class SubscriptionSaveFailure implements Exception {
  const SubscriptionSaveFailure(this.cause);

  final Object cause;

  @override
  String toString() => 'SubscriptionSaveFailure: $cause';
}

/// 저장이 실패하면 되돌아갔다고 알린다.
///
/// 편집 동작이 화면 곳곳에 흩어져 있어서, 저장 결과를 알리는 코드를
/// 자리마다 적으면 빠뜨리는 데가 생긴다. 한 겹으로 감싼다.
///
/// ```dart
/// await guardSave(context, () => notifier.cancel(id));
/// ```
///
/// 저장 말고 다른 예외는 그대로 던진다 — 감춰야 할 이유가 없다.
Future<bool> guardSave(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);

  try {
    await action();
    return true;
  } on SubscriptionSaveFailure catch (failure) {
    final tooNew = failure.cause is ContractTooNewException;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          tooNew
              ? '다른 앱이 더 새 버전으로 저장한 구독이 있어요. 설정에서 업데이트한 뒤 고쳐주세요'
              : '저장하지 못해서 되돌렸어요. 잠시 뒤 다시 시도해주세요',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    return false;
  }
}
