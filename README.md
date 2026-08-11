# attest-check

An AI agent will approve a whole batch of changes without reading each one. Mine approved six but had really only looked at two, and all six got logged as done.

You can't force an agent to read carefully. But you can refuse to accept an answer for anything it never actually named. That's all this does. It reads the agent's reply and fails if the reply doesn't list every item you asked it to check. It's about 60 lines of bash.

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

Worth being upfront: this can't tell you whether the agent looked *hard*. Nothing can measure that. It catches the one thing you actually can check, which is the agent staying silent about something and that silence getting logged as approval. The full reasoning is in [docs/ADR.md](docs/ADR.md).

## Use it if

You have an agent checking several things in one go, code changes, tickets, checklist items, and then acting on each answer. If you build workflows like that, this is the small safety check you don't think you need until a shallow review slips through.

```
attest-check.sh <reviewer-out-file> <item-id> [<item-id> ...]
# exit 0  everything was named
# exit 1  the list is missing, or an item wasn't named (it tells you which)
# exit 64 you called it wrong
```

The agent's reply needs to include a short list that names each item; the exact shape is in [docs/FORMAT.md](docs/FORMAT.md). There's a sample file to try it on:

```
src/attest-check.sh examples/sample-reply.txt A1 A2 A3     # passes
src/attest-check.sh examples/sample-reply.txt A1 A2 A3 A4  # fails, points at A4
```

## What it won't do

- It won't tell you if the review was any good. An agent can name every item and still have barely looked. This catches the silent miss, not a review that named everything but looked at none of it. How carefully it looked is a separate, harder thing to measure.
- It doesn't read the contents of your list, only checks that each name shows up. How you write each line is up to you.
- It's one small check you drop into your own setup, not a product on its own.

## How I tested it

You can run the test suite offline, no accounts or keys needed:

```
bash tests/test-attest-check.sh    # 22 checks
```

It covers the ways a shallow review can slip through, plus two bugs I hit and fixed while writing it, both the kind that only show up on very large replies. The tests keep them from coming back. Details are in [docs/ADR.md](docs/ADR.md).

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

---

One of a set of small tools I've pulled out of a bigger system I run, where agents write the code and plain scripts decide when it's actually done. They all share one rule: the machine suggests, a person decides, and nothing quietly goes wrong behind your back. More of them on my [GitHub profile](https://github.com/justin-rhee).
