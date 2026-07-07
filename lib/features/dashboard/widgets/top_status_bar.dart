import 'package:flutter/material.dart';

class TopStatusBar extends StatelessWidget {
  const TopStatusBar({
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
    final linkStatus = isWaiting
        ? 'Disconnected'
        : isStale
        ? 'Stale'
        : 'Live';
    final linkColor = isWaiting
        ? const Color(0xFF98A6B3)
        : isStale
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF65D890);

    return LayoutBuilder(
      builder: (context, constraints) {
        final statusItems = [
          const _SafetyBadge(),
          const _StatusItem(
            icon: Icons.lock,
            label: 'Command authority',
            value: 'Disabled',
            color: Color(0xFFFFCF70),
          ),
          _StatusItem(
            icon: Icons.link,
            label: 'Link status',
            value: linkStatus,
            color: linkColor,
          ),
          _StatusItem(
            icon: Icons.call_received,
            label: 'Packets',
            value: packetCount.toString(),
            color: const Color(0xFF7DC6FF),
          ),
          _StatusItem(
            icon: Icons.schedule,
            label: 'Last packet',
            value: lastPacketAt == null
                ? '--:--:--'
                : TimeOfDay.fromDateTime(lastPacketAt!).format(context),
            color: const Color(0xFFE7EDF3),
          ),
        ];

        final statusWrap = Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: statusItems,
        );

        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BrandBlock(),
              const SizedBox(height: 12),
              statusWrap,
            ],
          );
        }

        return Row(
          children: [
            const Expanded(child: _BrandBlock()),
            const SizedBox(width: 18),
            Flexible(flex: 3, child: statusWrap),
          ],
        );
      },
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MAVLink GCS Portfolio',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFFF5F7FA),
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Robotics Telemetry Lab',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF98A6B3),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SafetyBadge extends StatelessWidget {
  const _SafetyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF65D890).withValues(alpha: 0.12),
        border: Border.all(
          color: const Color(0xFF65D890).withValues(alpha: 0.42),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility, color: Color(0xFF65D890), size: 18),
          SizedBox(width: 8),
          Text(
            'Receive-only telemetry',
            style: TextStyle(
              color: Color(0xFF65D890),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
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
      height: 44,
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF98A6B3),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
