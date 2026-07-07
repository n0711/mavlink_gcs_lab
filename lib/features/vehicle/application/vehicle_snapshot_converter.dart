import 'package:mavlink_gcs_portfolio/features/link/domain/link_models.dart';
import 'package:mavlink_gcs_portfolio/features/vehicle/domain/vehicle_models.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

VehicleState vehicleStateFromSnapshot(
  VehicleSnapshot snapshot, {
  DateTime? receivedAt,
}) {
  final timestamp = receivedAt ?? DateTime.now();
  final rawMode = snapshot.mode?.trim();

  return VehicleState(
    identity: VehicleIdentity(
      systemId: snapshot.vehicleSysid,
      componentId: snapshot.vehicleCompid,
      vehicleType: VehicleType.unknown,
      label: snapshot.lockedVehicleSource
          ? 'sysid ${snapshot.vehicleSysid ?? '--'} / compid ${snapshot.vehicleCompid ?? '--'}'
          : null,
    ),
    mode: VehicleMode(
      rawMode: rawMode == null || rawMode.isEmpty ? 'UNKNOWN' : rawMode,
      normalizedMode: rawMode == null || rawMode.isEmpty ? 'unknown' : rawMode,
      autopilotName: 'unknown',
    ),
    position: VehiclePosition(
      latitude: snapshot.latitude,
      longitude: snapshot.longitude,
      altitudeMeters: snapshot.altitudeM,
      headingDegrees: snapshot.yawDeg,
    ),
    battery: VehicleBattery(
      voltage: snapshot.batteryVoltageV,
      current: snapshot.batteryCurrentA,
      remainingPercent: snapshot.batteryPct,
    ),
    gps: VehicleGps(
      fixType: snapshot.gpsFixType,
      satellitesVisible: snapshot.satellitesVisible,
      hdop: snapshot.hdop,
    ),
    attitude: VehicleAttitude(
      rollDeg: snapshot.rollDeg,
      pitchDeg: snapshot.pitchDeg,
      yawDeg: snapshot.yawDeg,
    ),
    isArmed: snapshot.isArmed,
    lastTelemetryAt: timestamp,
    linkHealth: LinkHealth(
      status: LinkStatus.connected,
      lastMessageAt: timestamp,
      messageRateHz: _bestMessageRate(snapshot),
    ),
  );
}

double? _bestMessageRate(VehicleSnapshot snapshot) {
  if (snapshot.messageRates.isEmpty) return null;
  final activeRates = snapshot.messageRates
      .map((rate) => rate.rateHz)
      .where((rateHz) => rateHz > 0);
  if (activeRates.isEmpty) return 0;
  return activeRates.reduce((a, b) => a > b ? a : b);
}
