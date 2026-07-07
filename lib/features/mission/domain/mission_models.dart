enum MissionVehicleType { uav, usv }

class MissionWaypoint {
  const MissionWaypoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.altitudeMeters,
    this.speedMetersPerSecond,
    this.acceptanceRadiusMeters,
    this.holdSeconds,
    this.notes,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double? altitudeMeters;
  final double? speedMetersPerSecond;
  final double? acceptanceRadiusMeters;
  final double? holdSeconds;
  final String? notes;
}

class MissionPlan {
  const MissionPlan({
    required this.id,
    required this.name,
    required this.vehicleType,
    required this.waypoints,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final String name;
  final MissionVehicleType vehicleType;
  final List<MissionWaypoint> waypoints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  bool get isEmpty => waypoints.isEmpty;
}
