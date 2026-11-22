import 'dart:math';

/// 데이터를 함께 보는 사람들의 묶음. 부부가 하나의 household 를 쓴다.
///
/// **초대 코드를 받은 사람만 들어온다.** 같은 앱을 쓰는 친구들은 아무것도
/// 하지 않으면 계속 자기 기기에만 저장된다. 실수로 남의 구독이 섞이는 일이
/// 없도록 자동으로 묶이는 경로는 만들지 않는다.
class Household {
  const Household({
    required this.id,
    required this.inviteCode,
    required this.memberUids,
    required this.createdAt,
  });

  final String id;

  /// 상대에게 불러줄 코드. 짧고 헷갈리지 않는 글자만 쓴다.
  final String inviteCode;

  final List<String> memberUids;
  final DateTime createdAt;

  bool contains(String uid) => memberUids.contains(uid);

  Map<String, Object?> toJson() => {
    'inviteCode': inviteCode,
    'memberUids': memberUids,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Household.fromJson(String id, Map<String, Object?> json) => Household(
    id: id,
    inviteCode: json['inviteCode'] as String? ?? '',
    memberUids: ((json['memberUids'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  /// 초대 코드를 만든다.
  ///
  /// 사람이 불러주고 받아 적는 코드라서 헷갈리는 글자(0/O, 1/I/L)는 뺐다.
  /// 6자리면 대략 10억 가지라 두 사람이 쓰기에 충분하다.
  static String generateCode([Random? random]) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rng = random ?? Random.secure();
    return List.generate(
      6,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
  }

  /// 입력한 코드를 비교 가능한 형태로. 소문자로 적거나 공백이 섞여도 통한다.
  static String normalizeCode(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
}
