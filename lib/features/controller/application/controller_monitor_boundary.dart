import 'package:mavlink_gcs_portfolio/features/controller/domain/controller_models.dart';

abstract class ControllerMonitorBoundary {
  Stream<ControllerInputSnapshot> get inputSnapshots;
}
