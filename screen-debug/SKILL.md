---
name: screen-debug
description: Test interactive CLI applications (readline/console-based) that don't accept piped stdin, using GNU screen as a PTY intermediary. Use when a piped/heredoc/expect approach to an interactive shell blocks or fails on terminal size queries. Also covers driving remote targets and VM serial consoles through a local screen session.
---

# Screen Debug

## Purpose
Test interactive CLI applications that use readline/console libraries (reeflective/console, etc.) and don't accept stdin input. Also the standard way to interact with SSH sessions, virsh consoles, and VMs from a non-TTY automation context.

## Problem
Interactive shells require a real PTY and don't work with:
- Piped stdin (`echo "command" | app`)
- Heredocs
- Simple expect scripts (terminal size queries block)

Additionally, `screen -S name -X stuff` / `-X hardcopy` work **without a TTY** — so screen is also how an agent drives terminals it cannot attach to.

## Solution
Use GNU `screen` as a local PTY intermediary:
1. Start a **local** screen session with the app/command as its child
2. Send commands via `-X stuff`
3. Capture output via `-X hardcopy -h` (scrollback)

## Helper Functions

Source these in your shell (or inline them):

```bash
# Strip ANSI escape sequences from captured output
strip_ansi() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g'; }

# Capture FULL scrollback of a session (hardcopy -h = whole buffer;
# plain hardcopy only sees the VISIBLE screen — always use -h)
cap() { # cap <session> [outfile]
    local s="$1" f="${2:-/tmp/sc-${1}.txt}"
    screen -S "$s" -X hardcopy -h "$f"
    sleep 0.2
    sed -i 's/[[:space:]]*$//' "$f"
    echo "$f"
}

# Send a command line (^M = Enter)
send() { # send <session> <command> [delay]
    screen -S "$1" -X stuff "$2^M"
    sleep "${3:-1}"
}

# Capture ONLY the last command's output: the whole-scrollback capture
# includes EVERYTHING from the session start (earlier commands pollute
# later assertions). This keeps lines from the last prompt onward.
# Set PROMPT_RE per app, e.g. PROMPT_RE='^router[#>] '
cap_last() { # cap_last <session> [outfile]
    local s="$1" f="${2:-/tmp/scl-${1}.txt}"
    screen -S "$s" -X hardcopy -h "$f"
    sleep 0.2
    sed -i 's/[[:space:]]*$//' "$f"
    local tmp="$f.tmp"
    awk -v re="${PROMPT_RE:-^[^ ]+[#>] }" \
        '$0 ~ re {last=NR} {lines[NR]=$0} END{for(i=(last?last:1);i<=NR;i++) print lines[i]}' \
        "$f" > "$tmp" && mv "$tmp" "$f"
    echo "$f"
}

# Wait until a pattern appears in the scrollback (with timeout)
wait_for() { # wait_for <session> <pattern> [timeout_s]
    local s="$1" pat="$2" t="${3:-60}" f="/tmp/wf-${1}.txt" i=0
    while [ "$i" -lt "$t" ]; do
        screen -S "$s" -X hardcopy -h "$f" 2>/dev/null
        if grep -qE "$pat" "$f"; then return 0; fi
        sleep 1; i=$((i+1))
    done
    echo "TIMEOUT waiting for '$pat'" >&2; return 1
}
```

## Local Session, Remote Target (PREFERRED)

Start screen **locally** with the remote command as the child. Every
`stuff`/`hardcopy` is then local — no ssh round-trip per interaction,
no orphaned sessions on the remote, no `screen` needed remotely.

```bash
# SSH into a remote host
screen -dmS host1 ssh root@192.168.122.40

# VM serial console via virsh (session mode = no root needed)
screen -dmS vm1 virsh -c qemu:///session console sash-test

# Interact — all local, instant:
send host1 "sash -c 'show version'"
f=$(cap_last host1); cat "$f" | strip_ansi
```

If the ssh connection drops, the screen session survives — re-run the
command inside (the window stays).

### When remote screen is justified
Only when the *remote local display* matters (GUI app that must run in
the remote session), or a long job must survive your downtime. Not for
agent-driven testing.

## Attached Sessions / Stealing

- `screen -S name -X stuff` / `-X hardcopy` work on **attached** sessions
  without stealing the terminal — read-only-ish driving is always safe.
- **Detach other users**: `screen -S name -X detach`
- **Share keystrokes interactively** (two people typing): `screen -x name`
- List state: `screen -ls` shows `(Attached)` / `(Detached)`

## Gotchas (learned the hard way)

1. **Always `hardcopy -h`.** Plain `hardcopy` captures only the visible
   terminal — long output silently truncates and you'll chase ghosts.
2. **Scrollback pollution.** `-h` captures the ENTIRE session history.
   Earlier commands leak into your capture → use `cap_last` so assertions
   only see the last command's output.
3. **Last output line may be overwritten.** TUI prompt redraws can
   overwrite the final line of a command's output. Never assert on the
   last line of a capture; pick a line in the middle instead.
4. **ANSI codes are in captures.** Use `strip_ansi` before matching.
5. **Sleep generously.** `-X stuff` injects keystrokes; the app needs
   time to process. Start at 1s, increase if flaky.

## Minimal Recipe

```bash
screen -dmS app app-bin
sleep 2
send app "configure" 2
send app "set route static 10.0.0.0/8 next-hop 192.168.1.1" 1
send app "compare" 1
f=$(cap_last app); cat "$f" | strip_ansi
send app "discard" 1
screen -S app -X quit
```
