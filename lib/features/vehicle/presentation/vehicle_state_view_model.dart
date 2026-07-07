import 'package:mavlink_gcs_portfolio/features/vehicle/domain/vehicle_models.dart';

class VehicleStateViewModel {
  const VehicleStateViewModel(this.state);

  final VehicleState state;

  String get vehicleLabel => state.identity.label ?? 'Unknown vehicle';

  String get safetyLabel => state.isArmed ? 'ARMED' : 'DISARMED';
}
