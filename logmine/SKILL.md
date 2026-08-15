---
name: logmine
description: Cluster noisy logs by pattern (drain3) to find the dominant/hot repeated line, extract what's filling a wildcard, or diff a log window against a baseline to catch new/gone patterns after a fix or restart
---

# logmine

`logmine` — pipe any log stream in, get back distinct patterns ranked by count instead of a wall of near-duplicate lines. Reach for this *before* hand-writing a `grep -oE ... | sort | uniq -c | sort -rn` pipeline to find "what's the hot repeated log line."

```bash
journalctl -u k6s --since '10s ago' | logmine
```

```
[ 692x] ...Webhook request... "kind":"Orphan"...
[   8x] ...Webhook response... status": 200...
```

Built-in masking already treats UUIDs, long hex hashes (16+ chars — request IDs, CRD instance hashes), IPv4 addresses, and ISO timestamps as wildcards, so unrelated lines that only differ by one of those still cluster together from the first example (no need to see the field repeat to learn it varies).

## Three debugging workflows

**1. Find the dominant pattern** (default mode, shown above) — the fast path for "why is this process busy" or "what's actually filling this log." Pull a short window (5-15s is usually enough for anything happening at more than ~1/sec) and read the counts top-down.

**2. Is it the same thing retrying, or many different things?**

```bash
journalctl -u k6s --since '10s ago' | logmine --values orphan
```
```
[ 156x] ...orphan-<HEX>... retry...
         14 distinct value-tuple(s):
           ('a1b2...',) ('c3d4...',) ...
```
14 distinct hashes each retried ~11x — a real fan-out of failures, not one object stuck in a hot loop. If it had printed `1 distinct value-tuple(s)`, that's a single stuck retry instead. This is the question to ask before you start guessing at root cause — "one thing looping" and "many things individually failing" point at completely different bugs.

**3. Did the fix/restart actually change anything?**

```bash
# before
journalctl -u k6s --since '2min ago' | logmine --save /tmp/baseline.state
# ...apply the fix, restart the thing...
# after
journalctl -u k6s --since '30s ago' | logmine --baseline /tmp/baseline.state
```
Prints only templates that are *new* since the baseline — either the fix introduced a new problem (something unexpected shows up) or, if it prints `no new patterns vs baseline`, confirms the noise floor didn't just shuffle. Pair this with a plain before/after line-count comparison (`journalctl ... | wc -l` over the same window length) to see whether volume actually dropped, not just which patterns are present — a fix can eliminate one pattern while an unrelated one at the same rate takes over, and only the raw count catches that.

## Notes

- `logmine` is a `uv run --script` shebang (deps: `drain3`) — first invocation in a while may take a moment to resolve.
- Not installed on remote hosts. Pipe remote logs back over SSH into the local binary: `ssh host "journalctl ..." | logmine`, don't expect it to exist on the target.
- `--top N` caps output if a window has too many distinct patterns to read.
- Source: `~/GITHUB/tools/logmine/logmine` (~130 lines, single self-contained script — read it directly if you need a mode it doesn't have).

## Install
```bash
ln -s ~/GITHUB/tools/logmine/logmine ~/.local/bin/logmine
```
