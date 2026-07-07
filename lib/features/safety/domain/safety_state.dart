enum CommandAuthorityStatus {
  disabled,
  monitorOnly,
  missionUploadOnly,
  commandEnabled,
}

enum ControlOwner {
  none,
  autopilotMission,
  externalRc,
  gcsMonitorOnly,
  gcsCommand,
  failsafe,
}

class SafetyState {
  const SafetyState({
    this.commandAuthorityStatus = CommandAuthorityStatus.disabled,
    this.controlOwner = ControlOwner.gcsMonitorOnly,
    this.telemetryStale = false,
    this.linkHealthy = false,
    this.missionApproved = false,
    this.warnings = const [],
  });

  final CommandAuthorityStatus commandAuthorityStatus;
  final ControlOwner controlOwner;
  final bool telemetryStale;
  final bool linkHealthy;
  final bool missionApproved;
  final List<String> warnings;

  bool get commandAuthorityDisabled {
    return commandAuthorityStatus == CommandAuthorityStatus.disabled ||
        commandAuthorityStatus == CommandAuthorityStatus.monitorOnly;
  }
}
