# MAVLink GCS Portfolio Prototype

A personal educational ground-control-station prototype built with Flutter and
Rust. It demonstrates receive-only robotics telemetry, local diagnostics, and
offline parameter-file review without providing any vehicle command authority.

This is not certified flight software, not an official tool, and not intended
for operating a real aircraft or vehicle.

## Why This Exists

This repository is a portfolio project for robotics software work:

- desktop UI architecture in Flutter
- Rust boundary for telemetry ingestion
- receive-only link diagnostics
- offline parameter parsing and comparison
- safety-first separation between monitoring and control

The project intentionally uses generic demo data and public MAVLink/ArduPilot
concepts. It does not include employer branding, non-public requirements,
hardware configuration, or production claims.

## Architecture

```text
Flutter Linux UI
→ flutter_rust_bridge
→ Rust backend
→ receive-only UDP JSON adapter on 127.0.0.1:16000
→ optional sample telemetry sender
```

Rust-native MAVLink parsing is not part of this version. A future version can
replace the UDP JSON adapter behind the same Rust telemetry boundary.

## Features

- Flutter desktop dashboard for Linux.
- Receive-only UDP JSON telemetry adapter.
- Link status with waiting, live, stale, and error states.
- Packet count, parse error count, source label, bind address, and message rate.
- Local JSONL session diagnostics.
- Offline/read-only parameter-file parser.
- Offline parameter diff with changed, added, removed, and unchanged values.
- Markdown parameter report export.
- Safety lockouts showing that command authority is disabled.

## Safety Boundary

This project cannot:

- arm or disarm a vehicle
- change flight/drive modes
- upload missions
- send `COMMAND_LONG`, `COMMAND_INT`, `SET_MODE`, or RC override messages
- send `PARAM_SET` or write parameters
- control actuators, payloads, motors, or servos
- run `mavsdk_server`
- use gRPC/protobuf command services

The parameter tools are offline and file-based only.

## Run The App

```bash
flutter pub get
flutter run -d linux
```

Before telemetry packets arrive, the dashboard should show a disconnected or
waiting link state.

## Run Sample Telemetry

In another terminal:

```bash
python3 tools/send_sample_telemetry.py
```

The sender emits UDP JSON to `127.0.0.1:16000`. The dashboard should show:

- source: `UDP JSON adapter`
- increasing packet count
- parse errors at `0`
- changing position, attitude, and battery fields
- stale link state after the sender is stopped for more than five seconds

## Optional MAVLink Bridge

The current app does not parse MAVLink natively. A public/sample bridge can be
used to convert MAVLink telemetry into the same UDP JSON shape:

```bash
python3 -m pip install -r tools/requirements.txt
python3 tools/mavlink_to_udp_json.py --connect udp:127.0.0.1:14550
```

Serial example:

```bash
python3 tools/mavlink_to_udp_json.py --connect /dev/ttyACM0 --baud 115200
```

The bridge is still receive-only.

## Parameters Demo

The Parameters tab accepts saved ArduPilot/Mission Planner-style files:

- `PARAM,VALUE`
- `PARAM VALUE`
- `PARAM=VALUE`

Example parameter names used for demos:

- `ARMING_CHECK`
- `GPS_TYPE`
- `BATT_MONITOR`
- `FS_THR_ENABLE`
- `EK3_ENABLE`

Full-line `#` and `//` comments are ignored. Inline comments are stripped and
counted. Duplicate parameter names are reported; the last parsed value is used
for comparison.

## Session Logs

Local diagnostics are written as JSONL:

```text
$HOME/.mavlink_gcs_portfolio/session_logs/
```

If `HOME` is not available, the app falls back to the system temporary
directory. Logging failures are ignored so diagnostics cannot crash the demo.

## Tests And Build

```bash
dart format lib test tools
flutter analyze
flutter test
cargo fmt --check --manifest-path rust/Cargo.toml
cargo test --manifest-path rust/Cargo.toml
flutter build linux --debug
```

## Roadmap

V1:

- receive-only telemetry demo
- offline parameter parser/diff/report
- local session diagnostics
- safety lockouts
- Linux desktop build

V2 ideas:

- Rust-native receive-only MAVLink parsing
- richer telemetry replay
- map view using public/offline data
- better parameter metadata from public sources
- packaging and screenshots for portfolio presentation

Out of scope until a separate safety design exists:

- vehicle commands
- mission upload
- parameter writes
- guided/manual/offboard control
- actuator or payload control

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Safety Boundary](docs/SAFETY_BOUNDARY.md)
- [Parameters](docs/PARAMETERS.md)
- [Roadmap](docs/ROADMAP.md)
- [Developer Notes](docs/DEVELOPER_NOTES.md)
