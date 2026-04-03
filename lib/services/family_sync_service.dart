import '../models/family_workspace_model.dart';

abstract class FamilySyncService {
  Future<FamilyWorkspace> createWorkspace({
    required String workspaceName,
    required String ownerUserId,
    required String ownerDisplayName,
  });

  Future<FamilyWorkspace> joinWorkspace({
    required String inviteCode,
    required String userId,
    required String displayName,
  });

  Future<FamilyWorkspace?> getCurrentWorkspace({required String userId});

  Future<List<FamilyMember>> getFamilyMembers({required String workspaceId});
}

class InMemoryFamilySyncService implements FamilySyncService {
  FamilyWorkspace? _workspace;
  final List<FamilyMember> _members = [];

  @override
  Future<FamilyWorkspace> createWorkspace({
    required String workspaceName,
    required String ownerUserId,
    required String ownerDisplayName,
  }) async {
    final now = DateTime.now();
    final inviteCode = _buildInviteCode(workspaceName, now);
    _workspace = FamilyWorkspace(
      id: '${now.microsecondsSinceEpoch}',
      name: workspaceName,
      inviteCode: inviteCode,
      createdByUserId: ownerUserId,
      createdAt: now,
    );

    _members
      ..clear()
      ..add(
        FamilyMember(
          userId: ownerUserId,
          displayName: ownerDisplayName,
          role: FamilyRole.admin,
          monthlySpend: 0,
        ),
      );

    return _workspace!;
  }

  @override
  Future<FamilyWorkspace?> getCurrentWorkspace({required String userId}) async {
    return _workspace;
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers({
    required String workspaceId,
  }) async {
    return List<FamilyMember>.from(_members);
  }

  @override
  Future<FamilyWorkspace> joinWorkspace({
    required String inviteCode,
    required String userId,
    required String displayName,
  }) async {
    final workspace = _workspace;
    if (workspace == null || workspace.inviteCode != inviteCode) {
      throw StateError('Invalid invite code or workspace not initialized');
    }

    final exists = _members.any((m) => m.userId == userId);
    if (!exists) {
      _members.add(
        FamilyMember(
          userId: userId,
          displayName: displayName,
          role: FamilyRole.member,
          monthlySpend: 0,
        ),
      );
    }

    return workspace;
  }

  String _buildInviteCode(String workspaceName, DateTime now) {
    final seed = workspaceName
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final head = seed.isEmpty
        ? 'FAM'
        : seed.substring(0, seed.length >= 3 ? 3 : seed.length);
    final tail = (now.millisecond % 1000).toString().padLeft(3, '0');
    return '$head$tail';
  }
}
