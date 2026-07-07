import 'package:mavlink_gcs_portfolio/features/vehicle/domain/vehicle_models.dart';

enum AutopilotType { ardupilot, px4, unknown }

abstract class AutopilotAdapter {
  AutopilotType get type;

  String get displayName;

  VehicleMode normalizeMode(String? rawMode);

  String describeHealth(VehicleState state);

  bool get supportsMissionUpload;

  bool get supportsCommandAuthority;
}
