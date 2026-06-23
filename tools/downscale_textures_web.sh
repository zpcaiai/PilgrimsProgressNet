#!/usr/bin/env bash
# Downscale large textures (≥1024px) to 512×512 for the Web export.
# This reduces the .pck from ~153 MB to ~50 MB, fitting within Vercel's 100 MB limit.
#
# Usage:
#   tools/downscale_textures_web.sh          # preview (dry-run)
#   tools/downscale_textures_web.sh --apply  # resize in-place
#
# After running with --apply, re-export the Web build in Godot, then deploy.
# To restore originals: git checkout -- assets/textures/ assets/imported_scenes/
#
# Requires: sips (macOS built-in) or ImageMagick (convert)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SIZE=512
APPLY=false
COUNT=0
SAVED=0

[[ "${1:-}" == "--apply" ]] && APPLY=true

echo "=== Downscale textures to ${TARGET_SIZE}×${TARGET_SIZE} for Web export ==="
[[ "$APPLY" == false ]] && echo "(dry-run — pass --apply to resize in-place)"
echo

while IFS= read -r -d '' f; do
  # Get dimensions via sips (macOS)
  w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')
  [[ -z "$w" || -z "$h" ]] && continue
  if (( w >= 1024 || h >= 1024 )); then
    sz=$(stat -f '%z' "$f")
    rel="${f#$ROOT/}"
    printf "  %-60s %4dx%-4d (%s)\n" "$rel" "$w" "$h" "$(numfmt --to=iec $sz 2>/dev/null || echo "${sz}B")"
    COUNT=$((COUNT + 1))
    SAVED=$((SAVED + sz))
    if [[ "$APPLY" == true ]]; then
      sips --resampleHeightWidth "$TARGET_SIZE" "$TARGET_SIZE" "$f" >/dev/null 2>&1
    fi
  fi
done < <(find "$ROOT/assets/textures" -type f -name "*.png" -print0)

echo
echo "Files ≥1024px: $COUNT"
if [[ "$APPLY" == true ]]; then
  echo "✓ All resized to ${TARGET_SIZE}×${TARGET_SIZE}. Now re-export the Web build in Godot."
else
  echo "Estimated savings: ~75% of texture data (run with --apply to resize)."
fi
