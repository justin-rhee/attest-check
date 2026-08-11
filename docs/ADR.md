# Architecture Decision Records (ADRs)

Short notes on the design decisions behind this tool, one per real problem I hit.
The tests enforce these; this is the reasoning.

## 1. A silent answer can't count as approval

When an agent reviews several items in one call and my program records a yes-or-no
for each, an agent that really looked at two of six and said "all good" still
produced six approvals. A later step read those six as fact, so a shallow review
turned into a batch of confident sign-offs. Whether the agent looked carefully
isn't something a script can measure.

So instead the tool makes the agent include a short list that names every item it
was asked about, and checks that it actually did. If an item isn't named, it
refuses to record an answer for it. If the list is missing entirely, that's a hard
fail.

This can't judge how good the review was, and it doesn't try to. It catches one
specific thing: an item the agent stayed silent about getting logged as approved.
That's the difference between "the agent approved this" and "the agent said it
approved this," for about 60 lines and one extra check.

## 2. Only the real list counts, and the last one wins

An early version looked for the first "here's my list" marker and read everything
after it. That let a reply open with an empty marker, pull all of its rambling into
"the list," and pass, even while plainly saying "item 3 I didn't look at." A mention
of an item in the surrounding text, outside the list, was also being counted as if
the agent had checked it.

Now it only reads the list that comes right before the final verdict, so a new
marker resets what counts and the last one wins. And an item only counts if its
name appears inside that list, as a whole word.

The two easiest ways to fool the check, a decoy marker and an offhand mention, both
stop working. Matching whole words also means `A1` never counts as `A10`, and an
item name with odd characters in it can't accidentally match.

## 3. Big replies have to be both fast and correct

This runs on every batch, so it sees large replies, and two bugs lived here that
never showed up on small ones.

The first: the check for "is this blank" was written in a way that gets dramatically
slower as the input grows. On the version of bash that ships with macOS, a 12KB
reply took over 90 seconds, and a 135KB one never finished.

The second was worse. The check for "did the reply name this item" piped text into
`grep -q`. `grep -q` stops at the first match, so once the reply got bigger than the
operating system's pipe buffer (64KB), the part still being written got cut off, and
a strict-error setting turned that into a wrong answer: the item read as missing when
it was right there. It only happened for items named early in a big reply. I measured
it: the same input passed at 60KB and failed at 67KB.

I rewrote both to avoid the slow path and the pipe entirely. The test that exercises
this is sized past 64KB on purpose, so that second bug can't quietly come back.

The lesson I took from it: a bug that only appears past a certain size passes every
small test and then fails in production. If a check can give a wrong answer at scale,
you have to test it at scale, or a green test is just telling you it hasn't been
tried hard enough.
