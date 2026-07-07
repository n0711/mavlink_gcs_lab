import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/log_replay_helper_resolver.dart';

void main() {
  test('uses explicit replay helper environment variable first', () {
    final path = resolveReplayHelperPath({
      replayHelperPathEnvironmentVariable: '/opt/replay/replay_log_to_udp.py',
      'HOME': '/home/operator',
    });

    expect(path, '/opt/replay/replay_log_to_udp.py');
  });

  test('falls back to documented home-relative replay helper path', () {
    final path = resolveReplayHelperPath({'HOME': '/home/operator'});

    expect(path, '/home/operator/tools/replay_log_to_udp.py');
  });

  test('returns null when no replay helper path can be resolved', () {
    expect(resolveReplayHelperPath(const {}), isNull);
  });
}
