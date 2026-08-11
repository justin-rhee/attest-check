#!/usr/bin/env bash
# test-attest-check.sh, standalone offline test suite for attest-check.sh.
# No dependencies beyond bash + awk + grep + coreutils. One command:
#   bash tests/test-attest-check.sh
# Exit 0 = all pass. Every check below maps to a defect the tool was built to
# catch, plus the two measured bash bugs (SIGPIPE false-miss, quadratic scan).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC="$HERE/../src/attest-check.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/attestci.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok    $*"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL  $*"; }
check() { # check <label> <actual-rc> <expected-rc>
  if [ "$2" = "$3" ]; then ok "$1 (rc=$2)"; else bad "$1 (got rc=$2, want $3)"; fi
}

mk_reply() { # mk_reply <file> <provenance-body> <verdict>
  { printf 'Some reasoning prose that happens to mention A9 in passing.\n\n'
    printf 'VERDICT-PROVENANCE:\n'
    printf '  findings: 0\n'
    printf '%s\n' "$2"
    printf '%s\n' "$3"
  } > "$1"
}

echo "== 1. the roll-call is verified, not trusted =="
full="$WORK/full.out.txt"
mk_reply "$full" '  A1 | "const x = 1" | verified
  A2 | "return ok" | verified
  A3 | "guard present" | verified' 'UPHELD'
bash "$AC" "$full" A1 A2 A3 >/dev/null 2>&1; check "all three named -> exit 0" "$?" "0"

partial="$WORK/partial.out.txt"
mk_reply "$partial" '  A1 | "const x = 1" | verified
  A3 | "guard present" | verified' 'UPHELD'
out_msg="$(bash "$AC" "$partial" A1 A2 A3 2>&1)"; check "one unnamed -> exit 1" "$?" "1"
grep -q 'A2' <<< "$out_msg" && ok "failure names the unaccounted item" || bad "failure must name the unaccounted item"
grep -q 'A1' <<< "$out_msg" && bad "failure must not name accounted items" || ok "failure does not name accounted items"

noblock="$WORK/noblock.out.txt"
printf 'I reviewed A1 A2 A3 and they all look fine.\nUPHELD\n' > "$noblock"
bash "$AC" "$noblock" A1 A2 A3 >/dev/null 2>&1; check "no VERDICT-PROVENANCE block -> exit 1 even though the ids appear" "$?" "1"

# A restated block header must not swallow the analysis prose as "the block".
twohdr="$WORK/twohdr.out.txt"
{ printf 'VERDICT-PROVENANCE:\n(will fill in below)\n\n'
  printf 'Analysis. A1 seems ok. A2 seems ok. A3 I did not examine.\n\n'
  printf 'VERDICT-PROVENANCE:\n  findings: 0\n  A1 | "a" | ok\n'
  printf 'UPHELD\n'
} > "$twohdr"
bash "$AC" "$twohdr" A1 A2 A3 >/dev/null 2>&1; check "a restated header cannot launder unexamined items" "$?" "1"
bash "$AC" "$twohdr" A1 >/dev/null 2>&1; check "the LAST block is the one that counts" "$?" "0"

# Regex metacharacters in an item id must be literal, not a pattern.
meta="$WORK/meta.out.txt"
mk_reply "$meta" '  A7 | "z" | verified' 'UPHELD'
for badid in 'A.' 'A[7]' 'A*'; do
  bash "$AC" "$meta" "$badid" >/dev/null 2>&1; check "id '$badid' does not pattern-match A7" "$?" "1"
done

echo "== 2. large replies must be FAST and CORRECT (SIGPIPE + quadratic regressions) =="
# Deliberately sized ABOVE the 64KB pipe buffer: an early-matching id is what
# triggers the SIGPIPE false-miss; a late-matching id lets printf finish first.
big="$WORK/big.out.txt"
{ printf 'VERDICT-PROVENANCE:\n  findings: 0\n'
  printf '  ROLL-CALL A1 | "the FIRST line, matched early, which is what triggers SIGPIPE" | verified\n'
  i=0; while [ "$i" -lt 1200 ]; do
    printf '  ROLL-CALL Afill | "a line of quoted evidence padded out to a realistic width %d" | verified\n' "$i"
    i=$((i + 1))
  done
  printf '  ROLL-CALL A2 | "the LAST line, matched late, so printf finishes first" | verified\n'
  printf 'UPHELD\n'
} > "$big"
bytes="$(wc -c < "$big" | tr -d ' ')"
[ "$bytes" -ge 70000 ] && ok "large-reply fixture clears the 64KB pipe buffer (${bytes} bytes)" \
  || bad "large-reply fixture must exceed 65536 bytes (${bytes} bytes)"
t0=$(date +%s)
bash "$AC" "$big" A1 >/dev/null 2>&1; rc_early=$?
bash "$AC" "$big" A2 >/dev/null 2>&1; rc_late=$?
bash "$AC" "$big" A1 A2 >/dev/null 2>&1; rc_both=$?
t1=$(date +%s)
check "large reply: EARLY-matching item accounted (SIGPIPE regression)" "$rc_early" "0"
check "large reply: LATE-matching item accounted" "$rc_late" "0"
check "large reply: both accounted together" "$rc_both" "0"
elapsed=$((t1 - t0))
[ "$elapsed" -le 5 ] && ok "large reply completes promptly (${elapsed}s for 3 runs)" \
  || bad "large reply took ${elapsed}s, the O(n^2) whitespace test is back"
bash "$AC" "$big" A1 A99 >/dev/null 2>&1; check "large reply: a genuinely unnamed item still fails" "$?" "1"

echo "== 3. usage + scoping (block-only; A1 does not match A10) =="
bash "$AC" "$WORK/does-not-exist.txt" A1 >/dev/null 2>&1; check "missing out-file -> exit 64" "$?" "64"
bash "$AC" "$full" >/dev/null 2>&1; check "no item ids -> exit 64" "$?" "64"

outside="$WORK/outside.out.txt"
{ printf 'Prose discussing A2 at length before the block.\n\n'
  printf 'VERDICT-PROVENANCE:\n  findings: 0\n  A1 | "x" | verified\n'
  printf 'UPHELD\n'
} > "$outside"
bash "$AC" "$outside" A1 A2 >/dev/null 2>&1; check "a mention OUTSIDE the block does not count" "$?" "1"

tens="$WORK/tens.out.txt"
mk_reply "$tens" '  A10 | "y" | verified' 'UPHELD'
bash "$AC" "$tens" A1  >/dev/null 2>&1; check "A10 in the block does not satisfy A1" "$?" "1"
bash "$AC" "$tens" A10 >/dev/null 2>&1; check "A10 satisfies A10" "$?" "0"

refuted="$WORK/refuted.out.txt"
mk_reply "$refuted" '  A1 | "bad line" | concrete failure
  A2 | "ok line" | verified' 'REFUTED'
bash "$AC" "$refuted" A1 A2 >/dev/null 2>&1; check "roll-call is checked on REFUTED replies too, not just UPHELD" "$?" "0"

echo "test-attest-check: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
