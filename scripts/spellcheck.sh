#!/usr/bin/env bash
#
# Bilingual spellcheck for the CV.
#
# The CV mixes Spanish prose with English tech terms, so a single dictionary
# produces endless false positives. Instead: a word is considered OK if EITHER
# the Spanish OR the English aspell dictionary knows it. Only words unknown to
# BOTH dictionaries are treated as candidate typos.
#
# Real names / brands / acronyms that legitimately fail both dictionaries live
# in the allow-list (.github/spell-allow.txt, one lowercase word per line).
#
# Usage: scripts/spellcheck.sh [cv.tex] [.github/spell-allow.txt]
# Exit 0 = clean, exit 1 = unknown words remain.
set -euo pipefail

TEX="${1:-cv.tex}"
ALLOW="${2:-.github/spell-allow.txt}"

# Only check the document body; the LaTeX preamble is config, not prose.
body="$(sed -n '/\\begin{document}/,$p' "$TEX")"
[ -n "$body" ] || body="$(cat "$TEX")"

# Words unknown to each dictionary (aspell strips LaTeX markup in --mode=tex).
es_bad="$(printf '%s' "$body" | aspell --mode=tex --lang=es --encoding=utf-8 list | sort -u)"
en_bad="$(printf '%s' "$body" | aspell --mode=tex --lang=en --encoding=utf-8 list | sort -u)"

# Unknown to BOTH dictionaries -> candidate typos.
both="$(comm -12 <(printf '%s\n' "$es_bad") <(printf '%s\n' "$en_bad"))"

# Strip comments/blank lines from the allow-list.
allow=""
[ -f "$ALLOW" ] && allow="$(grep -vE '^[[:space:]]*(#|$)' "$ALLOW" || true)"

# Subtract the allow-list (case-insensitive).
remaining="$(comm -23 \
  <(printf '%s\n' "$both"  | tr '[:upper:]' '[:lower:]' | sort -u | grep -v '^$') \
  <(printf '%s\n' "$allow" | tr '[:upper:]' '[:lower:]' | sort -u | grep -v '^$') \
  || true)"

if [ -n "$remaining" ]; then
  echo "Spellcheck: words unknown to BOTH Spanish and English dictionaries:"
  printf '  %s\n' $remaining
  echo
  echo "Fix the typo, or — if it is a real name/term — add it (lowercase) to $ALLOW."
  exit 1
fi

echo "Spellcheck clean: every word is known to Spanish or English (or allow-listed)."
