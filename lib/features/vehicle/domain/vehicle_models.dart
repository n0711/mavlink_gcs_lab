import 'package:mavlink_gcs_portfolio/features/link/domain/link_models.dart';

enum VehicleType { uav, usv, unknown }

class VehicleIdentity {
  const VehicleIdentity({
    this.systemId,
    this.componentId,
    this.vehicleType = VehicleType.unknown,
    this.label,
  });

  final int? systemId;
  final int? componentId;
  final VehicleType vehicleType;
  final String? label;
}

class VehicleMode {
  const VehicleMode({
    required this.rawMode,
    required this.normalizedMode,
    required this.autopilotName,
  });

  final String rawMode;
  final String normalizedMode;
  final String autopilotName;
}

class VehiclePosition {
  const VehiclePosition({
    this.latitude,
    this.longitude,
    this.altitudeMeters,
    this.headingDegrees,
  });

  final double? latitude;
  final double? longitude;
  final double? altitudeMeters;
  final double? headingDegrees;
}

class VehicleBattery {
  const VehicleBattery({this.voltage, this.current, this.remainingPercent});

  final double? voltage;
  final double? current;
  final int? remainingPercent;
}

class VehicleGps {
  const VehicleGps({this.fixType, this.satellitesVisible, this.hdop});

  final int? fixType;
  final int? satellitesVisible;
  final double? hdop;

  bool get isHealthy {
    final fix = fixType;
    if (fix == null || fix < 3) return false;
    final satellites = satellitesVisible;
    if (satellites != null && satellites < 6) return false;
    final dilution = hdop;
    if (dilution != null && dilution > 2.5) return false;
    return true;
  }
}

class VehicleAttitude {
  const VehicleAttitude({this.rollDeg, this.pitchDeg, this.yawDeg});

  final double? rollDeg;
  final double? pitchDeg;
  final double? yawDeg;
}

class VehicleState {
  const VehicleState({
    required this.identity,
    required this.mode,
    required this.position,
    required this.battery,
    required this.gps,
    required this.attitude,
    required this.isArmed,
    required this.lastTelemetryAt,
    required this.linkHealth,
    this.telemetryStaleAfter = const Duration(seconds: 5),
  });

  final VehicleIdentity identity;
  final VehicleMode mode;
  final VehiclePosition position;
  final VehicleBattery battery;
  final VehicleGps gps;
  final VehicleAttitude attitude;
  final bool isArmed;
  final DateTime lastTelemetryAt;
  final LinkHealth linkHealth;
  final Duration telemetryStaleAfter;

  bool get isTelemetryStale {
    return linkHealth.isStale ||
        DateTime.now().difference(lastTelemetryAt) > telemetryStaleAfter;
  }
}
