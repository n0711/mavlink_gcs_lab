# Safety Boundary

This repository is a monitoring and offline-analysis prototype. It is not
flight software.

## Allowed In V1

- receive UDP JSON telemetry
- display telemetry status and stale state
- parse saved parameter files
- compare saved parameter files
- export a Markdown parameter report
- write local JSONL diagnostics

## Not Allowed In V1

- arm/disarm
- mode changes
- mission upload
- `COMMAND_LONG`
- `COMMAND_INT`
- `SET_MODE`
- `PARAM_SET`
- `MISSION_ITEM` or `MISSION_COUNT`
- manual control or RC override
- actuator, motor, servo, or payload commands
- `mavsdk_server`
- gRPC/protobuf command services

Any future command-capable work needs a separate safety design, explicit review,
hardware test plan, and operator confirmation model.
