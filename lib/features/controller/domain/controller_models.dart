enum ControllerConnectionStatus {
  disconnected,
  connected,
  monitorOnly,
  commandDisabled,
  error,
}

class ControllerProfile {
  const ControllerProfile({
    required this.id,
    required this.name,
    required this.deviceNamePattern,
    this.notes,
  });

  final String id;
  final String name;
  final String deviceNamePattern;
  final String? notes;
}

class ControllerInputSnapshot {
  const ControllerInputSnapshot({
    required this.timestamp,
    this.axes = const {},
    this.buttons = const {},
    this.status = ControllerConnectionStatus.monitorOnly,
  });

  final DateTime timestamp;
  final Map<String, double> axes;
  final Map<String, bool> buttons;
  final ControllerConnectionStatus status;

  bool get isMonitorOnly => status == ControllerConnectionStatus.monitorOnly;
}
