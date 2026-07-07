const replayHelperPathEnvironmentVariable = 'MAVLINK_GCS_REPLAY_HELPER';
const replayHelperRelativePath = 'tools/replay_log_to_udp.py';

String? resolveReplayHelperPath(Map<String, String> environment) {
  final configured = environment[replayHelperPathEnvironmentVariable]?.trim();
  if (configured != null && configured.isNotEmpty) return configured;

  final home = environment['HOME']?.trim();
  if (home == null || home.isEmpty) return null;
  return '$home/$replayHelperRelativePath';
}

String replayHelperPathHelp(String? resolvedPath) {
  if (resolvedPath == null) {
    return 'Set HOME or $replayHelperPathEnvironmentVariable to the replay helper path.';
  }
  return 'Missing: $resolvedPath. Set $replayHelperPathEnvironmentVariable to override.';
}
