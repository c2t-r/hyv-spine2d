#!/usr/bin/env bash
set -euo pipefail

git rev-parse --is-inside-work-tree >/dev/null

if ! git diff --cached --quiet; then
  echo "Error: staged changes already exist. Please commit or unstage them first."
  exit 1
fi

git status --porcelain=v1 --untracked-files=all |
  awk '$1 == "??" { sub(/^\?\? /, ""); print }' |
  while IFS= read -r path; do
    [[ "$path" == */*/* ]] || continue

    parent="${path%%/*}"
    rest="${path#*/}"
    child="${rest%%/*}"

    [[ -d "$parent/$child" ]] || continue

    printf '%s\t%s\n' "$parent" "$child"
  done |
  sort -u |
  while IFS=$'\t' read -r parent child; do
    target="$parent/$child"
    message="[$parent] $child"

    echo "Committing $target -> $message"

    git add -- "$target"

    if git diff --cached --quiet -- "$target"; then
      git reset -- "$target" >/dev/null
      continue
    fi

    git commit -m "$message" -- "$target"

    if ! git diff --cached --quiet; then
      echo "Error: staged changes remain after committing $target."
      exit 1
    fi
  done