import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

class AttitudePanel extends StatelessWidget {
  const AttitudePanel({super.key, required this.telemetry});

  final VehicleSnapshot? telemetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attitude',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _CenterZeroAxis(
              label: 'Roll',
              value: telemetry?.rollDeg,
              color: const Color(0xFF7DC6FF),
            ),
            const SizedBox(height: 16),
            _CenterZeroAxis(
              label: 'Pitch',
              value: telemetry?.pitchDeg,
              color: const Color(0xFFFFCF70),
            ),
            const SizedBox(height: 18),
            _YawAxis(yawDeg: telemetry?.yawDeg),
          ],
        ),
      ),
    );
  }
}

class _CenterZeroAxis extends StatelessWidget {
  const _CenterZeroAxis({
    required this.label,
    required this.value,
    required this.color,
  });

  static const _rangeDeg = 45.0;

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clampedTarget = (value ?? 0.0).clamp(-_rangeDeg, _rangeDeg);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: clampedTarget),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final clamped = animatedValue.clamp(-_rangeDeg, _rangeDeg);
        final magnitudeFraction = value == null
            ? 0.0
            : clamped.abs() / _rangeDeg;
        final extendsLeft = clamped < 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF98A6B3),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final halfWidth = constraints.maxWidth / 2;
                        final fillWidth = halfWidth * magnitudeFraction;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF29323B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            // The zero marker is fixed at true center. Negative
                            // roll/pitch extends left; positive extends right.
                            Positioned(
                              left: halfWidth - 1,
                              child: Container(
                                width: 2,
                                height: 28,
                                color: const Color(0xFFE7EDF3),
                              ),
                            ),
                            Positioned(
                              left: extendsLeft
                                  ? halfWidth - fillWidth
                                  : halfWidth,
                              width: fillWidth,
                              child: AnimatedOpacity(
                                opacity: value == null ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 100),
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 82,
                  child: Text(
                    value == null
                        ? '-- deg'
                        : '${value!.toStringAsFixed(1)} deg',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFFE7EDF3),
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 54, right: 94, top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('-45', style: _ScaleLabelStyle()),
                  Text('0', style: _ScaleLabelStyle()),
                  Text('+45', style: _ScaleLabelStyle()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _YawAxis extends StatefulWidget {
  const _YawAxis({required this.yawDeg});

  final double? yawDeg;

  @override
  State<_YawAxis> createState() => _YawAxisState();
}

class _YawAxisState extends State<_YawAxis> {
  double _displayTurns = 0.0;
  bool _hasDisplayYaw = false;

  @override
  void initState() {
    super.initState();
    _setYaw(widget.yawDeg, animateShortestPath: false);
  }

  @override
  void didUpdateWidget(covariant _YawAxis oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.yawDeg != oldWidget.yawDeg) {
      _setYaw(widget.yawDeg, animateShortestPath: true);
    }
  }

  void _setYaw(double? yawDeg, {required bool animateShortestPath}) {
    if (yawDeg == null) {
      _hasDisplayYaw = false;
      return;
    }

    final targetTurns = _normalizeYaw(yawDeg) / 360.0;
    if (!_hasDisplayYaw || !animateShortestPath) {
      _displayTurns = targetTurns;
      _hasDisplayYaw = true;
      return;
    }

    final currentWrapped = _displayTurns - _displayTurns.floorToDouble();
    var delta = targetTurns - currentWrapped;
    if (delta > 0.5) delta -= 1.0;
    if (delta < -0.5) delta += 1.0;
    _displayTurns += delta;
  }

  @override
  Widget build(BuildContext context) {
    final yaw = widget.yawDeg == null ? null : _normalizeYaw(widget.yawDeg!);
    final cardinal = yaw == null ? '--' : _cardinalDirection(yaw);

    return Row(
      children: [
        const SizedBox(
          width: 54,
          child: Text(
            'Yaw',
            style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
          ),
        ),
        Expanded(
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF151A20),
              border: Border.all(color: const Color(0xFF29323B)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF29323B)),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _displayTurns,
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: yaw == null ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 100),
                          child: const Icon(
                            Icons.navigation,
                            color: Color(0xFF65D890),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: _CompassScale()),
                const SizedBox(width: 10),
                _CardinalBadge(value: cardinal),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 82,
          child: Text(
            yaw == null ? '-- deg' : '${yaw.toStringAsFixed(1)} deg',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFE7EDF3),
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  double _normalizeYaw(double degrees) {
    final normalized = degrees % 360.0;
    return normalized < 0 ? normalized + 360.0 : normalized;
  }

  String _cardinalDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45.0).floor() % directions.length;
    return directions[index];
  }
}

class _CardinalBadge extends StatelessWidget {
  const _CardinalBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF65D890).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF65D890),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CompassScale extends StatelessWidget {
  const _CompassScale();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('N 0', style: _ScaleLabelStyle()),
        Text('E 90', style: _ScaleLabelStyle()),
        Text('S 180', style: _ScaleLabelStyle()),
        Text('W 270', style: _ScaleLabelStyle()),
      ],
    );
  }
}

class _ScaleLabelStyle extends TextStyle {
  const _ScaleLabelStyle()
    : super(
        color: const Color(0xFF667583),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      );
}
