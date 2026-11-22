import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

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

/// 서버에서 마지막으로 본 문서들. "바뀐 것만 쓰고, 사용자가 지운 것만 지운다"의 기준.
///
/// 예전 저장은 "내 목록에 없는 문서는 전부 지우고 나머지는 전부 덮어쓴다"였다.
/// 다른 기기·다른 앱(family_finance)이 방금 만든 구독을 아직 못 본 상태에서
/// 저장하면 그 구독이 지워지고, 오프라인에서 고친 뒤 다시 연결되면 상대가 고친
/// 구독까지 옛 값으로 덮였다. 그래서 마지막으로 본 서버 상태와 비교해
/// **내가 실제로 바꾼 문서만** 쓰고, **내가 본 적 있는데 목록에서 빠진 문서만** 지운다.
@visibleForTesting
class KnownDocs<T> {
  KnownDocs(this._encode);

  final String Function(T) _encode;
  Map<String, String>? _byId;

  bool get isLoaded => _byId != null;

  void remember(Map<String, T> items) =>
      _byId = {for (final e in items.entries) e.key: _encode(e.value)};

  /// 저장할 목록과 비교해 (쓸 id, 지울 id) 를 돌려준다.
  ({List<String> upserts, List<String> deletes}) diff(
    Map<String, T> next, {
    required bool allowDeletes,
  }) {
    final known = _byId ?? const <String, String>{};
    final upserts = [
      for (final e in next.entries)
        if (known[e.key] != _encode(e.value)) e.key,
    ];
    final deletes = allowDeletes
        ? [for (final id in known.keys) if (!next.containsKey(id)) id]
        : const <String>[];
    return (upserts: upserts, deletes: deletes);
  }
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
  final _known = KnownDocs<Subscription>(
    (s) => jsonEncode(s.toJson()),
  );

  List<Subscription> _read(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final list = snapshot.docs
        .map((doc) => Subscription.fromJson(doc.data()))
        .toList();
    _known.remember({for (final s in list) s.id: s});
    return list;
  }

  @override
  Future<List<Subscription>> load() async =>
      _read(await _paths.subscriptions.get());

  @override
  Stream<List<Subscription>> watch() =>
      _paths.subscriptions.snapshots().map(_read);

  /// 바뀐 구독만 쓰고, 사용자가 지운 구독만 지운다. ([KnownDocs] 참고)
  ///
  /// 쓰기는 merge 로 한다 — 다른 앱이 같은 문서에 둔, 이 앱이 모르는 필드를
  /// 지우지 않기 위해서다. 이 앱이 아는 필드는 null 까지 그대로 써서 지울 수 있다.
  /// 서버 상태를 한 번도 못 본 채 저장하게 되면(드묾) 지우기는 하지 않는다.
  @override
  Future<void> save(List<Subscription> subscriptions) async {
    final allowDeletes = _known.isLoaded;
    if (!allowDeletes) await load();

    final next = {for (final s in subscriptions) s.id: s};
    final change = _known.diff(next, allowDeletes: allowDeletes);
    if (change.upserts.isEmpty && change.deletes.isEmpty) return;

    final batch = _paths.firestore.batch();
    for (final id in change.deletes) {
      batch.delete(_paths.subscriptions.doc(id));
    }
    for (final id in change.upserts) {
      batch.set(
        _paths.subscriptions.doc(id),
        next[id]!.toJson(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    _known.remember(next);
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
  final _known = KnownDocs<StoredCredential>(
    (c) => jsonEncode(c.toJson()),
  );

  List<StoredCredential> _read(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final list = snapshot.docs
        .map((doc) => StoredCredential.fromJson(doc.data()))
        .toList();
    _known.remember({for (final c in list) c.subscriptionId: c});
    return list;
  }

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
  Future<List<StoredCredential>> load() async =>
      _read(await _paths.credentials.get());

  @override
  Stream<List<StoredCredential>> watch() =>
      _paths.credentials.snapshots().map(_read);

  /// 구독과 같은 원칙: 바뀐 것만 쓰고, 사용자가 지운 것만 지운다.
  @override
  Future<void> save(List<StoredCredential> credentials) async {
    final allowDeletes = _known.isLoaded;
    if (!allowDeletes) await load();

    final next = {for (final c in credentials) c.subscriptionId: c};
    final change = _known.diff(next, allowDeletes: allowDeletes);
    if (change.upserts.isEmpty && change.deletes.isEmpty) return;

    final batch = _paths.firestore.batch();
    for (final id in change.deletes) {
      batch.delete(_paths.credentials.doc(id));
    }
    for (final id in change.upserts) {
      batch.set(_paths.credentials.doc(id), next[id]!.toJson());
    }
    await batch.commit();
    _known.remember(next);
  }
}
