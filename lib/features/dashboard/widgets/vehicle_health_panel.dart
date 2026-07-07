import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

class VehicleHealthPanel extends StatelessWidget {
  const VehicleHealthPanel({
    super.key,
    required this.telemetry,
    required this.isWaiting,
    required this.isStale,
  });

  final VehicleSnapshot? telemetry;
  final bool isWaiting;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vehicle Health',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HealthCard(
                  label: 'Vehicle source',
                  value: _sourceText,
                  state: telemetry?.lockedVehicleSource == true
                      ? _HealthState.healthy
                      : _HealthState.unavailable,
                ),
                _HealthCard(
                  label: 'Heartbeat age',
                  value: _formatAge(telemetry?.heartbeatAgeS),
                  state: _ageState(telemetry?.heartbeatAgeS, 2.5),
                ),
                _HealthCard(
                  label: 'Attitude age',
                  value: _formatAge(telemetry?.attitudeAgeS),
                  state: _ageState(telemetry?.attitudeAgeS, 1.0),
                ),
                _HealthCard(
                  label: 'GPS fix / satellites',
                  value: _gpsText,
                  state: _gpsState,
                ),
                _HealthCard(
                  label: 'Battery validity',
                  value: _batteryText,
                  state: _batteryState,
                ),
                _HealthCard(
                  label: 'Last MAVLink message',
                  value: telemetry?.lastMessageType ?? '--',
                  state: telemetry?.lastMessageType == null
                      ? _HealthState.unavailable
                      : _HealthState.live,
                ),
                _HealthCard(
                  label: 'Link state',
                  value: isWaiting
                      ? 'Disconnected'
                      : isStale
                      ? 'Stale'
                      : 'Live',
                  state: isWaiting
                      ? _HealthState.unavailable
                      : isStale
                      ? _HealthState.stale
                      : _HealthState.live,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SourceLine(
              yawSource: telemetry?.yawSource,
              headingSource: telemetry?.headingSource,
            ),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'MAVLink Inspector Lite',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFFE7EDF3),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: const Text(
                  'Read-only message rates and counts',
                  style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
                ),
                children: [
                  _InspectorTable(rows: telemetry?.messageRates ?? const []),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _sourceText {
    final sysid = telemetry?.vehicleSysid;
    final compid = telemetry?.vehicleCompid;
    if (sysid == null || compid == null) return 'Unavailable';
    return 'sysid $sysid / compid $compid';
  }

  String get _gpsText {
    final fix = telemetry?.gpsFixType;
    final sats = telemetry?.satellitesVisible;
    if (fix == null && sats == null) return 'Unavailable';
    return 'fix ${fix ?? '--'} / sats ${sats ?? '--'}';
  }

  _HealthState get _gpsState {
    final fix = telemetry?.gpsFixType;
    if (fix == null) return _HealthState.unavailable;
    return fix >= 2 ? _HealthState.healthy : _HealthState.unverified;
  }

  String get _batteryText {
    final validity = telemetry?.batteryValidity;
    final source = telemetry?.batterySource;
    if (validity == null || validity.isEmpty) return 'Unavailable';
    if (source == null || source.isEmpty) return validity;
    return '$validity / $source';
  }

  _HealthState get _batteryState {
    final validity = telemetry?.batteryValidity;
    if (validity == 'Valid') return _HealthState.healthy;
    if (validity == 'Unverified') return _HealthState.unverified;
    return _HealthState.unavailable;
  }

  String _formatAge(double? ageSeconds) {
    return ageSeconds == null ? '-- s' : '${ageSeconds.toStringAsFixed(1)} s';
  }

  _HealthState _ageState(double? ageSeconds, double staleAfterSeconds) {
    if (ageSeconds == null) return _HealthState.unavailable;
    return ageSeconds > staleAfterSeconds
        ? _HealthState.stale
        : _HealthState.live;
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.yawSource, required this.headingSource});

  final String? yawSource;
  final String? headingSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Yaw source: ${yawSource ?? '--'}  ·  Heading source: ${headingSource ?? '--'}',
        style: const TextStyle(color: Color(0xFFC8D2DC), fontSize: 12),
      ),
    );
  }
}

class _InspectorTable extends StatelessWidget {
  const _InspectorTable({required this.rows});

  final List<MessageRateSnapshot> rows;

  @override
  Widget build(BuildContext context) {
    final displayRows = rows.isEmpty
        ? const <MessageRateSnapshot>[
            MessageRateSnapshot(
              messageType: 'HEARTBEAT',
              count: 0,
              rateHz: 0.0,
            ),
            MessageRateSnapshot(messageType: 'ATTITUDE', count: 0, rateHz: 0.0),
          ]
        : rows;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const _InspectorRow(
            messageType: 'Message type',
            rate: 'Rate Hz',
            count: 'Count',
            age: 'Age',
            isHeader: true,
          ),
          ...displayRows.map(
            (row) => _InspectorRow(
              messageType: row.messageType,
              rate: row.rateHz.toStringAsFixed(1),
              count: row.count.toString(),
              age: row.ageMs == null ? '--' : '${row.ageMs} ms',
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({
    required this.messageType,
    required this.rate,
    required this.count,
    required this.age,
    this.isHeader = false,
  });

  final String messageType;
  final String rate;
  final String count;
  final String age;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final color = isHeader ? const Color(0xFF98A6B3) : const Color(0xFFE7EDF3);
    final weight = isHeader ? FontWeight.w800 : FontWeight.w600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              messageType,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: weight, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              rate,
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: weight, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              count,
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: weight, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              age,
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: weight, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.label,
    required this.value,
    required this.state,
  });

  final String label;
  final String value;
  final _HealthState state;

  @override
  Widget build(BuildContext context) {
    final color = state.color(context);
    return Container(
      width: 176,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(state.icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF98A6B3),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

enum _HealthState {
  healthy,
  live,
  stale,
  unavailable,
  unverified;

  IconData get icon {
    switch (this) {
      case _HealthState.healthy:
      case _HealthState.live:
        return Icons.check_circle;
      case _HealthState.stale:
        return Icons.schedule;
      case _HealthState.unavailable:
        return Icons.help_outline;
      case _HealthState.unverified:
        return Icons.info_outline;
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case _HealthState.healthy:
      case _HealthState.live:
        return const Color(0xFF65D890);
      case _HealthState.stale:
        return Theme.of(context).colorScheme.error;
      case _HealthState.unavailable:
        return const Color(0xFF98A6B3);
      case _HealthState.unverified:
        return const Color(0xFFFFCF70);
    }
  }
}
