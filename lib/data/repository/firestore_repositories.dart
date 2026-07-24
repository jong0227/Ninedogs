import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/credential.dart';
import '../models/subscription.dart';
import 'credential_repository.dart';
import 'subscription_repository.dart';

/// household 하나가 쓰는 Firestore 경로들.
///
/// 문서 구조
/// ```
/// households/{id}
///   subscriptions/{subscriptionId}
///   credentials/{subscriptionId}   ← 암호문만
///   meta/vault                     ← salt 와 확인용 값
/// ```
class _HouseholdPaths {
  const _HouseholdPaths(this.firestore, this.householdId);

  final FirebaseFirestore firestore;
  final String householdId;

  DocumentReference<Map<String, dynamic>> get root =>
      firestore.collection('households').doc(householdId);

  CollectionReference<Map<String, dynamic>> get subscriptions =>
      root.collection('subscriptions');

  CollectionReference<Map<String, dynamic>> get credentials =>
      root.collection('credentials');

  DocumentReference<Map<String, dynamic>> get vault =>
      root.collection('meta').doc('vault');
}

/// 구독을 household 안에 저장한다. 두 사람이 같은 목록을 본다.
class FirestoreSubscriptionRepository implements SubscriptionRepository {
  FirestoreSubscriptionRepository({
    required String householdId,
    FirebaseFirestore? firestore,
  }) : _paths = _HouseholdPaths(
         firestore ?? FirebaseFirestore.instance,
         householdId,
       );

  final _HouseholdPaths _paths;

  @override
  Future<List<Subscription>> load() async {
    final snapshot = await _paths.subscriptions.get();
    return snapshot.docs.map((doc) => Subscription.fromJson(doc.data())).toList();
  }

  @override
  Stream<List<Subscription>> watch() => _paths.subscriptions.snapshots().map(
    (snapshot) =>
        snapshot.docs.map((doc) => Subscription.fromJson(doc.data())).toList(),
  );

  /// 목록 전체를 맞춘다. 사라진 구독은 문서도 지운다.
  ///
  /// 한 번에 쓰기 때문에 중간 상태가 상대에게 보이지 않는다.
  @override
  Future<void> save(List<Subscription> subscriptions) async {
    final existing = await _paths.subscriptions.get();
    final keep = {for (final s in subscriptions) s.id};

    final batch = _paths.firestore.batch();

    for (final doc in existing.docs) {
      if (!keep.contains(doc.id)) batch.delete(doc.reference);
    }
    for (final subscription in subscriptions) {
      batch.set(_paths.subscriptions.doc(subscription.id), subscription.toJson());
    }

    await batch.commit();
  }
}

/// 계정 정보를 household 안에 저장한다.
///
/// 올라가는 건 **암호문뿐**이다. 서버 관리자가 문서를 열어봐도 아이디와
/// 비밀번호는 알 수 없다. 열려면 두 사람이 공유하는 마스터 암호가 필요하다.
class FirestoreCredentialRepository implements CredentialRepository {
  FirestoreCredentialRepository({
    required String householdId,
    FirebaseFirestore? firestore,
  }) : _paths = _HouseholdPaths(
         firestore ?? FirebaseFirestore.instance,
         householdId,
       );

  final _HouseholdPaths _paths;

  @override
  Future<VaultMetadata?> loadMetadata() async {
    final doc = await _paths.vault.get();
    final data = doc.data();
    return data == null ? null : VaultMetadata.fromJson(data);
  }

  @override
  Future<void> saveMetadata(VaultMetadata metadata) =>
      _paths.vault.set(metadata.toJson());

  @override
  Future<List<StoredCredential>> load() async {
    final snapshot = await _paths.credentials.get();
    return snapshot.docs
        .map((doc) => StoredCredential.fromJson(doc.data()))
        .toList();
  }

  @override
  Stream<List<StoredCredential>> watch() => _paths.credentials.snapshots().map(
    (snapshot) => snapshot.docs
        .map((doc) => StoredCredential.fromJson(doc.data()))
        .toList(),
  );

  @override
  Future<void> save(List<StoredCredential> credentials) async {
    final existing = await _paths.credentials.get();
    final keep = {for (final c in credentials) c.subscriptionId};

    final batch = _paths.firestore.batch();

    for (final doc in existing.docs) {
      if (!keep.contains(doc.id)) batch.delete(doc.reference);
    }
    for (final credential in credentials) {
      batch.set(
        _paths.credentials.doc(credential.subscriptionId),
        credential.toJson(),
      );
    }

    await batch.commit();
  }
}
