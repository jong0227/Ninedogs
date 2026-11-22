import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics.dart';
import '../data/models/people.dart';
import 'app_providers.dart';
import 'sync_providers.dart';

/// 사람 이름(구독 주인 이름표에 쓰는 이름).
///
/// 가족 연결이 되어 있으면 `households/{id}/meta/people` 문서를 실시간으로
/// 따라가 두 폰이 같은 이름을 본다. 연결 전이거나 읽기에 실패하면 기기에
/// 저장해 둔 값(마지막으로 본 값)을 쓴다.
class PeopleNotifier extends Notifier<People> {
  static const _key = 'people_v1';

  @override
  People build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final householdId = ref.watch(householdIdProvider);
    final cached = _decode(prefs.getString(_key));

    if (householdId != null) {
      StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
      try {
        sub = _doc(householdId).snapshots().listen((snap) {
          final people = People.fromJson(snap.data());
          state = people;
          prefs.setString(_key, jsonEncode(people.toJson()));
        }, onError: (Object e) => logIgnored('사람 이름을 읽지 못했다', e));
      } catch (e) {
        logIgnored('사람 이름 구독을 시작하지 못했다', e);
      }
      ref.onDispose(() => sub?.cancel());
    }
    return cached;
  }

  Future<void> rename(String key, String name) async {
    if (name.trim().isEmpty) return;
    final next = state.withName(key, name);
    state = next;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(next.toJson()));
    final householdId = ref.read(householdIdProvider);
    if (householdId != null) {
      await _doc(householdId).set(next.toJson());
    }
  }

  static DocumentReference<Map<String, dynamic>> _doc(String householdId) =>
      FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('meta')
          .doc('people');

  static People _decode(String? raw) {
    if (raw == null) return People.defaults;
    try {
      return People.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return People.defaults;
    }
  }
}

final peopleProvider = NotifierProvider<PeopleNotifier, People>(PeopleNotifier.new);
