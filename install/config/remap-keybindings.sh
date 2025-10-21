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

# User-specific Hypr config overrides
if [[ -f "$HOME/.config/hypr/bindings.conf" ]]; then
  config_files+=("$HOME/.config/hypr/bindings.conf")
fi
for file in "$HOME/.config/hypr/bindings/"*.conf; do
  config_files+=("$file")
done

# Omarchy default Hypr bindings (sourced by hyprland.conf before user overrides)
DEFAULT_HYPR_DIR="$HOME/.local/share/omarchy/default/hypr"
if [[ -f "$DEFAULT_HYPR_DIR/bindings.conf" ]]; then
  config_files+=("$DEFAULT_HYPR_DIR/bindings.conf")
fi
for file in "$DEFAULT_HYPR_DIR/bindings/"*.conf; do
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

pattern_bind = re.compile(r'^(bind\w*\s*=\s*)([^,]+)(,.*)$', re.IGNORECASE)
pattern_ctrl_alt_print = re.compile(r'^(bind\w*\s*=\s*)CTRL\s+ALT(\s*,\s*PRINT\b)', re.IGNORECASE)
for path in binding_paths:
    if not path.exists():
        continue

    original = path.read_text()
    lines = original.splitlines()
    changed = False
    output_lines = []

    for line in lines:
        updated_line = line

        match = pattern_bind.match(updated_line.strip())
        if match:
            prefix, modifiers, suffix = match.groups()
            tokens = [tok for tok in modifiers.strip().split() if tok]
            tokens_upper = [tok.upper() for tok in tokens]

            if "SUPER" in tokens_upper:
                normalized_tokens = []
                for tok in tokens:
                    upper_tok = tok.upper()
                    if upper_tok == "SUPER":
                        normalized_tokens.extend(["CTRL", "ALT"])
                    else:
                        normalized_tokens.append(upper_tok)

                # Remove duplicates while preserving order
                deduped_tokens = []
                seen = set()
                for tok in normalized_tokens:
                    if tok not in seen:
                        deduped_tokens.append(tok)
                        seen.add(tok)

                new_modifiers = " ".join(deduped_tokens)
                updated_line = f"{prefix}{new_modifiers}{suffix}"
                if updated_line != line:
                    changed = True

        # Adjust screen-record shortcut to SUPER+ALT+Print
        new_line = pattern_ctrl_alt_print.sub(r'\1SUPER ALT\2', updated_line)
        if new_line != updated_line:
            changed = True
            updated_line = new_line

        output_lines.append(updated_line)

    if changed:
        trailing_newline = original.endswith("\n")
        path.write_text("\n".join(output_lines) + ("\n" if trailing_newline else ""))
        print(f"  Updated {path}")
    else:
        print(f"  No changes needed for {path}")
PYCODE

echo "✓ Hyprland keybindings remapped to CTRL+ALT variants."
