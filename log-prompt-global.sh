#!/usr/bin/env bash
# Global UserPromptSubmit hook: append every user prompt, from every Claude Code
# session on this machine, to ~/.claude/logs/prompts/YYYY-MM-DD.md.
# Adapted from the CSE490 project logger (.claude/hooks/log-prompt.sh) — same
# proofread-then-log pipeline, but machine-global and manifest-free.
#
# Incognito protocol (per session):
#   - Prompt "/incognito"      -> create sentinel ~/.claude/incognito/<session_id>,
#                                 skip logging from now on for that session.
#   - Prompt "/incognito off"  -> remove the sentinel, resume logging.
#   - Sentinel present         -> log nothing, exit 0.
# Sentinels older than 7 days are garbage-collected on each run.
#
# Prompts are proofread through the on-device Apple Intelligence model
# (~/.claude/hooks/proofread/proofread) before logging; raw text is kept when
# the proofreader is absent, fails, or times out.
# Fails LOUD (stderr + nonzero exit) on write error, but never blocks the prompt.
set -euo pipefail

PROOFREADER="$HOME/.claude/hooks/proofread/proofread"
LOGS_DIR="$HOME/.claude/logs/prompts"
INCOG_DIR="$HOME/.claude/incognito"

input="$(cat)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // ""')"
session="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // ""')"

mkdir -p "$INCOG_DIR"
find "$INCOG_DIR" -type f -mtime +7 -delete 2>/dev/null || true
sentinel="$INCOG_DIR/$session"

# Toggle handling — the /incognito skill only confirms; this is what acts.
trimmed="$(printf '%s' "$prompt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
case "$trimmed" in
  /incognito|/incognito\ on)
    touch "$sentinel"
    exit 0
    ;;
  /incognito\ off)
    rm -f "$sentinel"
    exit 0
    ;;
esac

# Incognito session: log nothing.
[ -f "$sentinel" ] && exit 0

# Nothing to log.
[ -z "$prompt" ] && exit 0

if [ -x "$PROOFREADER" ] && [ "${prompt:0:1}" != "/" ]; then
  corrected="$(printf '%s' "$prompt" | "$PROOFREADER" 2>/dev/null)" || corrected=""
  [ -n "$corrected" ] && prompt="$corrected"
fi

if ! mkdir -p "$LOGS_DIR" 2>/dev/null; then
  echo "[log-prompt-global] FAILED: cannot create $LOGS_DIR" >&2
  exit 1
fi

ts="$(date '+%Y-%m-%d %H:%M:%S')"
day="$(date '+%Y-%m-%d')"
file="$LOGS_DIR/$day.md"

if [ ! -f "$file" ]; then
  printf '# Prompt log — %s\n\n' "$day" > "$file"
fi

{
  printf -- '- **%s** _(session %s)_ `%s`\n' "$ts" "${session:0:8}" "${cwd/#$HOME/~}"
  printf '%s\n' "$prompt" | sed 's/^/  > /'
  printf '\n'
} >> "$file" || { echo "[log-prompt-global] FAILED: cannot write $file" >&2; exit 1; }

exit 0
