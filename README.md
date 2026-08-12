# attest-check

[![test](https://github.com/justin-rhee/attest-check/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/attest-check/actions/workflows/test.yml)

A check that reads an agent's answer and fails it if anything you asked about went unmentioned.

## Why I built it

An agent told me six changes were fine. It had only read two.

The other four were never mentioned in the reply. Not rejected, not questioned, just absent. All six went into my log as approved, because the thing reading that reply was looking at the overall verdict and nobody was watching for the gap.

If you hand an agent a batch of anything and act on what comes back, you have this problem sitting in your harness right now. It doesn't announce itself. The reply was well written and confident about the two it had actually looked at, and nothing in it suggested that four items had quietly fallen out along the way.

## How it works

You can't make an agent read carefully. You can refuse to accept an answer about something it never mentioned.

You give it the reply and the list of items you asked about. It checks that each one is named somewhere in the reply. If any are missing it fails and tells you which.

```console
$ attest-check.sh reply.txt A1 A2 A3
attest-check: ok, all 3 item(s) accounted for in the VERDICT-PROVENANCE block

$ attest-check.sh reply.txt A1 A2 A3 A4
attest-check: FAIL, the reviewer did not account for: A4
attest-check: 3 of 4 items accounted for in the VERDICT-PROVENANCE block.
attest-check: do NOT record a verdict for an unaccounted item. Re-review the unaccounted ones, or re-run the batch with fewer items per call.
$ echo $?
1
```

About 60 lines of shell. The reply needs to carry a short list naming each item, and the shape of that list is in [docs/FORMAT.md](docs/FORMAT.md).

## Install

Nothing to install. One shell script, no dependencies.

```
attest-check.sh <reviewer-out-file> <item-id> [<item-id> ...]
# exit 0  everything was named
# exit 1  the list is missing, or an item wasn't named, and it tells you which
# exit 64 you called it wrong
```

There's a sample reply to try it against before you wire it into anything:

```
src/attest-check.sh examples/sample-reply.txt A1 A2 A3     # passes
src/attest-check.sh examples/sample-reply.txt A1 A2 A3 A4  # fails, points at A4
```

It fits anywhere an agent checks several things in one go and something downstream acts on each answer.

## What it won't do

- It won't tell you whether the review was any good. An agent can name all six items and still have barely looked at them. This catches the silent miss, which is the failure I actually hit, not shallow reading, which nothing can measure from the outside.
- It doesn't read what you wrote about each item, only that each one is named. What goes in each line is yours.
- It's a small check you drop into your own harness, not a product on its own.

## How I tested it

The suite runs offline, no accounts or keys:

```
bash tests/test-attest-check.sh
```

22 cases. They cover the ways a shallow review slips through, plus two bugs I hit while writing it, both of which only appeared on very large replies. Those tests exist so the bugs cannot come back. The reasoning is in [docs/ADR.md](docs/ADR.md).

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

---

One of a set of small tools I've pulled out of a bigger system I run, where agents write the code and plain scripts decide when it's actually done. They all share one rule: the machine suggests, a person decides, and nothing quietly goes wrong behind your back. More of them on my [GitHub profile](https://github.com/justin-rhee).
