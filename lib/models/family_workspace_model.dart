enum FamilyRole { admin, member }

class FamilyWorkspace {
  final String id;
  final String name;
  final String inviteCode;
  final String createdByUserId;
  final DateTime createdAt;

  const FamilyWorkspace({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdByUserId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'created_by_user_id': createdByUserId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FamilyWorkspace.fromMap(Map<String, dynamic> map) {
    return FamilyWorkspace(
      id: map['id'] as String,
      name: map['name'] as String,
      inviteCode: map['invite_code'] as String,
      createdByUserId: map['created_by_user_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class FamilyMember {
  final String userId;
  final String displayName;
  final FamilyRole role;
  final double monthlySpend;

  const FamilyMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.monthlySpend,
  });

  FamilyMember copyWith({
    String? userId,
    String? displayName,
    FamilyRole? role,
    double? monthlySpend,
  }) {
    return FamilyMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      monthlySpend: monthlySpend ?? this.monthlySpend,
    );
  }
}
