#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

mkdir -p "$HOME/.claude/commands"
cp -f "$CLAUDE_PROJECT_DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
cp -f "$CLAUDE_PROJECT_DIR/commands/"*.md "$HOME/.claude/commands/"
