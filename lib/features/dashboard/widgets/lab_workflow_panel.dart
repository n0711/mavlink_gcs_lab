import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

class MilestoneStatusPanel extends StatelessWidget {
  const MilestoneStatusPanel({super.key, required this.telemetry});

  final VehicleSnapshot? telemetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _PanelHeader(title: 'Milestone Status', badge: '0.2 / 0.3'),
            const SizedBox(height: 14),
            _WorkflowStep(
              icon: Icons.sensors,
              title: 'Telemetry receive',
              detail: telemetry == null
                  ? 'Listening for vehicle_state packets.'
                  : 'Decoded vehicle_state packets are updating the dashboard.',
              state: telemetry == null ? _StepState.pending : _StepState.good,
            ),
            const _WorkflowStep(
              icon: Icons.map_outlined,
              title: 'Mission upload',
              detail: 'Not available in this milestone.',
              state: _StepState.locked,
            ),
            const _WorkflowStep(
              icon: Icons.tune,
              title: 'Mode and actuator control',
              detail:
                  'Not available until the safety architecture is reviewed.',
              state: _StepState.locked,
            ),
            _WorkflowStep(
              icon: Icons.health_and_safety,
              title: 'Safety status display',
              detail:
                  'Armed state, link state, battery, attitude, and position are visible for lab monitoring.',
              state: telemetry == null ? _StepState.pending : _StepState.good,
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { good, pending, locked }

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.icon,
    required this.title,
    required this.detail,
    required this.state,
  });

  final IconData icon;
  final String title;
  final String detail;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.good => const Color(0xFF65D890),
      _StepState.pending => const Color(0xFF7DC6FF),
      _StepState.locked => const Color(0xFFFFCF70),
    };
    final stateIcon = switch (state) {
      _StepState.good => Icons.check_circle,
      _StepState.pending => Icons.radio_button_unchecked,
      _StepState.locked => Icons.lock,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF98A6B3),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(stateIcon, color: color, size: 20),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.badge});

  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    );
  }
}
