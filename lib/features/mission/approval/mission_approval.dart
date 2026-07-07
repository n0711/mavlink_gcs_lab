enum MissionApprovalStatus {
  draft,
  pendingApproval,
  approved,
  rejected,
  expired,
}

class MissionApproval {
  const MissionApproval({
    required this.missionId,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.missionHash,
    this.notes,
  });

  final String missionId;
  final MissionApprovalStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? missionHash;
  final String? notes;

  bool get isApproved => status == MissionApprovalStatus.approved;

  bool get isRejected => status == MissionApprovalStatus.rejected;
}
