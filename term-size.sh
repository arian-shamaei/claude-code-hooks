#!/bin/bash
# UserPromptSubmit hook: inject the live terminal pane size into context.
# Walks the process ancestry to the Claude Code process to find its tty,
# then matches that tty against tmux panes for the exact pane size.
# Outside tmux, falls back to stty on the same tty. Silent when unknown.

pid=$$ tty=""
while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
  tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  case "$tty" in
    ttys*|pts/*) break ;;
    *) tty="" ;;
  esac
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done

[ -z "$tty" ] && exit 0

size=""
if command -v tmux >/dev/null 2>&1; then
  size=$(tmux list-panes -a -F '#{pane_tty} #{pane_width} #{pane_height}' 2>/dev/null \
    | awk -v t="/dev/$tty" '$1 == t { print $2 "x" $3; exit }')
fi
if [ -z "$size" ]; then
  size=$(stty size < "/dev/$tty" 2>/dev/null | awk '{ print $2 "x" $1 }')
fi

[ -z "$size" ] && exit 0

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"[terminal pane: %s cols x rows -- size display math, tables, and code blocks to fit this width]"}}\n' "$size"
