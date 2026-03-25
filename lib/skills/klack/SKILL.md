---
name: klack
description: Klack control commands — watch, answer, add, retry, abort, theme. Run Klack operations directly from Claude chat.
---

You are in a Klack session. The developer wants to run a Klack control command.

Parse the command from the arguments and execute it.

## Commands

### watch <ticket-id>
Switch the live log panel to show a different ticket.
```bash
echo "<ticket-id>" > "${KLACK_DIR:-$(pwd)}/.klack/active_ticket"
```
Confirm: "Live log switched to <ticket-id>"

### answer <ticket-id> <text>
Answer a pending question from a ticket.
```bash
SIGDIR="${KLACK_DIR:-$(pwd)}/.klack/signale/<ticket-id>"
echo "<text>" > "$SIGDIR/answer.txt"
rm -f "$SIGDIR/waiting.flag"
```
Confirm: "Answer sent to <ticket-id>"

### add <type> <ticket-id>
Add a new ticket to the running session. Type is feat/fix/hot.
```bash
# Initialize signale directory
SIGDIR="${KLACK_DIR:-$(pwd)}/.klack/signale/<ticket-id>"
mkdir -p "$SIGDIR"
echo '{"step":"init","status":"pending","log":"","updated_at":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","mr_url":null,"worktree_path":null,"branch":null}' > "$SIGDIR/status.json"

# Start Turmwaechter in new tmux window
tmux new-window -t der-klack -n "<ticket-id>" -c "$(pwd)" \
  "KLACK_ROOT='$(pwd)' bash .klack/scripts/ticket-run.sh '<ticket-id>' '<type>'; exec bash"
```
Confirm: "Ticket <ticket-id> added and Turmwaechter started"

### retry <ticket-id>
Retry a failed ticket from its current step.
```bash
SIGDIR="${KLACK_DIR:-$(pwd)}/.klack/signale/<ticket-id>"
# Read current step, reset status to pending
python3 -c "
import json
from datetime import datetime, timezone
d = json.load(open('$SIGDIR/status.json'))
d['status'] = 'pending'
d['log'] = 'Retrying from step: ' + d['step']
d['updated_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d, open('$SIGDIR/status.json', 'w'), indent=2)
"
> "$SIGDIR/error.log"

# Kill and restart
tmux kill-window -t "der-klack:<ticket-id>" 2>/dev/null || true
tmux new-window -t der-klack -n "<ticket-id>" -c "$(pwd)" \
  "KLACK_ROOT='$(pwd)' bash .klack/scripts/ticket-run.sh '<ticket-id>' 'feat'; exec bash"
```
Confirm: "Retrying <ticket-id>"

### abort <ticket-id>
Stop a ticket and mark it as error.
```bash
tmux kill-window -t "der-klack:<ticket-id>" 2>/dev/null || true
SIGDIR="${KLACK_DIR:-$(pwd)}/.klack/signale/<ticket-id>"
python3 -c "
import json
from datetime import datetime, timezone
d = json.load(open('$SIGDIR/status.json'))
d['status'] = 'error'
d['log'] = 'Aborted by developer'
d['updated_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d, open('$SIGDIR/status.json', 'w'), indent=2)
"
```
Confirm: "Aborted <ticket-id>"

### theme <name>
Switch color scheme. Options: unicorn, cylon, kitt, shufflepuck, monochrome.
```bash
echo "<name>" > "${KLACK_DIR:-$(pwd)}/.klack/active_theme"
# Signal all pane scripts to reload
tmux list-panes -t der-klack:hauptturm -F '#{pane_pid}' | while read pid; do
  kill -USR1 "$pid" 2>/dev/null || true
done
```
Confirm: "Theme switched to <name>"

## Important
- Execute the bash commands directly, don't just show them
- Use KLACK_ROOT or current working directory to find .klack/
- Log actions to .klack/activity.log: `echo "$(date +%H:%M:%S)  [KLACK]  <message>" >> .klack/activity.log`
