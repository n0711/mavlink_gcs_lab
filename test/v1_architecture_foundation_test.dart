import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/features/autopilot/ardupilot/ardupilot_adapter.dart';
import 'package:mavlink_gcs_portfolio/features/autopilot/px4/px4_adapter.dart';
import 'package:mavlink_gcs_portfolio/features/controller/domain/controller_models.dart';
import 'package:mavlink_gcs_portfolio/features/link/domain/link_models.dart';
import 'package:mavlink_gcs_portfolio/features/mission/approval/mission_approval.dart';
import 'package:mavlink_gcs_portfolio/features/mission/domain/mission_models.dart';
import 'package:mavlink_gcs_portfolio/features/mission/validation/mission_validation.dart';
import 'package:mavlink_gcs_portfolio/features/safety/domain/safety_state.dart';
import 'package:mavlink_gcs_portfolio/features/vehicle/application/vehicle_snapshot_converter.dart';
import 'package:mavlink_gcs_portfolio/features/vehicle/domain/vehicle_models.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

void main() {
  group('V1 architecture foundation', () {
    test('VehicleState detects stale telemetry', () {
      final state = _vehicleState(
        lastTelemetryAt: DateTime.now().subtract(const Duration(seconds: 10)),
        linkHealth: LinkHealth(
          status: LinkStatus.connected,
          lastMessageAt: DateTime.now(),
        ),
      );

      expect(state.isTelemetryStale, isTrue);
    });

    test('LinkHealth detects stale connected link', () {
      final health = LinkHealth(
        status: LinkStatus.connected,
        lastMessageAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      expect(health.isStale, isTrue);
    });

    test('MissionPlan reports empty and non-empty plans', () {
      final now = DateTime.utc(2026, 7);
      final empty = MissionPlan(
        id: 'm1',
        name: 'Empty',
        vehicleType: MissionVehicleType.uav,
        waypoints: const [],
        createdAt: now,
        updatedAt: now,
        version: 1,
      );
      final nonEmpty = MissionPlan(
        id: 'm2',
        name: 'Patrol',
        vehicleType: MissionVehicleType.usv,
        waypoints: const [
          MissionWaypoint(id: 'wp1', latitude: 34.0, longitude: 33.0),
        ],
        createdAt: now,
        updatedAt: now,
        version: 1,
      );

      expect(empty.isEmpty, isTrue);
      expect(nonEmpty.isEmpty, isFalse);
    });

    test('MissionValidationResult is valid only without errors', () {
      const warningOnly = MissionValidationResult(
        issues: [
          MissionValidationIssue(
            severity: MissionValidationSeverity.warning,
            code: 'near_boundary',
            message: 'Waypoint is near an operation boundary.',
          ),
        ],
      );
      const withError = MissionValidationResult(
        issues: [
          MissionValidationIssue(
            severity: MissionValidationSeverity.error,
            code: 'outside_zone',
            message: 'Waypoint is outside the approved operation zone.',
            waypointId: 'wp1',
          ),
        ],
      );

      expect(warningOnly.isValid, isTrue);
      expect(withError.isValid, isFalse);
    });

    test('MissionApproval exposes approved and rejected states', () {
      final approved = MissionApproval(
        missionId: 'm1',
        status: MissionApprovalStatus.approved,
        approvedBy: 'operator',
        approvedAt: DateTime.utc(2026, 7),
        missionHash: 'hash',
      );
      const rejected = MissionApproval(
        missionId: 'm1',
        status: MissionApprovalStatus.rejected,
      );

      expect(approved.isApproved, isTrue);
      expect(approved.isRejected, isFalse);
      expect(rejected.isApproved, isFalse);
      expect(rejected.isRejected, isTrue);
    });

    test('ArduPilotAdapter command authority remains disabled', () {
      const adapter = ArduPilotAdapter();

      expect(adapter.supportsMissionUpload, isFalse);
      expect(adapter.supportsCommandAuthority, isFalse);
    });

    test('Px4Adapter command authority remains disabled', () {
      const adapter = Px4Adapter();

      expect(adapter.supportsMissionUpload, isFalse);
      expect(adapter.supportsCommandAuthority, isFalse);
    });

    test('ControllerInputSnapshot defaults to monitor-only', () {
      final snapshot = ControllerInputSnapshot(
        timestamp: DateTime.utc(2026, 7),
      );

      expect(snapshot.status, ControllerConnectionStatus.monitorOnly);
      expect(snapshot.isMonitorOnly, isTrue);
      expect(snapshot.axes, isEmpty);
      expect(snapshot.buttons, isEmpty);
    });

    test('SafetyState defaults command authority to disabled', () {
      const state = SafetyState();

      expect(state.commandAuthorityStatus, CommandAuthorityStatus.disabled);
      expect(state.commandAuthorityDisabled, isTrue);
      expect(state.controlOwner, ControlOwner.gcsMonitorOnly);
    });

    test('converts VehicleSnapshot to VehicleState', () {
      final receivedAt = DateTime.utc(2026, 7);
      const snapshot = VehicleSnapshot(
        latitude: 34.981269,
        longitude: 34.002445,
        altitudeM: 4.8,
        rollDeg: -4.9,
        pitchDeg: 8.0,
        yawDeg: 319.8,
        batteryPct: 74,
        batteryVoltageV: 12.1,
        batteryCurrentA: 2.4,
        isArmed: true,
        mode: 'AUTO',
        gpsFixType: 3,
        satellitesVisible: 10,
        hdop: 0.9,
        vehicleSysid: 1,
        vehicleCompid: 1,
        lockedVehicleSource: true,
        messageRates: [
          MessageRateSnapshot(messageType: 'HEARTBEAT', count: 5, rateHz: 1.0),
        ],
        telemetrySourceType: 'UDP JSON adapter',
        telemetryBindAddress: '127.0.0.1:16000',
        telemetryPacketCount: 4,
        telemetryParseErrorCount: 0,
        telemetryMessageRateHz: 1.0,
        telemetryReceiveOnlyNote:
            'Receive-only V1 adapter: no commands, parameter writes, or mission upload.',
        statusText: 'Decoded vehicle_state JSON',
      );

      final state = vehicleStateFromSnapshot(snapshot, receivedAt: receivedAt);

      expect(state.identity.systemId, 1);
      expect(state.identity.componentId, 1);
      expect(state.mode.rawMode, 'AUTO');
      expect(state.position.latitude, 34.981269);
      expect(state.position.headingDegrees, 319.8);
      expect(state.battery.remainingPercent, 74);
      expect(state.gps.isHealthy, isTrue);
      expect(state.attitude.rollDeg, -4.9);
      expect(state.isArmed, isTrue);
      expect(state.lastTelemetryAt, receivedAt);
      expect(state.linkHealth.status, LinkStatus.connected);
      expect(state.linkHealth.messageRateHz, 1.0);
      expect(snapshot.telemetrySourceType, 'UDP JSON adapter');
      expect(snapshot.telemetryBindAddress, '127.0.0.1:16000');
      expect(snapshot.telemetryParseErrorCount, 0);
      expect(snapshot.telemetryReceiveOnlyNote, contains('Receive-only'));
    });
  });
}

VehicleState _vehicleState({
  required DateTime lastTelemetryAt,
  required LinkHealth linkHealth,
}) {
  return VehicleState(
    identity: const VehicleIdentity(systemId: 1, componentId: 1),
    mode: const VehicleMode(
      rawMode: 'AUTO',
      normalizedMode: 'auto',
      autopilotName: 'ArduPilot',
    ),
    position: const VehiclePosition(),
    battery: const VehicleBattery(),
    gps: const VehicleGps(),
    attitude: const VehicleAttitude(),
    isArmed: false,
    lastTelemetryAt: lastTelemetryAt,
    linkHealth: linkHealth,
  );
}
