import 'package:flutter/material.dart';

class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.packetCount,
    required this.lastPacketAt,
    required this.isWaiting,
    required this.isStale,
  });

  final int packetCount;
  final DateTime? lastPacketAt;
  final bool isWaiting;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        const _StatusPill(
          icon: Icons.lan,
          label: 'UDP endpoint',
          value: '127.0.0.1:16000',
          color: Color(0xFF7DC6FF),
        ),
        _StatusPill(
          icon: isWaiting || isStale ? Icons.sync_problem : Icons.sync,
          label: 'Telemetry link',
          value: isWaiting
              ? 'Waiting'
              : isStale
              ? 'Stale'
              : 'Live',
          color: isWaiting
              ? const Color(0xFF7DC6FF)
              : isStale
              ? Theme.of(context).colorScheme.error
              : const Color(0xFF65D890),
        ),
        _StatusPill(
          icon: Icons.call_received,
          label: 'Packets seen',
          value: packetCount.toString(),
          color: const Color(0xFFFFCF70),
        ),
        _StatusPill(
          icon: Icons.schedule,
          label: 'Last packet',
          value: lastPacketAt == null
              ? '--:--:--'
              : TimeOfDay.fromDateTime(lastPacketAt!).format(context),
          color: const Color(0xFFE7EDF3),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF98A6B3)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF5F7FA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
