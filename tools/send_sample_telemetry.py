#!/usr/bin/env python3
"""Send simulated receive-only telemetry to the MAVLink GCS Portfolio dashboard."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import socket
import time


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send simulated UDP JSON telemetry to the MAVLink GCS Portfolio.",
    )
    parser.add_argument("--host", default="127.0.0.1", help="Destination host.")
    parser.add_argument("--port", type=int, default=16000, help="Destination port.")
    parser.add_argument(
        "--rate",
        type=float,
        default=2.0,
        help="Packet send rate in Hz.",
    )
    parser.add_argument(
        "--armed",
        action="store_true",
        help="Mark simulated telemetry as armed. Defaults to false.",
    )
    return parser.parse_args()


def build_packet(packet_number: int, armed: bool) -> dict[str, object]:
    yaw_deg = (packet_number * 3.0) % 360.0
    roll_deg = math.sin(packet_number / 12.0) * 5.0
    pitch_deg = math.cos(packet_number / 15.0) * 4.0
    battery_percent = int(100 - ((packet_number * 0.1) % 86))
    battery_voltage_v = 10.5 + (battery_percent / 100.0) * (12.6 - 10.5)

    return {
        "message_type": "vehicle_state",
        "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
        "position": {
            "latitude_deg": 34.981269 + math.sin(packet_number / 80.0) * 0.00005,
            "longitude_deg": 34.002445 + math.cos(packet_number / 80.0) * 0.00005,
            "altitude_m": 4.8,
        },
        "motion": {
            "heading_deg": yaw_deg,
        },
        "attitude": {
            "roll_deg": roll_deg,
            "pitch_deg": pitch_deg,
            "yaw_deg": yaw_deg,
        },
        "system": {
            "armed": armed,
            "battery_percent": battery_percent,
            "battery_voltage_v": round(battery_voltage_v, 2),
            "mode": "MANUAL",
        },
    }


def main() -> int:
    args = parse_args()
    if args.rate <= 0:
        raise SystemExit("--rate must be greater than 0")

    destination = (args.host, args.port)
    interval_seconds = 1.0 / args.rate
    packet_number = 0

    print(
        "Sending simulated receive-only telemetry to "
        f"{args.host}:{args.port} at {args.rate:g} Hz. Press Ctrl+C to stop."
    )

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp_socket:
        try:
            while True:
                packet_number += 1
                packet = build_packet(packet_number, args.armed)
                payload = json.dumps(packet, separators=(",", ":")).encode("utf-8")
                udp_socket.sendto(payload, destination)

                system = packet["system"]
                attitude = packet["attitude"]
                print(
                    f"packet={packet_number} "
                    f"yaw={attitude['yaw_deg']:.1f} "
                    f"battery={system['battery_percent']}% "
                    f"dest={args.host}:{args.port}"
                )
                time.sleep(interval_seconds)
        except KeyboardInterrupt:
            print("\nTelemetry sender stopped.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
