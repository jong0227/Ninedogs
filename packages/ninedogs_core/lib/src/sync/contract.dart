/// 구독·계정 문서의 "계약 버전".
///
/// Ninedogs 와 family_finance 두 앱이 같은 Firestore 문서를 읽고 쓴다.
/// 한쪽이 문서 모양을 바꾸면(필드 의미 변경 등), 아직 업데이트하지 않은
/// 다른 앱이 옛 모양으로 덮어써 데이터가 깨질 수 있다. 그래서 문서마다
/// `cv` 를 적고, **내가 아는 것보다 높은 cv 를 보면 쓰지 않는다.**
///
/// 필드를 "추가"만 할 때는 올리지 않는다(모르는 필드는 merge 쓰기로 보존된다).
/// 의미가 바뀌거나 필드를 없앨 때만 올린다.
const kContractVersion = 1;

/// 서버에 이 앱이 모르는 새 계약 버전의 문서가 있어서 쓰기를 막았다.
class ContractTooNewException implements Exception {
  const ContractTooNewException(this.seen);

  final int seen;

  @override
  String toString() =>
      'ContractTooNewException: 서버 cv=$seen, 이 앱 cv=$kContractVersion';
}
