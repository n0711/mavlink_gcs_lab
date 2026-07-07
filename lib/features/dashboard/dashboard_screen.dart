import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/command_lockout_panel.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/future_modules_panel.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/log_replay_panel.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/parameter_viewer_panel.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/safety_banner.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/telemetry_panel.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/top_status_bar.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/widgets/vehicle_health_panel.dart';
import 'package:mavlink_gcs_portfolio/features/logging/application/gcs_session_log.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

const _workspaceMaxWidth = 1480.0;
const _packetDiagnosticsEveryCount = 50;
const _packetDiagnosticsInterval = Duration(seconds: 10);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.telemetryStream});

  final Stream<VehicleSnapshot>? telemetryStream;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<VehicleSnapshot>? _telemetrySubscription;
  Timer? _staleRefreshTimer;
  VehicleSnapshot? _latestSnapshot;
  DateTime? _lastPacketAt;
  Object? _streamError;
  var _packetCount = 0;
  late final GcsSessionLog _sessionLog;
  bool _lastStaleState = false;
  DateTime? _lastPacketLogAt;

  @override
  void initState() {
    super.initState();
    _sessionLog = GcsSessionLog();
    unawaited(
      _sessionLog.record('telemetry_source_start', {
        'source_type': 'UDP JSON adapter',
        'bind_address': '127.0.0.1:16000',
        'receive_only': true,
        'safety_note':
            'No commands, parameter writes, mode changes, or mission upload.',
      }),
    );
    final stream = widget.telemetryStream ?? startTelemetryStream();
    _telemetrySubscription = stream.listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _latestSnapshot = snapshot;
          _lastPacketAt = DateTime.now();
          _packetCount += 1;
          _streamError = null;
          _lastStaleState = false;
        });
        final now = DateTime.now();
        if (_shouldRecordPacketDiagnostics(now)) {
          _lastPacketLogAt = now;
          unawaited(
            _sessionLog.record('telemetry_packet_sample', {
              'source_type': snapshot.telemetrySourceType,
              'bind_address': snapshot.telemetryBindAddress,
              'ui_packet_count': _packetCount,
              'backend_packet_count': snapshot.telemetryPacketCount,
              'backend_parse_error_count': snapshot.telemetryParseErrorCount,
              'backend_message_rate_hz': snapshot.telemetryMessageRateHz,
              'last_message_type': snapshot.lastMessageType,
              'status_text': snapshot.statusText,
            }),
          );
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _streamError = error);
        unawaited(
          _sessionLog.record('telemetry_source_error', {
            'source_type': 'UDP JSON adapter',
            'bind_address': '127.0.0.1:16000',
            'error': error.toString(),
            'receive_only': true,
          }),
        );
      },
    );
    _staleRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final isNowStale =
          _lastPacketAt != null &&
          DateTime.now().difference(_lastPacketAt!).inSeconds > 5;
      if (isNowStale && !_lastStaleState) {
        unawaited(
          _sessionLog.record('telemetry_source_stale', {
            'source_type':
                _latestSnapshot?.telemetrySourceType ?? 'UDP JSON adapter',
            'bind_address':
                _latestSnapshot?.telemetryBindAddress ?? '127.0.0.1:16000',
            'seconds_since_packet': DateTime.now()
                .difference(_lastPacketAt!)
                .inSeconds,
            'backend_packet_count': _latestSnapshot?.telemetryPacketCount,
            'backend_parse_error_count':
                _latestSnapshot?.telemetryParseErrorCount,
          }),
        );
      }
      _lastStaleState = isNowStale;
      setState(() {});
    });
  }

  bool _shouldRecordPacketDiagnostics(DateTime now) {
    if (_packetCount == 1) return true;
    if (_packetCount % _packetDiagnosticsEveryCount == 0) return true;
    final lastPacketLogAt = _lastPacketLogAt;
    if (lastPacketLogAt == null) return true;
    return now.difference(lastPacketLogAt) >= _packetDiagnosticsInterval;
  }

  @override
  void dispose() {
    unawaited(
      _sessionLog.record('telemetry_source_stop', {
        'source_type':
            _latestSnapshot?.telemetrySourceType ?? 'UDP JSON adapter',
        'bind_address':
            _latestSnapshot?.telemetryBindAddress ?? '127.0.0.1:16000',
        'packet_count': _packetCount,
        'receive_only': true,
      }),
    );
    _staleRefreshTimer?.cancel();
    _telemetrySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_streamError != null) {
      return Scaffold(body: _FailureState(error: _streamError.toString()));
    }

    final telemetry = _latestSnapshot;
    final isWaiting = telemetry == null;
    final secondsSincePacket = _lastPacketAt == null
        ? null
        : DateTime.now().difference(_lastPacketAt!).inSeconds;
    final isStale = secondsSincePacket != null && secondsSincePacket > 5;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: Column(
          children: [
            _UnifiedHeader(
              packetCount: _packetCount,
              lastPacketAt: _lastPacketAt,
              isWaiting: isWaiting,
              isStale: isStale,
            ),
            const SizedBox(height: 10),
            const _WorkspaceTabs(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1050;
                  final isCompact = constraints.maxWidth < 720;

                  return TabBarView(
                    children: [
                      _MonitorTab(
                        telemetry: telemetry,
                        isWaiting: isWaiting,
                        isStale: isStale,
                        secondsSincePacket: secondsSincePacket,
                        isWide: isWide,
                        isCompact: isCompact,
                      ),
                      const _MissionTab(),
                      const _SinglePanelTab(child: ParameterViewerPanel()),
                      const _SinglePanelTab(child: LogReplayPanel()),
                      _SystemTab(
                        telemetry: telemetry,
                        statusText: telemetry?.statusText,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnifiedHeader extends StatelessWidget {
  const _UnifiedHeader({
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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF101419),
        border: Border(bottom: BorderSide(color: Color(0xFF29323B))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _workspaceMaxWidth),
            child: TopStatusBar(
              packetCount: packetCount,
              lastPacketAt: lastPacketAt,
              isWaiting: isWaiting,
              isStale: isStale,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTabs extends StatelessWidget {
  const _WorkspaceTabs();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _workspaceMaxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151A20),
              border: Border.all(color: const Color(0xFF29323B)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SizedBox(
              height: 58,
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorColor: Color(0xFF65D890),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3,
                labelColor: Color(0xFFF5F7FA),
                unselectedLabelColor: Color(0xFF98A6B3),
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                labelPadding: EdgeInsets.symmetric(horizontal: 20),
                tabs: [
                  Tab(
                    icon: Icon(Icons.monitor_heart, size: 22),
                    iconMargin: EdgeInsets.only(bottom: 5),
                    text: 'Monitor',
                  ),
                  Tab(
                    icon: Icon(Icons.route, size: 22),
                    iconMargin: EdgeInsets.only(bottom: 5),
                    text: 'Mission',
                  ),
                  Tab(
                    icon: Icon(Icons.tune, size: 22),
                    iconMargin: EdgeInsets.only(bottom: 5),
                    text: 'Parameters',
                  ),
                  Tab(
                    icon: Icon(Icons.history, size: 22),
                    iconMargin: EdgeInsets.only(bottom: 5),
                    text: 'Replay',
                  ),
                  Tab(
                    icon: Icon(Icons.settings, size: 22),
                    iconMargin: EdgeInsets.only(bottom: 5),
                    text: 'System',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonitorTab extends StatelessWidget {
  const _MonitorTab({
    required this.telemetry,
    required this.isWaiting,
    required this.isStale,
    required this.secondsSincePacket,
    required this.isWide,
    required this.isCompact,
  });

  final VehicleSnapshot? telemetry;
  final bool isWaiting;
  final bool isStale;
  final int? secondsSincePacket;
  final bool isWide;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final telemetryColumn = TelemetryPanel(
      telemetry: telemetry,
      isWaiting: isWaiting,
      isStale: isStale,
      isCompact: isCompact,
    );
    final operationsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafetyBanner(
          telemetry: telemetry,
          isWaiting: isWaiting,
          isStale: isStale,
          secondsSincePacket: secondsSincePacket,
        ),
        const SizedBox(height: 16),
        VehicleHealthPanel(
          telemetry: telemetry,
          isWaiting: isWaiting,
          isStale: isStale,
        ),
        const SizedBox(height: 16),
        _CollapsedCoreLog(
          statusText: telemetry?.statusText,
          telemetry: telemetry,
        ),
      ],
    );

    return _TabScrollView(
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: telemetryColumn),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: operationsColumn),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                telemetryColumn,
                const SizedBox(height: 16),
                operationsColumn,
              ],
            ),
    );
  }
}

class _MissionTab extends StatelessWidget {
  const _MissionTab();

  @override
  Widget build(BuildContext context) {
    return const _SinglePanelTab(child: _MissionPlaceholder());
  }
}

class _MissionPlaceholder extends StatelessWidget {
  const _MissionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mission planning is not implemented yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const _LockedBadge(label: 'Locked'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This build does not upload missions or command vehicles.',
              style: TextStyle(color: Color(0xFFE7EDF3), height: 1.35),
            ),
            const SizedBox(height: 14),
            const _WorkflowLockRow(label: 'Plan mission', badge: 'Locked'),
            const _WorkflowLockRow(label: 'Validate route', badge: 'Locked'),
            const _WorkflowLockRow(label: 'Approve mission', badge: 'Locked'),
            const _WorkflowLockRow(label: 'Upload mission', badge: 'Disabled'),
          ],
        ),
      ),
    );
  }
}

class _SystemTab extends StatelessWidget {
  const _SystemTab({required this.telemetry, required this.statusText});

  final VehicleSnapshot? telemetry;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    return _TabScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CommandLockoutPanel(),
          const SizedBox(height: 16),
          const _SafetyBoundarySummary(),
          const SizedBox(height: 16),
          _CollapsedCoreLog(statusText: statusText, telemetry: telemetry),
          const SizedBox(height: 16),
          _CollapsedMilestoneStatus(telemetry: telemetry),
          const SizedBox(height: 16),
          const FutureModulesPanel(),
        ],
      ),
    );
  }
}

class _SafetyBoundarySummary extends StatelessWidget {
  const _SafetyBoundarySummary();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _SectionTitle(
              icon: Icons.verified_user,
              title: 'Safety Boundary',
              badge: 'Receive-only',
            ),
            SizedBox(height: 12),
            Text(
              'No vehicle commands are available in this build.',
              style: TextStyle(
                color: Color(0xFF65D890),
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mission upload, mode changes, manual control, actuator output, and payload control remain locked until a reviewed safety architecture exists.',
              style: TextStyle(color: Color(0xFFC8D2DC), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedMilestoneStatus extends StatelessWidget {
  const _CollapsedMilestoneStatus({required this.telemetry});

  final VehicleSnapshot? telemetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: false,
            title: const Text(
              'Development milestone status',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Current build state and locked future controls',
              style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 10),
            children: [
              _MilestoneRow(
                icon: Icons.sensors,
                title: 'Telemetry receive',
                detail: telemetry == null
                    ? 'Listening for vehicle_state packets.'
                    : 'Decoded vehicle_state packets are updating the dashboard.',
                locked: false,
              ),
              const _MilestoneRow(
                icon: Icons.map_outlined,
                title: 'Mission upload',
                detail: 'Not available in this build.',
                locked: true,
              ),
              const _MilestoneRow(
                icon: Icons.tune,
                title: 'Mode and actuator control',
                detail: 'Locked until a reviewed safety architecture exists.',
                locked: true,
              ),
              const _MilestoneRow(
                icon: Icons.health_and_safety,
                title: 'Safety status display',
                detail:
                    'Armed state, link state, battery, attitude, and position are visible for monitoring.',
                locked: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.locked,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = locked
        ? Theme.of(context).colorScheme.secondary
        : const Color(0xFF65D890);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(color: Color(0xFF98A6B3), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            locked ? Icons.lock : Icons.check_circle,
            color: color,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _CollapsedCoreLog extends StatelessWidget {
  const _CollapsedCoreLog({required this.statusText, this.telemetry});

  final String? statusText;
  final VehicleSnapshot? telemetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: false,
            title: const Text(
              'Core Log',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              statusText ?? 'No telemetry packet decoded yet.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 10),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF07090C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF29323B)),
                ),
                child: Text(
                  _coreLogText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFD5DEE8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _coreLogText {
    final snapshot = telemetry;
    if (snapshot == null) {
      return statusText ?? 'No telemetry packet decoded yet.';
    }
    return [
      statusText ?? 'Telemetry packet decoded.',
      'source=${snapshot.telemetrySourceType}',
      'bind=${snapshot.telemetryBindAddress}',
      'packets=${snapshot.telemetryPacketCount}',
      'parse_errors=${snapshot.telemetryParseErrorCount}',
      'rate_hz=${snapshot.telemetryMessageRateHz.toStringAsFixed(2)}',
      snapshot.telemetryReceiveOnlyNote,
    ].join('\n');
  }
}

class _SinglePanelTab extends StatelessWidget {
  const _SinglePanelTab({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _TabScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _workspaceMaxWidth),
          child: child,
        ),
      ),
    );
  }
}

class _TabScrollView extends StatelessWidget {
  const _TabScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _workspaceMaxWidth),
          child: child,
        ),
      ),
    );
  }
}

class _WorkflowLockRow extends StatelessWidget {
  const _WorkflowLockRow({required this.label, required this.badge});

  final String label;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.lock,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC8D2DC),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _LockedBadge(label: badge),
        ],
      ),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF65D890), size: 20),
        const SizedBox(width: 10),
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
            color: const Color(0xFF65D890).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: Color(0xFF65D890),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
          border: Border.all(color: Theme.of(context).colorScheme.error),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Telemetry receiver failed',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(error, style: const TextStyle(color: Color(0xFFC8D2DC))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
