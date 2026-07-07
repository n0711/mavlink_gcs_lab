import 'package:mavlink_gcs_portfolio/features/link/domain/link_models.dart';

abstract class LinkManagerBoundary {
  Stream<LinkHealth> get healthStream;

  LinkEndpoint? get activeEndpoint;
}
