import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/repository/firestore_repositories.dart';

/// 저장할 때 "바뀐 것만 쓰고, 내가 지운 것만 지운다"를 지킨다.
/// 다른 앱(family_finance)과 같은 구독 문서를 쓰기 때문에 생긴 규칙이다.
void main() {
  KnownDocs<String> known(Map<String, String> server) =>
      KnownDocs<String>((v) => v)..remember(server);

  test('바뀌지 않은 문서는 쓰지 않는다', () {
    final k = known({'a': '1', 'b': '2'});
    final d = k.diff({'a': '1', 'b': '3'}, allowDeletes: true);
    expect(d.upserts, ['b']);
    expect(d.deletes, isEmpty);
  });

  test('다른 앱이 방금 만든, 아직 못 본 문서는 지우지 않는다', () {
    // 서버에는 c 가 새로 생겼지만 이 기기는 아직 a, b 만 봤다.
    final k = known({'a': '1', 'b': '2'});
    final d = k.diff({'a': '1', 'b': '2'}, allowDeletes: true);
    expect(d.deletes, isEmpty); // c 를 몰라서 건드리지 않는다
    expect(d.upserts, isEmpty);
  });

  test('본 적 있는 문서를 목록에서 빼면 지운다 (사용자가 삭제)', () {
    final k = known({'a': '1', 'b': '2'});
    final d = k.diff({'a': '1'}, allowDeletes: true);
    expect(d.deletes, ['b']);
  });

  test('서버 상태를 못 본 채 저장하면 지우기는 하지 않는다', () {
    final k = known({'a': '1', 'b': '2'});
    final d = k.diff({'a': '9'}, allowDeletes: false);
    expect(d.upserts, ['a']);
    expect(d.deletes, isEmpty);
  });

  test('새 문서는 쓴다', () {
    final k = known({'a': '1'});
    expect(k.diff({'a': '1', 'n': '5'}, allowDeletes: true).upserts, ['n']);
  });
}
