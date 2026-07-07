import 'package:mavlink_gcs_portfolio/features/vehicle/domain/vehicle_models.dart';

class SessionId {
  const SessionId(this.value);

  final String value;
}

class OperatorAction {
  const OperatorAction({
    required this.id,
    required this.timestamp,
    required this.actor,
    required this.actionType,
    required this.description,
    this.relatedMissionId,
    this.relatedVehicleId,
  });

  final String id;
  final DateTime timestamp;
  final String actor;
  final String actionType;
  final String description;
  final String? relatedMissionId;
  final String? relatedVehicleId;
}

class TelemetryLogEntry {
  const TelemetryLogEntry({
    required this.timestamp,
    required this.vehicleState,
  });

  final DateTime timestamp;
  final VehicleState vehicleState;
}

class SessionLogMetadata {
  const SessionLogMetadata({
    required this.sessionId,
    required this.startedAt,
    this.endedAt,
    this.operatorName,
    this.vehicleIdentity,
    this.notes,
  });

  final SessionId sessionId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? operatorName;
  final VehicleIdentity? vehicleIdentity;
  final String? notes;
}
