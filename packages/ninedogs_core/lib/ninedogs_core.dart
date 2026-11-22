/// Ninedogs 와 family_finance 가 함께 쓰는 구독 데이터 계약.
///
/// 두 앱이 같은 Firestore 문서(구독·계정·금고·가구)를 읽고 쓴다. 직렬화가
/// 두 벌이면 언젠가 어긋나므로, 모델·코덱·카탈로그·암호화를 이 패키지 한 곳에 둔다.
/// Flutter·Firebase·Riverpod 에 의존하지 않는다(어느 앱에서든, 순수 Dart 테스트로도 쓰게).
library;

export 'src/catalog/billing_lookup.dart';
export 'src/catalog/catalog_service.dart';
export 'src/catalog/service_catalog.dart';
export 'src/models/billing_cycle.dart';
export 'src/models/credential.dart';
export 'src/models/money.dart';
export 'src/models/people.dart';
export 'src/models/subscription.dart';
export 'src/security/vault_crypto.dart';
export 'src/sync/contract.dart';
export 'src/sync/household.dart';
