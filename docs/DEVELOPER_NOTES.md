# Developer Notes

## Project Identity

Package name: `mavlink_gcs_portfolio`

App title: `MAVLink GCS Portfolio`

Rust crate/plugin name: `rust_lib_mavlink_gcs_portfolio`

## Main Code Paths

- App shell: `lib/app/ground_control_app.dart`
- Dashboard: `lib/features/dashboard/dashboard_screen.dart`
- Telemetry widgets: `lib/features/dashboard/widgets/`
- Session diagnostics: `lib/features/logging/application/gcs_session_log.dart`
- Parameter parser: `lib/features/dashboard/parameter_file_parser.dart`
- Parameter diff: `lib/features/dashboard/parameter_diff.dart`
- Markdown report: `lib/features/dashboard/parameter_diff_report.dart`
- Rust telemetry adapter: `rust/src/telemetry/`

## Run Checks

```bash
dart format lib test tools
flutter analyze
flutter test
cargo fmt --check --manifest-path rust/Cargo.toml
cargo test --manifest-path rust/Cargo.toml
flutter build linux --debug
```

## Development Guardrails

Keep V1 receive-only. Do not add vehicle command paths, parameter writes, mission
upload, MAVSDK server, gRPC/protobuf command services, or local environment
assumptions.

If a future Rust-native MAVLink source is added, keep it behind the existing
telemetry adapter boundary so the Flutter dashboard can continue consuming
`VehicleSnapshot` diagnostics.
