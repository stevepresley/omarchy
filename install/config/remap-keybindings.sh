#!/bin/bash

# Remap Hyprland keybindings to avoid host Super-key interception in VM mode
# When the advanced installer state requests key remapping, duplicate "Super"
# bindings onto CTRL+ALT (and adjust screen-record shortcut).

set -euo pipefail

# Helper to convert truthy strings to lowercase "true"/"false"
normalize_bool() {
  local value="${1:-}"
  value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
  case "$value" in
    1|y|yes|true|enable|enabled) echo "true" ;;
    *) echo "false" ;;
  esac
}

state_file="${OMARCHY_ADVANCED_STATE:-}"

if [[ -z "$state_file" || ! -f "$state_file" ]]; then
  echo "Keybinding remap disabled (no advanced state file available)."
  exit 0
fi

remap_choice=$(jq -r '(.remap_keybindings // .remapKeys // .remap_keys // empty)' "$state_file")
remap_flag=$(normalize_bool "$remap_choice")

if [[ "$remap_flag" != "true" ]]; then
  echo "Keybinding remap disabled (RemapKeys option not selected)."
  exit 0
fi

echo "Remapping Hyprland keybindings for VM mode (Super → CTRL+ALT)."

# Ensure Python is available; jq already required elsewhere
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for keybinding remap but was not found." >&2
  exit 1
fi

shopt -s nullglob

config_files=()
if [[ -f "$HOME/.config/hypr/bindings.conf" ]]; then
  config_files+=("$HOME/.config/hypr/bindings.conf")
fi
for file in "$HOME/.config/hypr/bindings/"*.conf; do
  config_files+=("$file")
done

if [[ ${#config_files[@]} -eq 0 ]]; then
  echo "No Hyprland binding files found under ~/.config/hypr; skipping remap."
  exit 0
fi

python3 - "$state_file" "${config_files[@]}" <<'PYCODE'
import pathlib
import re
import sys

state_path = pathlib.Path(sys.argv[1])
binding_paths = [pathlib.Path(p) for p in sys.argv[2:]]

pattern_super = re.compile(r'^(bind\w*\s*=\s*)SUPER(\s*,)', re.IGNORECASE)
pattern_ctrl_alt_print = re.compile(r'^(bind\w*\s*=\s*)CTRL\s+ALT(\s*,\s*PRINT\b)', re.IGNORECASE)

for path in binding_paths:
    if not path.exists():
        continue

    original = path.read_text()
    lines = original.splitlines()
    changed = False
    output_lines = []

    for line in lines:
        new_line = pattern_super.sub(r'\1CTRL ALT\2', line)
        if new_line != line:
            changed = True

        new_line2 = pattern_ctrl_alt_print.sub(r'\1SUPER ALT\2', new_line)
        if new_line2 != new_line:
            changed = True
        output_lines.append(new_line2)

    if changed:
        trailing_newline = original.endswith("\n")
        path.write_text("\n".join(output_lines) + ("\n" if trailing_newline else ""))
        print(f"  Updated {path}")
    else:
        print(f"  No changes needed for {path}")
PYCODE

echo "✓ Hyprland keybindings remapped to CTRL+ALT variants."
