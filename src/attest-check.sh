#!/usr/bin/env bash
# attest-check.sh, verify a BATCHED reviewer reply actually accounted for every
# item in the batch, before a caller fans one batch-level verdict out into N
# per-item records.
#
# Usage: attest-check.sh <reviewer-out-file> <item-id> [<item-id> ...]
#
# WHY THIS EXISTS
# When an LLM reviews N items in ONE call and the caller records a per-item
# verdict for each, a reviewer that meaningfully examined 2 of 6 items and replied
# UPHELD still produces 6 attested UPHELD records, and a downstream step reads
# those as machine truth, so a skim launders itself into a batch of ship-grade
# attestations. The fix is a protocol: the reviewer must emit a VERDICT-PROVENANCE
# roll-call naming every item. This is the machine check that it actually did.
# Attestation nobody verifies is not attestation.
#
# This does NOT judge whether the reviewer looked *hard*, no script can. It
# enforces the one thing that IS mechanically checkable: silence about an item
# can never be recorded as a verdict about it.
#
# SCOPE: only the VERDICT-PROVENANCE block is searched, from the block header to
# the final verdict tag, so an incidental mention of item 3 in the surrounding
# prose does not count as having examined item 3. A missing block is a hard fail:
# the protocol makes it mandatory, so its absence means the reply did not follow
# the protocol and no per-item verdict can be derived from it.
#
# The LAST header wins. Taking the first would let a reply open with a placeholder
# "VERDICT-PROVENANCE:" line and thereby pull its entire analysis prose into the
# "block", so a reply that says in plain English "item 3 I did not examine" would
# pass the very check that exists to catch it. The real block is the one that
# precedes the verdict tag.
#
# Exit: 0 every item accounted for | 1 one or more unaccounted (named on stderr)
#       | 64 usage.
set -euo pipefail

usage() {
  printf 'usage: attest-check.sh <reviewer-out-file> <item-id> [<item-id> ...]\n' >&2
  exit 64
}

[ "$#" -ge 2 ] || usage
out_file="$1"; shift
[ -f "$out_file" ] || { printf 'attest-check: no such file: %s\n' "$out_file" >&2; exit 64; }

# Extract the provenance block: from the VERDICT-PROVENANCE header to the final
# verdict tag (or EOF). awk, so no dependency on the block's internal shape.
block="$(awk '
  # A new header RESETS the accumulator: only the last block survives.
  /^[[:space:]]*VERDICT-PROVENANCE:/ { inblock = 1; buf = ""; next }
  inblock && /^[[:space:]]*(UPHELD|REFUTED|UNVERIFIABLE)[[:space:]]*$/ { inblock = 0 }
  inblock { buf = buf $0 "\n" }
  END { printf "%s", buf }
' "$out_file")"

# Whitespace-only test via `case`, NOT `${block//[[:space:]]/}`: global pattern
# substitution is quadratic in bash 3.2 (still the default /bin/bash on macOS).
# A routine 12KB batched reply took over 90s through that expansion and a 135KB one
# never finished, this script is meant to run before every batch verdict, so it
# would have wedged real runs. `case` is O(n).
case "$block" in
  *[![:space:]]*) : ;;
  *)
    printf 'attest-check: FAIL, no VERDICT-PROVENANCE block found in %s\n' "$out_file" >&2
    printf 'attest-check: the protocol makes it mandatory; without it no per-item verdict can be derived. Treat as UNVERIFIABLE and surface it.\n' >&2
    exit 1 ;;
esac

missing=""
accounted=0
for cp in "$@"; do
  # A HERESTRING, never `printf | grep -q`. `grep -q` exits on its first match, so
  # once the block exceeds the 64KB pipe buffer the still-writing printf takes
  # SIGPIPE, `pipefail` turns that into a failed pipeline, and the `if` reads it as
  # "item not named", a silent FALSE MISSING above 64KB, and only for items
  # matched EARLY (a late match lets printf finish first). Measured: identical
  # input at 60KB answered correctly, at 67KB did not. Herestrings go via a temp
  # file, so there is no pipe and no early-exit race.
  # -F: an item id is a LITERAL, never a pattern (an id like `A.` or `A[7]` would
  # otherwise match a block that never named it).
  # -w so item id `A1` does not match `A10` (the trailing digit is a word character).
  if grep -Fqw -- "$cp" <<< "$block"; then
    accounted=$((accounted + 1))
  else
    missing="$missing $cp"
  fi
done

if [ -n "$missing" ]; then
  printf 'attest-check: FAIL, the reviewer did not account for:%s\n' "$missing" >&2
  printf 'attest-check: %d of %d items accounted for in the VERDICT-PROVENANCE block.\n' "$accounted" "$#" >&2
  printf 'attest-check: do NOT record a verdict for an unaccounted item. Re-review the unaccounted ones, or re-run the batch with fewer items per call.\n' >&2
  exit 1
fi

printf 'attest-check: ok, all %d item(s) accounted for in the VERDICT-PROVENANCE block\n' "$#"
exit 0
