#!/usr/bin/env bash
# Every Markdown document must have an English and a Chinese version.
# Chinese documents use the `.zh.md` suffix.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

status=0

while IFS= read -r file; do
  case "$file" in
    ./lib/*|./out/*|./cache/*|./node_modules/*|./.venv/*|./.git/*|./.github/*) continue ;;
    *.zh.md) continue ;;
    LICENSE|LICENSE.md) continue ;;
  esac

  zh="${file%.md}.zh.md"
  if [[ ! -f "$zh" ]]; then
    printf 'missing Chinese translation: %s (expected %s)\n' "$file" "$zh"
    status=1
  fi
done < <(find . -name '*.md' -not -path './.git/*' | sort)

while IFS= read -r file; do
  base="${file%.zh.md}.md"
  if [[ ! -f "$base" ]]; then
    printf 'missing English source: %s (expected %s)\n' "$file" "$base"
    status=1
  fi
done < <(find . -name '*.zh.md' -not -path './.git/*' | sort)

if (( status )); then
  echo 'documentation language check failed'
  exit 1
fi

echo 'documentation language check passed'
