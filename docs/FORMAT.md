# The VERDICT-PROVENANCE format

`attest-check` verifies one thing: that a batched reviewer reply contains a
roll-call block naming every item it was asked to review. This is the contract
that block must satisfy. It is deliberately tiny, the point is that a machine,
not a human, confirms the reviewer accounted for each item.

## The block

A reply MUST contain a line whose (whitespace-trimmed) start is:

    VERDICT-PROVENANCE:

followed by one or more lines naming each reviewed item, followed by a line that
is exactly one verdict tag on its own:

    UPHELD          (all items pass)
    REFUTED         (at least one concrete failure found)
    UNVERIFIABLE    (could not determine)

Everything between the `VERDICT-PROVENANCE:` header and that terminating tag is
"the block." Only text inside the block counts as accounting for an item, a
mention in the surrounding prose does not.

## What "naming an item" means

An item id (the ids you pass on the command line) must appear inside the block as
a whole word. Matching is literal and word-bounded:

- literal: an id like `A.` or `A[7]` matches only that exact text, never as a
  regex;
- word-bounded: `A1` does **not** satisfy `A10` and vice versa.

The internal shape of each line is up to you, `attest-check` does not parse it.
A common, readable convention is one line per item:

    <item-id> | "<quoted evidence you actually looked at>" | <per-item note>

but `attest-check` only checks that each id is present as a word in the block.

## Two rules that exist because attackers are lazy

1. **The LAST `VERDICT-PROVENANCE:` header wins.** Otherwise a reply could open
   with a placeholder header, pull all of its analysis prose into "the block,"
   and pass while literally stating "item 3 I did not examine." The real block is
   the one just before the verdict tag.
2. **A missing block is a hard fail (exit 1), not a pass.** The protocol makes the
   block mandatory; its absence means the reply did not follow the protocol, so no
   per-item verdict can be trusted from it. Absence is never accounted-for.

See `examples/sample-reply.txt` for a complete, valid reply.
