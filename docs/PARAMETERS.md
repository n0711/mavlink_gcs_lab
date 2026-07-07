# Parameters

The Parameters tab is an offline file-review tool. It does not connect to a
vehicle and does not write parameters.

## Supported File Conventions

The parser accepts common saved ArduPilot/Mission Planner-style lines:

```text
ARMING_CHECK,1
GPS_TYPE 1
BATT_MONITOR=4
```

Full-line `#` and `//` comments are ignored. Inline comments are stripped and
counted so reports can show file-quality diagnostics.

## Comparison Policy

The diff compares a current file against a baseline file and classifies each
parameter as:

- changed
- added
- removed
- unchanged

Duplicate names are reported. If a file contains duplicates, the last parsed
value is used for comparison.

## Report Export

Markdown export includes:

- safety boundary
- summary counts
- changed/added/removed tables
- parser diagnostics
- duplicate summary
- local category/review hints

The category and review hints are local labels only. They are not official
ArduPilot metadata and do not imply safety approval.
