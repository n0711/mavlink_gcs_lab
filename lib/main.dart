import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/app/ground_control_app.dart';
import 'package:mavlink_gcs_portfolio/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const GroundControlApp());
}
