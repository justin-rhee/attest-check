# attest-check

[![test](https://github.com/justin-rhee/attest-check/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/attest-check/actions/workflows/test.yml)

One small shell check for batch agent reviews: **account for every item you asked about**, **fail with the unaccounted ids named**, and **stop the verdict before an unaccounted item gets recorded as done**. About 60 lines of shell, no dependencies, nothing to install.

It exists because six changes were once approved and logged as done when the agent had actually read two of them, and nothing in a confident reply announced the four it quietly dropped. You can't make an agent read carefully, but you can refuse to accept an answer about something it never mentioned. This is that refusal.

## Use it if

- an agent checks several things in one go, code changes, tickets, checklist items, and something downstream acts on each answer
- a shallow review has to be caught before the verdict is recorded
- you want the silent miss named by id, not found by hand

## How it works

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

The reply needs to carry a short list naming each item, and the shape of that list is in [docs/FORMAT.md](docs/FORMAT.md).

## Install

Nothing to install. One shell script, no dependencies. There's a sample reply to try it against before you wire it into anything:

```sh
git clone https://github.com/justin-rhee/attest-check
bash src/attest-check.sh examples/sample-reply.txt A1 A2 A3     # passes
bash src/attest-check.sh examples/sample-reply.txt A1 A2 A3 A4  # fails, points at A4
```

```
attest-check.sh <reviewer-out-file> <item-id> [<item-id> ...]
# exit 0  everything was named
# exit 1  the list is missing, or an item wasn't named, and it tells you which
# exit 64 you called it wrong
```

Verify it took effect rather than assuming: the second sample call above must fail and name A4 before you point it at a real reviewer.

## Platforms

macOS and Linux today. Windows on the way.

## What it won't do

- tell you whether the review was any good, since an agent can name all six items and still have barely looked at them
- measure shallow reading, which nothing can judge from the outside, only the silent miss that I actually hit
- read what you wrote about each item, only check that every one is named
- work as a product on its own, since it's a small check you drop into your own harness

## How I tested it

The suite runs offline, no accounts or keys:

```sh
bash tests/test-attest-check.sh
```

22 cases. They cover the ways a shallow review slips through, plus two bugs I hit while writing it, both of which only appeared on very large replies. Those tests exist so the bugs cannot come back. The reasoning is in [docs/ADR.md](docs/ADR.md).

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

This little tool is one of a handful I pulled out of my own day-to-day agent setup. I use them all myself, so when something breaks I usually notice fast. But if you run into any issues, or anything that looks off, open an issue. I read every one. More tools on my [GitHub profile](https://github.com/justin-rhee).
