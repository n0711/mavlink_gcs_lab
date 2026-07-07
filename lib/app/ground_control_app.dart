import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/dashboard_screen.dart';
import 'package:mavlink_gcs_portfolio/src/rust/api/simple.dart';

const dashboardTitle = 'MAVLink GCS Portfolio - Receive-only Telemetry';

class GroundControlApp extends StatelessWidget {
  const GroundControlApp({super.key, this.telemetryStream});

  final Stream<VehicleSnapshot>? telemetryStream;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: dashboardTitle,
      theme: _buildTheme(),
      home: DashboardScreen(telemetryStream: telemetryStream),
    );
  }

  ThemeData _buildTheme() {
    const colorScheme = ColorScheme.dark(
      surface: Color(0xFF111418),
      surfaceContainerHighest: Color(0xFF20262D),
      primary: Color(0xFF7DC6FF),
      secondary: Color(0xFFFFCF70),
      error: Color(0xFFFF6B6B),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0B0E11),
      cardTheme: const CardThemeData(
        color: Color(0xFF171C22),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: Color(0xFF29323B)),
        ),
      ),
      textTheme: Typography.whiteMountainView.apply(
        bodyColor: const Color(0xFFE7EDF3),
        displayColor: const Color(0xFFF5F7FA),
      ),
    );
  }
}
