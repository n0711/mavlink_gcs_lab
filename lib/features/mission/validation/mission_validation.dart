enum MissionValidationSeverity { info, warning, error }

class MissionValidationIssue {
  const MissionValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.waypointId,
  });

  final MissionValidationSeverity severity;
  final String code;
  final String message;
  final String? waypointId;
}

class MissionValidationResult {
  const MissionValidationResult({required this.issues});

  final List<MissionValidationIssue> issues;

  bool get isValid {
    return issues.every(
      (issue) => issue.severity != MissionValidationSeverity.error,
    );
  }
}
