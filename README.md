# attest-check

[![tests](https://github.com/justin-rhee/attest-check/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/attest-check/actions/workflows/test.yml) [![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) ![shell](https://img.shields.io/badge/shell-bash-blue.svg) ![zero dependencies](https://img.shields.io/badge/dependencies-0-brightgreen.svg)

Rejects an agent's review when it skipped any of the items you asked it to check, and names the ones it left out.

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

Six changes were once approved and logged as done when the agent had read two of them, and nothing in its confident reply mentioned the four it dropped. You can't make an agent read carefully, but you can refuse an answer about something it never mentioned.

## Use it if

- an agent checks several things in one go, and something downstream acts on each answer
- a shallow review has to be caught before the verdict is recorded
- you want the silent miss named by id, not found by hand

## Install

One shell script, nothing to install. Try it on the sample reply first:

```sh
git clone https://github.com/justin-rhee/attest-check
cd attest-check
bash src/attest-check.sh examples/sample-reply.txt A1 A2 A3      # passes
bash src/attest-check.sh examples/sample-reply.txt A1 A2 A3 A4   # fails, names A4
```

Exit 0 means every item was named, 1 means the list is missing or an item wasn't named, and 64 means it was called wrong.

## How it works

You give it the reply and the ids you asked about. The reply carries a short list naming each item, in the shape described in [docs/FORMAT.md](docs/FORMAT.md). Any id missing from that list fails the check, by name.

## What it won't do

- tell you whether the review was any good, since an agent can name all six items and barely look at them
- measure shallow reading, which nothing can judge from outside, only the silent miss I hit
- read what was written about each item, only check that each one is named
- work as a product on its own, since it's a small check you drop into your own harness
- run on Windows yet

## How I tested it

- 22 offline cases: `bash tests/test-attest-check.sh`
- covers the ways a shallow review slips through, plus two bugs that only showed up on very large replies
- CI runs them on macOS and Ubuntu; the reasoning is in [docs/ADR.md](docs/ADR.md)

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

<!-- related:start -->
## Related

- [anchor-check](https://github.com/justin-rhee/anchor-check): catches plans that cite files that don't exist
- [judgment-check](https://github.com/justin-rhee/judgment-check): has agents commit to a prediction first, then a different agent scores it

Part of a small set of tools I pulled out of my own agent harness. I use them myself and read every issue. More on my [GitHub profile](https://github.com/justin-rhee).
<!-- related:end -->
