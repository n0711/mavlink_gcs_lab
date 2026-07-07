# Tools

All helper tools in this repository are receive-only. They do not upload
missions, arm/disarm, change modes, send manual control, or send actuator/payload
commands.

Install helper dependencies:

```bash
python3 -m pip install -r tools/requirements.txt
```

## `send_sample_telemetry.py`

Small local UDP JSON sender for testing the dashboard without MAVLink hardware.
It emits to `127.0.0.1:16000` by default, which is the Rust V1 UDP JSON adapter
address.

Run from the repository root:

```bash
python3 tools/send_sample_telemetry.py
```

Optional examples:

```bash
python3 tools/send_sample_telemetry.py --rate 5
python3 tools/send_sample_telemetry.py --host 127.0.0.1 --port 16000
```

## `mavlink_to_udp_json.py`

Receive-only helper bridge that reads MAVLink telemetry and emits normalized UDP
JSON to the dashboard on `127.0.0.1:16000`.

This is an external helper, not full in-app MAVLink link management. The Flutter
app still consumes UDP JSON through the Rust receiver. Rust-native MAVLink
parsing is deferred beyond V1.

UDP example:

```bash
python3 tools/mavlink_to_udp_json.py --connect udp:127.0.0.1:14550
```

Serial/RF example:

```bash
python3 tools/mavlink_to_udp_json.py --connect /dev/ttyACM0 --baud 115200
```

MAVProxy split example:

```bash
mavproxy.py \
  --master=/dev/ttyACM0 \
  --baudrate 115200 \
  --out=127.0.0.1:14550 \
  --out=127.0.0.1:14551

python3 tools/mavlink_to_udp_json.py \
  --connect udpin:127.0.0.1:14551 \
  --out-host 127.0.0.1 \
  --out-port 16000 \
  --rate 20 \
  --verbose
```

The bridge maps telemetry from `HEARTBEAT`, `ATTITUDE`,
`GLOBAL_POSITION_INT`, `GPS_RAW_INT`, `VFR_HUD`, `SYS_STATUS`,
`BATTERY_STATUS`, and `STATUSTEXT` where available.

## Replay Helper Path

The dashboard replay panel can launch an external replay helper if one is
available. Configure its path with:

```bash
export MAVLINK_GCS_REPLAY_HELPER=/path/to/replay_log_to_udp.py
```

If the environment variable is not set, the app falls back to:

```text
$HOME/tools/replay_log_to_udp.py
```

This replay helper is external to this repository. The dashboard can select a
`.BIN`, `.bin`, `.tlog`, or `.TLOG` file and pass it to the helper. The app does
not parse logs internally yet.

## Current Limitations

- No Rust-native MAVLink parser yet.
- No raw MAVLink recording yet.
- No mission upload or command authority.
- No controller/manual-control support.
