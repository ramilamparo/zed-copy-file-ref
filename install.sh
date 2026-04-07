#!/bin/bash
set -euo pipefail

ZED_CONFIG="${HOME}/.config/zed"
SCRIPTS_DIR="${ZED_CONFIG}/scripts"
TASKS_FILE="${ZED_CONFIG}/tasks.json"
KEYMAP_FILE="${ZED_CONFIG}/keymap.json"

TASK_LABEL="Copy File Reference"
KEYBINDING="ctrl-alt-r"

# --- Colors ---
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }

# --- Dependency check ---
if ! command -v jq &>/dev/null; then
  red "Error: jq is required but not installed."
  echo "Install it with: sudo apt install jq  (or brew install jq on macOS)"
  exit 1
fi

# --- Clipboard tool detection ---
if command -v wl-copy &>/dev/null; then
  CLIP_CMD="wl-copy"
elif command -v pbcopy &>/dev/null; then
  CLIP_CMD="pbcopy"
elif command -v xclip &>/dev/null; then
  CLIP_CMD="xclip -selection clipboard"
elif command -v xsel &>/dev/null; then
  CLIP_CMD="xsel --clipboard --input"
else
  red "Error: No clipboard tool found (wl-copy, pbcopy, xclip, or xsel)."
  exit 1
fi

green "Using clipboard command: ${CLIP_CMD}"

# --- Helper: strip JSONC comments so jq can parse Zed config files ---
strip_jsonc() {
  sed 's|//.*$||' "$1" | jq '.'
}

# --- Create script ---
mkdir -p "${SCRIPTS_DIR}"

cat > "${SCRIPTS_DIR}/copy-file-ref.sh" << 'SCRIPT'
#!/bin/bash
# Copy file reference in @project/path#L20-25 format to clipboard

PROJECT=$(basename "$ZED_WORKTREE_ROOT")
REL_PATH="$ZED_RELATIVE_FILE"
ROW=$ZED_ROW

if [ -n "$ZED_SELECTED_TEXT" ]; then
  # Count lines using awk (handles trailing newlines from visual line mode)
  LINE_COUNT=$(printf '%s' "$ZED_SELECTED_TEXT" | awk 'END{print NR}')

  if [ "$LINE_COUNT" -gt 1 ]; then
    START=$ROW
    END=$((ROW + LINE_COUNT - 1))
    REF="@${PROJECT}/${REL_PATH}#L${START}-${END}"
  else
    REF="@${PROJECT}/${REL_PATH}#L${ROW}"
  fi
else
  REF="@${PROJECT}/${REL_PATH}#L${ROW}"
fi

printf '%s' "$REF" | __CLIP_CMD__
SCRIPT

# Inject the detected clipboard command (portable sed -i for macOS and Linux)
if [[ "$OSTYPE" == darwin* ]]; then
  sed -i '' "s|__CLIP_CMD__|${CLIP_CMD}|g" "${SCRIPTS_DIR}/copy-file-ref.sh"
else
  sed -i "s|__CLIP_CMD__|${CLIP_CMD}|g" "${SCRIPTS_DIR}/copy-file-ref.sh"
fi
chmod +x "${SCRIPTS_DIR}/copy-file-ref.sh"
green "Created ${SCRIPTS_DIR}/copy-file-ref.sh"

# --- Merge into tasks.json ---
NEW_TASK=$(cat << 'JSON'
{
  "label": "Copy File Reference",
  "command": "bash ~/.config/zed/scripts/copy-file-ref.sh",
  "use_new_terminal": false,
  "allow_concurrent_runs": false,
  "reveal": "never",
  "hide": "always"
}
JSON
)

if [ -f "${TASKS_FILE}" ]; then
  TASKS_CLEAN=$(strip_jsonc "${TASKS_FILE}")
  # Check if task already exists
  if echo "${TASKS_CLEAN}" | jq -e --arg label "${TASK_LABEL}" 'map(.label) | index($label)' &>/dev/null; then
    # Update existing task
    echo "${TASKS_CLEAN}" | jq --argjson task "${NEW_TASK}" --arg label "${TASK_LABEL}" \
      'map(if .label == $label then $task else . end)' > "${TASKS_FILE}.tmp"
    mv "${TASKS_FILE}.tmp" "${TASKS_FILE}"
    yellow "Updated existing task in ${TASKS_FILE}"
  else
    # Append to existing array
    echo "${TASKS_CLEAN}" | jq --argjson task "${NEW_TASK}" '. + [$task]' > "${TASKS_FILE}.tmp"
    mv "${TASKS_FILE}.tmp" "${TASKS_FILE}"
    green "Added task to ${TASKS_FILE}"
  fi
else
  echo "[${NEW_TASK}]" | jq '.' > "${TASKS_FILE}"
  green "Created ${TASKS_FILE}"
fi

# --- Merge into keymap.json ---
NEW_BINDING=$(cat << JSON
{
  "context": "Editor",
  "bindings": {
    "${KEYBINDING}": ["task::Spawn", { "task_name": "${TASK_LABEL}" }]
  }
}
JSON
)

if [ -f "${KEYMAP_FILE}" ]; then
  KEYMAP_CLEAN=$(strip_jsonc "${KEYMAP_FILE}")
  # Check if our binding already exists in an Editor context block
  if echo "${KEYMAP_CLEAN}" | jq -e --arg key "${KEYBINDING}" \
    '[.[] | select(.context == "Editor") | .bindings[$key]] | any' &>/dev/null; then
    # Update the binding in the existing Editor block
    echo "${KEYMAP_CLEAN}" | jq --arg key "${KEYBINDING}" --arg label "${TASK_LABEL}" \
      'map(if .context == "Editor" then .bindings[$key] = ["task::Spawn", { "task_name": $label }] else . end)' \
      > "${KEYMAP_FILE}.tmp"
    mv "${KEYMAP_FILE}.tmp" "${KEYMAP_FILE}"
    yellow "Updated existing keybinding in ${KEYMAP_FILE}"
  else
    # Append new context block
    echo "${KEYMAP_CLEAN}" | jq --argjson binding "${NEW_BINDING}" '. + [$binding]' > "${KEYMAP_FILE}.tmp"
    mv "${KEYMAP_FILE}.tmp" "${KEYMAP_FILE}"
    green "Added keybinding to ${KEYMAP_FILE}"
  fi
else
  echo "[${NEW_BINDING}]" | jq '.' > "${KEYMAP_FILE}"
  green "Created ${KEYMAP_FILE}"
fi

echo ""
green "Done! Restart Zed, then press Ctrl+Alt+R to copy a file reference."
echo "Format: @project/path/to/file.ts#L20-25"
