#!/usr/bin/env python3
"""Receive-only MAVLink to UDP JSON bridge for the MAVLink GCS Portfolio."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import socket
import time
from collections import defaultdict, deque
from typing import Any


UINT16_MAX = 65535
ATTITUDE_STALE_AFTER_S = 2.0
HEADING_STALE_AFTER_S = 5.0
POSITION_STALE_AFTER_S = 5.0
BATTERY_STALE_AFTER_S = 10.0
MESSAGE_RATE_WINDOW_S = 5.0
USEFUL_MESSAGE_TYPES = (
    "HEARTBEAT",
    "ATTITUDE",
    "GPS_RAW_INT",
    "GLOBAL_POSITION_INT",
    "VFR_HUD",
    "SYS_STATUS",
    "BATTERY_STATUS",
    "STATUSTEXT",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Read MAVLink telemetry and emit receive-only UDP JSON for the "
            "MAVLink GCS Portfolio."
        ),
    )
    parser.add_argument(
        "--connect",
        default="udp:127.0.0.1:14550",
        help="pymavlink connection string or serial device.",
    )
    parser.add_argument(
        "--baud",
        type=int,
        default=115200,
        help="Serial baud rate when --connect is a serial device.",
    )
    parser.add_argument(
        "--out-host",
        default="127.0.0.1",
        help="Destination UDP JSON host.",
    )
    parser.add_argument(
        "--out-port",
        type=int,
        default=16000,
        help="Destination UDP JSON port.",
    )
    parser.add_argument(
        "--rate",
        type=float,
        default=2.0,
        help="UDP JSON publish rate in Hz.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print MAVLink message types as they are received.",
    )
    return parser.parse_args()


def utc_timestamp() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def initial_state() -> dict[str, Any]:
    return {
        "message_type": "vehicle_state",
        "timestamp": utc_timestamp(),
        "position": {
            "latitude_deg": None,
            "longitude_deg": None,
            "altitude_m": None,
        },
        "motion": {
            "heading_deg": None,
            "heading_source": None,
        },
        "attitude": {
            "roll_deg": None,
            "pitch_deg": None,
            "yaw_deg": None,
            "age_ms": None,
        },
        "system": {
            "armed": False,
            "battery_percent": None,
            "battery_voltage_v": None,
            "battery_current_a": None,
            "battery_validity": "Unavailable",
            "battery_source": None,
            "mode": "UNKNOWN",
        },
        "gps": {
            "fix_type": None,
            "satellites_visible": None,
            "hdop": None,
        },
        "health": {
            "gps_fix_type": None,
            "satellites_visible": None,
            "hdop": None,
        },
        "freshness": {
            "heartbeat_age_s": None,
            "attitude_age_s": None,
            "position_age_s": None,
            "battery_age_s": None,
            "gps_age_s": None,
        },
        "source": {
            "vehicle_sysid": None,
            "vehicle_compid": None,
            "yaw_source": None,
            "heading_source": None,
        },
        "telemetry": {
            "vehicle_sysid": None,
            "vehicle_compid": None,
            "last_message_type": None,
            "message_counts": {},
            "message_rates_hz": {},
            "heartbeat_age_ms": None,
            "attitude_age_ms": None,
            "position_age_ms": None,
            "gps_age_ms": None,
            "battery_age_ms": None,
            "locked_vehicle_source": False,
        },
        "status_text": "Waiting for MAVLink telemetry",
        "_last_updates": {},
        "_locked_vehicle": None,
        "_message_counts": defaultdict(int),
        "_message_times": defaultdict(deque),
    }


def valid_percent(value: Any) -> bool:
    return isinstance(value, int) and 0 <= value <= 100


def valid_voltage_mv(value: Any) -> bool:
    return isinstance(value, int) and 0 < value < UINT16_MAX


def valid_current(value: Any) -> bool:
    return isinstance(value, int) and value >= 0


def mavlink_const(mavutil: Any, name: str, default: int) -> int:
    return getattr(mavutil.mavlink, name, default)


def message_source(msg: Any) -> tuple[int | None, int | None]:
    try:
        return msg.get_srcSystem(), msg.get_srcComponent()
    except Exception:
        return None, None


def is_non_vehicle_heartbeat(msg: Any, mavutil: Any) -> bool:
    mav_type = getattr(msg, "type", None)
    autopilot = getattr(msg, "autopilot", None)
    non_vehicle_types = {
        mavlink_const(mavutil, "MAV_TYPE_GCS", 6),
        mavlink_const(mavutil, "MAV_TYPE_ONBOARD_CONTROLLER", 18),
        mavlink_const(mavutil, "MAV_TYPE_GIMBAL", 26),
        mavlink_const(mavutil, "MAV_TYPE_ADSB", 27),
        mavlink_const(mavutil, "MAV_TYPE_CAMERA", 30),
    }
    if mav_type in non_vehicle_types:
        return True
    return autopilot == mavlink_const(mavutil, "MAV_AUTOPILOT_INVALID", 8)


def should_accept_message(
    state: dict[str, Any],
    msg: Any,
    mavutil: Any,
    verbose: bool,
) -> bool:
    msg_type = msg.get_type()
    src_sysid, src_compid = message_source(msg)
    locked_vehicle = state.get("_locked_vehicle")

    if msg_type == "HEARTBEAT":
        if locked_vehicle is None:
            if is_non_vehicle_heartbeat(msg, mavutil):
                return False
            locked_vehicle = (src_sysid, src_compid)
            state["_locked_vehicle"] = locked_vehicle
            state["source"]["vehicle_sysid"] = src_sysid
            state["source"]["vehicle_compid"] = src_compid
            state["telemetry"]["vehicle_sysid"] = src_sysid
            state["telemetry"]["vehicle_compid"] = src_compid
            state["telemetry"]["locked_vehicle_source"] = True
            if verbose:
                print(
                    "Locked vehicle source "
                    f"sysid={src_sysid} compid={src_compid} "
                    f"type={getattr(msg, 'type', None)} "
                    f"autopilot={getattr(msg, 'autopilot', None)}"
                )
            return True
        return (src_sysid, src_compid) == locked_vehicle

    if locked_vehicle is None:
        return True

    locked_sysid, _locked_compid = locked_vehicle
    return src_sysid == locked_sysid


def mark_update(state: dict[str, Any], group: str) -> None:
    state["_last_updates"][group] = time.monotonic()


def age_or_none(state: dict[str, Any], group: str, now: float) -> float | None:
    updated_at = state["_last_updates"].get(group)
    if updated_at is None:
        return None
    return round(now - updated_at, 1)


def age_ms_or_none(state: dict[str, Any], group: str, now: float) -> int | None:
    updated_at = state["_last_updates"].get(group)
    if updated_at is None:
        return None
    return round((now - updated_at) * 1000)


def is_fresh(state: dict[str, Any], group: str, max_age_s: float, now: float) -> bool:
    updated_at = state["_last_updates"].get(group)
    return updated_at is not None and now - updated_at <= max_age_s


def record_message(state: dict[str, Any], msg_type: str) -> None:
    now = time.monotonic()
    state["_message_counts"][msg_type] += 1
    state["telemetry"]["last_message_type"] = msg_type

    message_times = state["_message_times"][msg_type]
    message_times.append(now)
    cutoff = now - MESSAGE_RATE_WINDOW_S
    while message_times and message_times[0] < cutoff:
        message_times.popleft()


def message_counts(state: dict[str, Any]) -> dict[str, int]:
    counts = state["_message_counts"]
    return {
        message_type: counts.get(message_type, 0)
        for message_type in USEFUL_MESSAGE_TYPES
    }


def message_rates(state: dict[str, Any], now: float) -> dict[str, float]:
    rates: dict[str, float] = {}
    cutoff = now - MESSAGE_RATE_WINDOW_S
    for message_type in USEFUL_MESSAGE_TYPES:
        times = state["_message_times"][message_type]
        while times and times[0] < cutoff:
            times.popleft()
        rates[message_type] = round(len(times) / MESSAGE_RATE_WINDOW_S, 1)
    return rates


def update_from_heartbeat(state: dict[str, Any], msg: Any, mavutil: Any) -> None:
    armed_flag = mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED
    state["system"]["armed"] = (msg.base_mode & armed_flag) != 0
    try:
        state["system"]["mode"] = mavutil.mode_string_v10(msg)
    except Exception:
        state["system"]["mode"] = "UNKNOWN"
    state["status_text"] = "MAVLink heartbeat received"
    mark_update(state, "heartbeat")


def update_from_attitude(state: dict[str, Any], msg: Any) -> None:
    roll_deg = math.degrees(msg.roll)
    pitch_deg = math.degrees(msg.pitch)
    yaw_deg = math.degrees(msg.yaw) % 360.0
    state["attitude"]["roll_deg"] = roll_deg
    state["attitude"]["pitch_deg"] = pitch_deg
    state["attitude"]["yaw_deg"] = yaw_deg
    state["motion"]["heading_deg"] = yaw_deg
    state["motion"]["heading_source"] = "ATTITUDE yaw"
    state["source"]["yaw_source"] = "ATTITUDE"
    state["source"]["heading_source"] = "ATTITUDE yaw"
    mark_update(state, "attitude")
    mark_update(state, "heading")


def update_from_global_position(state: dict[str, Any], msg: Any) -> None:
    state["position"]["latitude_deg"] = msg.lat / 1e7
    state["position"]["longitude_deg"] = msg.lon / 1e7

    relative_alt = getattr(msg, "relative_alt", None)
    if relative_alt is not None:
        state["position"]["altitude_m"] = relative_alt / 1000.0
    else:
        state["position"]["altitude_m"] = msg.alt / 1000.0

    hdg = getattr(msg, "hdg", UINT16_MAX)
    if hdg != UINT16_MAX:
        state["motion"]["heading_deg"] = hdg / 100.0
        state["motion"]["heading_source"] = "GLOBAL_POSITION_INT"
        state["source"]["heading_source"] = "GLOBAL_POSITION_INT"
        mark_update(state, "heading")
    mark_update(state, "position")


def update_from_sys_status(state: dict[str, Any], msg: Any) -> None:
    voltage_battery = getattr(msg, "voltage_battery", UINT16_MAX)
    current_battery = getattr(msg, "current_battery", -1)
    has_battery_signal = valid_voltage_mv(voltage_battery) or valid_current(
        current_battery
    )

    if valid_voltage_mv(voltage_battery):
        state["system"]["battery_voltage_v"] = voltage_battery / 1000.0
    else:
        state["system"]["battery_voltage_v"] = None

    if valid_current(current_battery):
        state["system"]["battery_current_a"] = current_battery / 100.0
    else:
        state["system"]["battery_current_a"] = None

    battery_remaining = getattr(msg, "battery_remaining", -1)
    if has_battery_signal and valid_percent(battery_remaining):
        state["system"]["battery_percent"] = battery_remaining
        state["system"]["battery_validity"] = "Valid"
        state["system"]["battery_source"] = "SYS_STATUS"
    else:
        state["system"]["battery_percent"] = None
        state["system"]["battery_validity"] = "Unverified"
        state["system"]["battery_source"] = "SYS_STATUS"
    mark_update(state, "battery")


def update_from_battery_status(state: dict[str, Any], msg: Any) -> None:
    voltages = getattr(msg, "voltages", []) or []
    valid_cell_voltages = [voltage for voltage in voltages if valid_voltage_mv(voltage)]
    if valid_cell_voltages:
        state["system"]["battery_voltage_v"] = valid_cell_voltages[0] / 1000.0
    else:
        state["system"]["battery_voltage_v"] = None
    state["system"]["battery_current_a"] = None

    battery_remaining = getattr(msg, "battery_remaining", -1)
    if valid_cell_voltages and valid_percent(battery_remaining):
        state["system"]["battery_percent"] = battery_remaining
        state["system"]["battery_validity"] = "Valid"
        state["system"]["battery_source"] = "BATTERY_STATUS"
    else:
        state["system"]["battery_percent"] = None
        state["system"]["battery_validity"] = "Unverified"
        state["system"]["battery_source"] = "BATTERY_STATUS"
    mark_update(state, "battery")


def update_from_gps_raw_int(state: dict[str, Any], msg: Any) -> None:
    fix_type = getattr(msg, "fix_type", None)
    satellites_visible = getattr(msg, "satellites_visible", None)
    eph = getattr(msg, "eph", None)
    hdop = None if eph in (None, UINT16_MAX) else eph / 100.0
    state["health"]["gps_fix_type"] = fix_type
    state["health"]["satellites_visible"] = satellites_visible
    state["health"]["hdop"] = hdop
    state["gps"]["fix_type"] = fix_type
    state["gps"]["satellites_visible"] = satellites_visible
    state["gps"]["hdop"] = hdop
    mark_update(state, "gps")


def update_from_vfr_hud(state: dict[str, Any], msg: Any) -> None:
    heading = getattr(msg, "heading", None)
    if isinstance(heading, int) and 0 <= heading <= 360:
        state["motion"]["heading_deg"] = float(heading)
        state["motion"]["heading_source"] = "VFR_HUD"
        state["source"]["heading_source"] = "VFR_HUD"
        mark_update(state, "heading")


def update_from_statustext(state: dict[str, Any], msg: Any) -> None:
    text = getattr(msg, "text", "")
    if isinstance(text, bytes):
        text = text.decode("utf-8", errors="replace")
    state["status_text"] = str(text).strip("\x00") or "MAVLink status text received"


def update_state_from_message(
    state: dict[str, Any],
    msg: Any,
    mavutil: Any,
    verbose: bool = False,
) -> None:
    if not should_accept_message(state, msg, mavutil, verbose):
        return

    msg_type = msg.get_type()
    record_message(state, msg_type)
    if msg_type == "HEARTBEAT":
        update_from_heartbeat(state, msg, mavutil)
    elif msg_type == "ATTITUDE":
        update_from_attitude(state, msg)
    elif msg_type == "GLOBAL_POSITION_INT":
        update_from_global_position(state, msg)
    elif msg_type == "SYS_STATUS":
        update_from_sys_status(state, msg)
    elif msg_type == "BATTERY_STATUS":
        update_from_battery_status(state, msg)
    elif msg_type == "GPS_RAW_INT":
        update_from_gps_raw_int(state, msg)
    elif msg_type == "VFR_HUD":
        update_from_vfr_hud(state, msg)
    elif msg_type == "STATUSTEXT":
        update_from_statustext(state, msg)


def public_state(state: dict[str, Any]) -> dict[str, Any]:
    now = time.monotonic()
    payload = {key: value for key, value in state.items() if not key.startswith("_")}
    heartbeat_age_ms = age_ms_or_none(state, "heartbeat", now)
    attitude_age_ms = age_ms_or_none(state, "attitude", now)
    position_age_ms = age_ms_or_none(state, "position", now)
    gps_age_ms = age_ms_or_none(state, "gps", now)
    battery_age_ms = age_ms_or_none(state, "battery", now)
    payload["freshness"] = {
        "heartbeat_age_s": age_or_none(state, "heartbeat", now),
        "attitude_age_s": age_or_none(state, "attitude", now),
        "position_age_s": age_or_none(state, "position", now),
        "battery_age_s": age_or_none(state, "battery", now),
        "gps_age_s": age_or_none(state, "gps", now),
    }
    payload["telemetry"] = {
        **payload["telemetry"],
        "message_counts": message_counts(state),
        "message_rates_hz": message_rates(state, now),
        "heartbeat_age_ms": heartbeat_age_ms,
        "attitude_age_ms": attitude_age_ms,
        "position_age_ms": position_age_ms,
        "gps_age_ms": gps_age_ms,
        "battery_age_ms": battery_age_ms,
    }
    attitude_age_s = age_or_none(state, "attitude", now)
    payload["attitude"] = {
        **payload["attitude"],
        "age_ms": None if attitude_age_s is None else round(attitude_age_s * 1000),
    }
    if not is_fresh(state, "attitude", ATTITUDE_STALE_AFTER_S, now):
        payload["attitude"] = {
            "roll_deg": None,
            "pitch_deg": None,
            "yaw_deg": None,
            "age_ms": payload["attitude"]["age_ms"],
        }
        payload["source"] = {
            **payload["source"],
            "yaw_source": None,
        }
    if not is_fresh(state, "heading", HEADING_STALE_AFTER_S, now):
        payload["motion"] = {"heading_deg": None, "heading_source": None}
        payload["source"] = {
            **payload["source"],
            "heading_source": None,
        }
    if not is_fresh(state, "position", POSITION_STALE_AFTER_S, now):
        payload["position"] = {
            "latitude_deg": None,
            "longitude_deg": None,
            "altitude_m": None,
        }
    if not is_fresh(state, "battery", BATTERY_STALE_AFTER_S, now):
        payload["system"] = {
            **payload["system"],
            "battery_percent": None,
            "battery_voltage_v": None,
            "battery_current_a": None,
            "battery_validity": "Unavailable",
            "battery_source": None,
        }
    return payload


def format_number(value: Any, decimals: int) -> str:
    if value is None:
        return "--"
    return f"{value:.{decimals}f}"


def main() -> int:
    args = parse_args()
    if args.rate <= 0:
        raise SystemExit("--rate must be greater than 0")

    try:
        from pymavlink import mavutil
    except ImportError:
        print("python3 -m pip install pymavlink")
        return 0

    destination = (args.out_host, args.out_port)
    publish_interval = 1.0 / args.rate
    next_publish_at = time.monotonic()
    packet_number = 0
    state = initial_state()

    print(f"Connecting to MAVLink telemetry on {args.connect}")
    print(
        "Publishing receive-only UDP JSON telemetry to "
        f"{args.out_host}:{args.out_port} at {args.rate:g} Hz"
    )

    mavlink = mavutil.mavlink_connection(args.connect, baud=args.baud)

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp_socket:
        try:
            while True:
                now = time.monotonic()
                timeout = max(0.0, min(0.02, next_publish_at - now))
                msg = mavlink.recv_match(blocking=True, timeout=timeout)
                if msg is not None:
                    if args.verbose:
                        src_sysid, src_compid = message_source(msg)
                        print(
                            f"mavlink={msg.get_type()} "
                            f"sysid={src_sysid} compid={src_compid}"
                        )
                    update_state_from_message(state, msg, mavutil, args.verbose)

                if time.monotonic() >= next_publish_at:
                    packet_number += 1
                    state["timestamp"] = utc_timestamp()
                    payload_state = public_state(state)
                    payload = json.dumps(payload_state, separators=(",", ":")).encode(
                        "utf-8"
                    )
                    udp_socket.sendto(payload, destination)

                    position = payload_state["position"]
                    attitude = payload_state["attitude"]
                    system = payload_state["system"]
                    battery_pct = system["battery_percent"]
                    print(
                        f"packet={packet_number} "
                        f"mode={system['mode']} "
                        f"armed={system['armed']} "
                        f"lat={format_number(position['latitude_deg'], 7)} "
                        f"lon={format_number(position['longitude_deg'], 7)} "
                        f"yaw={format_number(attitude['yaw_deg'], 1)} "
                        f"battery={battery_pct if battery_pct is not None else '--'}% "
                        f"dest={args.out_host}:{args.out_port}"
                    )
                    next_publish_at += publish_interval
        except KeyboardInterrupt:
            print("\nMAVLink bridge stopped.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
