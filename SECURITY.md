# Security policy: attest-check

## Posture

attest-check is provided as-is, with NO WARRANTY (see LICENSE). It is one gate in
a review pipeline, not a guarantee of review quality.

The honest ceiling: attest-check bounds a specific *lie*, a reviewer's silence
about an item being recorded as a verdict about it. It does **not** and cannot
detect a *skim*: a reviewer that names every item but examined none carefully will
pass. If review depth matters, measure it separately (e.g. with a known-answer
corpus of planted defects). Treating a green attest-check as proof of a thorough
review is a misuse it cannot prevent.

## Validation status

The standalone suite `tests/test-attest-check.sh` runs offline (bash + coreutils,
no network, no keys) and passes 22/22, including the two measured `bash`
regressions (a >64KB SIGPIPE false-miss and a quadratic whitespace scan). Run it
before relying on the tool:

    bash tests/test-attest-check.sh

## Reporting a vulnerability

Please report suspected vulnerabilities privately through this repository's
**Security → Report a vulnerability** tab (GitHub private vulnerability
reporting). Do not open a public issue for a suspected vulnerability, this keeps
the report private until a fix is available.
