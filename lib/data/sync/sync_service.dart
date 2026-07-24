import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'household.dart';

/// 동기화 과정에서 사용자에게 보여줄 수 있는 실패들.
class SyncException implements Exception {
  const SyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 로그인과 household 관리.
///
/// 이 앱은 **기본이 오프라인**이다. 여기 있는 기능은 사용자가 설정에서
/// 직접 연결을 시작했을 때만 쓰인다.
class SyncService {
  SyncService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const _householdsPath = 'households';

  /// 초대 코드 -> household id 를 담는 별도 컬렉션.
  ///
  /// household 를 코드로 **검색**하게 두면, 로그인한 사람 누구나 전체
  /// household 목록을 훑을 수 있어야 한다(= 남의 초대 코드가 노출된다).
  /// 코드를 문서 id 로 쓰면 코드를 아는 사람만 정확히 한 건을 집어올 수 있다.
  static const _invitesPath = 'inviteCodes';

  String? get uid => _auth.currentUser?.uid;
  String? get email => _auth.currentUser?.email;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> get authChanges => _auth.authStateChanges();

  CollectionReference<Map<String, dynamic>> get _households =>
      _firestore.collection(_householdsPath);

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection(_invitesPath);

  // ── 접속 ────────────────────────────────────────────────

  /// 사용자 몰래 익명으로 접속한다.
  ///
  /// 서버는 household 를 만들거나 들어갈 때 "누가 요청했는지"를 알아야 한다.
  /// 예전에는 이메일·비밀번호로 계정을 만들게 했지만, 사용자 입장에선 왜 로그인을
  /// 해야 하는지 알 수 없는 마찰이었다. 익명 접속은 기기마다 uid 만 발급하므로
  /// 아무것도 입력하지 않아도 "버튼 → 코드 → 공유 → 연결"로 끝난다.
  ///
  /// 대신 앱을 지웠다 다시 깔면 uid 가 바뀐다. 그때는 초대 코드로 다시 들어오면
  /// 되고, 코드는 연결된 화면에서 언제든 확인할 수 있다.
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      throw SyncException(_readable(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  static String _readable(FirebaseAuthException e) => switch (e.code) {
    // Firebase 콘솔에서 익명 로그인을 안 켰을 때. 개발자에게 주는 힌트다.
    'operation-not-allowed' => '연결 기능이 아직 준비되지 않았어요 (익명 로그인 미설정)',
    'network-request-failed' => '네트워크에 연결할 수 없어요',
    'too-many-requests' => '잠시 뒤에 다시 시도해주세요',
    _ => '문제가 생겼어요 (${e.code})',
  };

  // ── household ──────────────────────────────────────────

  /// 새 household 를 만들고 내가 첫 구성원이 된다.
  Future<Household> createHousehold() async {
    await ensureSignedIn();
    final myUid = uid;
    if (myUid == null) throw const SyncException('연결에 실패했어요. 잠시 뒤 다시 시도해주세요');

    final doc = _households.doc();
    final household = Household(
      id: doc.id,
      inviteCode: Household.generateCode(),
      memberUids: [myUid],
      createdAt: DateTime.now(),
    );

    await doc.set(household.toJson());
    await _invites.doc(household.inviteCode).set({'householdId': doc.id});
    return household;
  }

  /// 초대 코드로 기존 household 에 들어간다.
  Future<Household> joinHousehold(String code) async {
    await ensureSignedIn();
    final myUid = uid;
    if (myUid == null) throw const SyncException('연결에 실패했어요. 잠시 뒤 다시 시도해주세요');

    final normalized = Household.normalizeCode(code);
    if (normalized.isEmpty) throw const SyncException('초대 코드를 입력해주세요');

    // 코드를 문서 id 로 직접 집는다. 목록을 훑을 수 없다.
    final invite = await _invites.doc(normalized).get();
    final householdId = invite.data()?['householdId'] as String?;
    if (householdId == null) {
      throw const SyncException('그런 초대 코드가 없어요. 다시 확인해주세요');
    }

    // 이미 들어와 있어도 다시 눌러서 문제가 없어야 한다
    await _households.doc(householdId).update({
      'memberUids': FieldValue.arrayUnion([myUid]),
    });

    final household = await fetchHousehold(householdId);
    if (household == null) {
      throw const SyncException('연결에 실패했어요. 잠시 뒤 다시 시도해주세요');
    }
    return household;
  }

  Future<Household?> fetchHousehold(String id) async {
    final doc = await _households.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return Household.fromJson(doc.id, data);
  }

  /// household 에서 빠진다. 남은 데이터는 상대방 것으로 남는다.
  Future<void> leaveHousehold(String id) async {
    final myUid = uid;
    if (myUid == null) return;

    await _households.doc(id).update({
      'memberUids': FieldValue.arrayRemove([myUid]),
    });
  }
}
