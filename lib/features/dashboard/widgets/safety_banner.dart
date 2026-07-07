import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

class SafetyBanner extends StatelessWidget {
  const SafetyBanner({
    super.key,
    required this.telemetry,
    required this.isWaiting,
    required this.isStale,
    required this.secondsSincePacket,
  });

  final VehicleSnapshot? telemetry;
  final bool isWaiting;
  final bool isStale;
  final int? secondsSincePacket;

  @override
  Widget build(BuildContext context) {
    final isArmed = telemetry?.isArmed ?? false;
    final color = isWaiting
        ? const Color(0xFF7DC6FF)
        : isStale || isArmed
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF65D890);
    final icon = isWaiting
        ? Icons.sensors
        : isStale
        ? Icons.signal_wifi_connected_no_internet_4
        : isArmed
        ? Icons.warning_amber
        : Icons.verified_user;
    final title = isWaiting
        ? 'Waiting for telemetry'
        : isStale
        ? 'Telemetry stale'
        : isArmed
        ? 'Vehicle reports ARMED'
        : 'Vehicle disarmed';
    final detail = isWaiting
        ? 'Listening on 127.0.0.1:16000 for compact vehicle-state JSON.'
        : isStale
        ? 'No new packets received. Last-known values remain displayed; expected after replay ends.'
        : isArmed
        ? 'Receive-only telemetry baseline: watch vehicle state only. Command authority is disabled.'
        : 'Receive-only telemetry is active. Command authority is disabled.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: Color(0xFFC8D2DC))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
