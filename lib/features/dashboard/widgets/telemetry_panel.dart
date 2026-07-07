import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/attitude_panel.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/metric_tile.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

class TelemetryPanel extends StatelessWidget {
  const TelemetryPanel({
    super.key,
    required this.telemetry,
    required this.isWaiting,
    required this.isStale,
    required this.isCompact,
  });

  final VehicleSnapshot? telemetry;
  final bool isWaiting;
  final bool isStale;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VehicleStateCard(
          telemetry: telemetry,
          isWaiting: isWaiting,
          isStale: isStale,
        ),
        const SizedBox(height: 16),
        _PositionCard(telemetry: telemetry, isCompact: isCompact),
        const SizedBox(height: 16),
        AttitudePanel(telemetry: telemetry),
      ],
    );
  }
}

class _VehicleStateCard extends StatelessWidget {
  const _VehicleStateCard({
    required this.telemetry,
    required this.isWaiting,
    required this.isStale,
  });

  final VehicleSnapshot? telemetry;
  final bool isWaiting;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final isArmed = telemetry?.isArmed ?? false;
    final linkState = isWaiting
        ? 'Disconnected'
        : isStale
        ? 'Stale'
        : 'Live';
    final linkColor = isWaiting
        ? const Color(0xFF98A6B3)
        : isStale
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF65D890);

    final values = [
      MetricData(
        icon: isArmed ? Icons.warning_amber : Icons.verified_user,
        label: 'Vehicle state',
        value: isArmed ? 'ARMED' : 'DISARMED',
        color: isArmed
            ? Theme.of(context).colorScheme.error
            : const Color(0xFF65D890),
      ),
      MetricData(
        icon: Icons.tune,
        label: 'Mode',
        value: _formattedMode(telemetry?.mode),
        color: const Color(0xFF7DC6FF),
      ),
      MetricData(
        icon: Icons.battery_charging_full,
        label: 'Battery',
        value: _formatBatteryPercent(telemetry?.batteryPct),
        color: _batteryColor(context, telemetry?.batteryPct),
      ),
      MetricData(
        icon: Icons.bolt,
        label: 'Battery voltage',
        value: _formatVoltage(telemetry?.batteryVoltageV),
        color: const Color(0xFF98A6B3),
      ),
      MetricData(
        icon: Icons.link,
        label: 'Link state',
        value: linkState,
        color: linkColor,
      ),
      MetricData(
        icon: Icons.input,
        label: 'Telemetry source',
        value: _formatSourceType(telemetry?.telemetrySourceType),
        color: const Color(0xFF7DC6FF),
      ),
      MetricData(
        icon: Icons.settings_ethernet,
        label: 'Bind address',
        value: telemetry?.telemetryBindAddress ?? '127.0.0.1:16000',
        color: const Color(0xFF98A6B3),
      ),
      MetricData(
        icon: Icons.error_outline,
        label: 'Parse errors',
        value: '${telemetry?.telemetryParseErrorCount ?? 0}',
        color: (telemetry?.telemetryParseErrorCount ?? 0) > 0
            ? Theme.of(context).colorScheme.error
            : const Color(0xFF65D890),
      ),
      MetricData(
        icon: Icons.speed,
        label: 'Adapter rate',
        value: telemetry == null
            ? '-- Hz'
            : '${telemetry!.telemetryMessageRateHz.toStringAsFixed(1)} Hz',
        color: const Color(0xFF98A6B3),
      ),
    ];

    return _DashboardCard(
      title: 'Vehicle State',
      badge: 'Monitor',
      child: _MetricWrap(values: values),
    );
  }

  Color _batteryColor(BuildContext context, int? batteryPct) {
    if (batteryPct == null) return const Color(0xFF98A6B3);
    if (batteryPct < 20) return Theme.of(context).colorScheme.error;
    if (batteryPct < 40) return Theme.of(context).colorScheme.secondary;
    return const Color(0xFF65D890);
  }

  String _formatBatteryPercent(int? batteryPct) {
    return batteryPct == null ? '--%' : '$batteryPct%';
  }

  String _formatVoltage(double? voltage) {
    return voltage == null ? '-- V' : '${voltage.toStringAsFixed(1)} V';
  }

  String _formattedMode(String? rawMode) {
    final mode = rawMode?.trim();
    if (mode == null || mode.isEmpty || mode == 'UNKNOWN') return 'UNKNOWN';
    if (RegExp(r'^\d+$').hasMatch(mode)) return 'Mode $mode';
    return mode;
  }

  String _formatSourceType(String? sourceType) {
    if (sourceType == null || sourceType.trim().isEmpty) {
      return 'UDP JSON adapter';
    }
    return sourceType.replaceAll(' telemetry adapter', ' adapter');
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.telemetry, required this.isCompact});

  final VehicleSnapshot? telemetry;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final hasNoFix = _positionUnavailable;
    final values = [
      MetricData(
        icon: Icons.my_location,
        label: 'Latitude',
        value: hasNoFix
            ? 'Position unavailable'
            : _formatDegrees(telemetry?.latitude),
      ),
      MetricData(
        icon: Icons.explore,
        label: 'Longitude',
        value: hasNoFix ? 'No GPS fix' : _formatDegrees(telemetry?.longitude),
      ),
      MetricData(
        icon: Icons.height,
        label: 'Altitude / relative height',
        value: telemetry?.altitudeM == null
            ? '--.- m'
            : '${telemetry!.altitudeM!.toStringAsFixed(1)} m',
      ),
    ];

    return _DashboardCard(
      title: 'Position',
      badge: 'GPS',
      child: _MetricGrid(values: values, isCompact: isCompact),
    );
  }

  bool get _positionUnavailable {
    final snapshot = telemetry;
    if (snapshot == null) return false;
    final latitude = snapshot.latitude;
    final longitude = snapshot.longitude;
    if (latitude == null || longitude == null) return true;
    final fixType = snapshot.gpsFixType;
    final hasFix = fixType != null && fixType >= 2;
    return !hasFix && latitude == 0.0 && longitude == 0.0;
  }

  String _formatDegrees(double? value) {
    return value == null ? '--.------ deg' : '${value.toStringAsFixed(6)} deg';
  }
}

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.values});

  final List<MetricData> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: values
          .map(
            (value) => SizedBox(
              width: 230,
              height: 104,
              child: MetricTile(data: value),
            ),
          )
          .toList(),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values, required this.isCompact});

  final List<MetricData> values;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: values.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 1 : 3,
        mainAxisExtent: 104,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => MetricTile(data: values[index]),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.badge,
    required this.child,
  });

  final String title;
  final String badge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.38),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
