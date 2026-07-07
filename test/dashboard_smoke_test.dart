import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/app/ground_control_app.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

void main() {
  testWidgets('shows the receive-only dashboard shell', (tester) async {
    await tester.pumpWidget(
      GroundControlApp(telemetryStream: const Stream.empty()),
    );

    expect(find.text('MAVLink GCS Portfolio'), findsWidgets);
    expect(find.textContaining('Robotics Telemetry Lab'), findsOneWidget);
    expect(find.text('Receive-only telemetry'), findsWidgets);
    expect(find.text('Monitor'), findsWidgets);
    expect(find.text('Mission'), findsOneWidget);
    expect(find.text('Parameters'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Vehicle Health'), findsOneWidget);
    expect(find.text('MAVLink Inspector Lite'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);
    expect(find.text('Attitude'), findsOneWidget);
    expect(find.text('Command authority'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(find.text('Roll'), findsOneWidget);
    expect(find.text('Pitch'), findsOneWidget);
    expect(find.text('Yaw'), findsOneWidget);
    expect(find.text('--%'), findsOneWidget);
    expect(find.text('-- V'), findsOneWidget);
    expect(find.text('-- deg'), findsWidgets);

    await tester.tap(find.text('Mission'));
    await tester.pumpAndSettle();
    expect(
      find.text('Mission planning is not implemented yet'),
      findsOneWidget,
    );
    expect(
      find.text('This build does not upload missions or command vehicles.'),
      findsOneWidget,
    );
    expect(find.text('Plan mission'), findsOneWidget);
    expect(find.text('Validate route'), findsOneWidget);
    expect(find.text('Approve mission'), findsOneWidget);
    expect(find.text('Upload mission'), findsOneWidget);
    expect(find.text('Disabled'), findsWidgets);

    await tester.tap(find.text('Parameters'));
    await tester.pumpAndSettle();
    expect(find.text('Offline Parameters'), findsOneWidget);
    expect(find.text('Import current parameter file'), findsWidgets);
    expect(find.text('Import baseline parameter file'), findsWidgets);
    expect(find.text('Export report'), findsWidgets);
    expect(find.text('Review differences'), findsOneWidget);
    expect(
      find.text('Comparison status: Waiting for parameter files'),
      findsOneWidget,
    );
    expect(
      find.text('Export is available after a comparison is created.'),
      findsOneWidget,
    );
    expect(find.text('Current parsed count'), findsOneWidget);
    expect(find.text('Baseline parsed count'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Review tag'), findsOneWidget);
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Display mode'), findsOneWidget);
    expect(find.text('Export current filtered view'), findsOneWidget);
    expect(
      find.text('Import both parameter files to compare.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Comparison is offline only. No vehicle communication or parameter writes.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Offline comparison only'), findsOneWidget);
    expect(find.text('Parser notes'), findsOneWidget);
    expect(find.text('Duplicate parameters'), findsOneWidget);
    expect(find.text('Category and review tag rules'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);
    expect(find.text('Write'), findsNothing);
    final exportButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Export report'),
    );
    expect(exportButton.onPressed, isNull);

    await tester.tap(find.text('Replay'));
    await tester.pumpAndSettle();
    expect(find.text('Log Replay'), findsOneWidget);
    expect(find.text('Import log'), findsOneWidget);
    expect(find.text('Copy command'), findsOneWidget);
    expect(find.text('Play replay'), findsOneWidget);
    expect(find.text('1x visual replay'), findsOneWidget);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(find.text('Command Lockout'), findsOneWidget);
    expect(find.text('Development milestone status'), findsOneWidget);
    expect(
      find.text('No vehicle commands are available in this build.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Planned Modules'));
    await tester.tap(find.text('Planned Modules'));
    await tester.pumpAndSettle();
    expect(find.text('Offline parameter viewer'), findsOneWidget);
    expect(find.text('Review-gated parameter writes'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
  });

  testWidgets('shows disarmed receive-only banner for disarmed telemetry', (
    tester,
  ) async {
    await tester.pumpWidget(
      GroundControlApp(
        telemetryStream: Stream.value(
          const VehicleSnapshot(
            isArmed: false,
            lockedVehicleSource: false,
            messageRates: [],
            telemetrySourceType: 'UDP JSON adapter',
            telemetryBindAddress: '127.0.0.1:16000',
            telemetryPacketCount: 1,
            telemetryParseErrorCount: 0,
            telemetryMessageRateHz: 1.0,
            telemetryReceiveOnlyNote:
                'Receive-only V1 adapter: no commands, parameter writes, or mission upload.',
            statusText: 'Decoded vehicle_state JSON',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Vehicle disarmed'), findsOneWidget);
    expect(
      find.text(
        'Receive-only telemetry is active. Command authority is disabled.',
      ),
      findsOneWidget,
    );
    expect(find.text('UDP JSON adapter'), findsWidgets);
  });
}
