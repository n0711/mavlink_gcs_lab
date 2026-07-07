import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/app/ground_control_app.dart';
import 'package:mavlink_gcs_portfolio/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('shows the dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      GroundControlApp(telemetryStream: const Stream.empty()),
    );
    expect(find.text('MAVLink GCS Portfolio'), findsWidgets);
    expect(
      find.textContaining('Robotics Telemetry Lab'),
      findsOneWidget,
    );
    expect(find.text('Receive-only telemetry'), findsWidgets);
    expect(find.text('Vehicle Health'), findsOneWidget);
    expect(find.text('MAVLink Inspector Lite'), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
    expect(find.text('Mission'), findsOneWidget);
    expect(find.text('Parameters'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);
    expect(find.text('Attitude'), findsOneWidget);

    await tester.tap(find.text('Replay'));
    await tester.pumpAndSettle();
    expect(find.text('Log Replay'), findsOneWidget);
    expect(find.text('Import log'), findsOneWidget);
    expect(find.text('Copy command'), findsOneWidget);
    expect(find.text('Play replay'), findsOneWidget);
    expect(find.text('1x visual replay'), findsOneWidget);

    await tester.tap(find.text('Monitor'));
    await tester.pumpAndSettle();
    expect(find.text('Roll'), findsOneWidget);
    expect(find.text('Pitch'), findsOneWidget);
    expect(find.text('Yaw'), findsOneWidget);
    expect(find.text('--%'), findsOneWidget);
    expect(find.text('-- deg'), findsWidgets);
  });
}
