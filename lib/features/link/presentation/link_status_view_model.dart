import 'package:mavlink_gcs_portfolio/features/link/domain/link_models.dart';

class LinkStatusViewModel {
  const LinkStatusViewModel({required this.label, required this.status});

  final String label;
  final LinkStatus status;

  bool get shouldWarn =>
      status == LinkStatus.stale || status == LinkStatus.error;
}
