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

  // ── 로그인 ──────────────────────────────────────────────

  Future<void> signIn(String email, String password) =>
      _run(() => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ));

  Future<void> signUp(String email, String password) =>
      _run(() => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ));

  Future<void> signOut() => _auth.signOut();

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw SyncException(_readable(e));
    }
  }

  static String _readable(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => '이메일 형식이 올바르지 않아요',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => '이메일 또는 비밀번호가 맞지 않아요',
    'email-already-in-use' => '이미 가입된 이메일이에요. 로그인해주세요',
    'weak-password' => '비밀번호는 6자 이상이어야 해요',
    'network-request-failed' => '네트워크에 연결할 수 없어요',
    'too-many-requests' => '잠시 뒤에 다시 시도해주세요',
    _ => '문제가 생겼어요 (${e.code})',
  };

  // ── household ──────────────────────────────────────────

  /// 새 household 를 만들고 내가 첫 구성원이 된다.
  Future<Household> createHousehold() async {
    final myUid = uid;
    if (myUid == null) throw const SyncException('먼저 로그인해주세요');

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
    final myUid = uid;
    if (myUid == null) throw const SyncException('먼저 로그인해주세요');

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
