# Contributing

## Branch Expectations

- Keep changes focused and reviewable.
- Separate cleanup, architecture foundation, and feature work into distinct
  commits or pull requests.
- Do not mix command-authority work into unrelated changes.

## Required Checks

Run before commit:

```bash
flutter analyze
flutter test
(cd rust && cargo fmt --check)
(cd rust && cargo test)
```

Run `dart format .` and `cargo fmt` when formatting is needed.

## Safety Rules

- Do not add mission upload, arm/disarm, RTL, hold, guided movement, mode
  changes, manual control commands, actuator commands, or payload-release
  workflows without explicit approval.
- Do not add online/cloud dependencies without discussion.
- Keep V1 Linux-first and offline-first.
- Preserve the command lockout and safety documentation.

## Tests

- Add tests for domain and application changes.
- Keep the current dashboard telemetry flow working.
- Do not remove generated Rust bridge files unless they are regenerated
  correctly and all tests pass.
