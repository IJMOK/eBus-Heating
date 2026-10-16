#!/usr/bin/env bash
# Scan what is about to be pushed for secrets, IPs and personal data.
#
#   tools/scan-secrets.sh                 # commits not yet on origin/main + uncommitted changes
#   tools/scan-secrets.sh <range>         # e.g. HEAD~3..HEAD
#   tools/scan-secrets.sh --all           # every tracked file
#
# Optional denylist: set SCAN_DENYLIST to a file with one literal string per line
# (real entity IDs, SSIDs, names, postcode...). Keep that file out of this repo.
# Exit code 1 if anything is found.

set -u
cd "$(git rev-parse --show-toplevel)" || exit 2

if [ "${1:-}" = "--all" ]; then
  text=$(git ls-files -z | xargs -0 grep -nH "" 2>/dev/null)
else
  range=${1:-}
  if [ -z "$range" ]; then
    git rev-parse -q --verify origin/main >/dev/null && range="origin/main" || range="$(git hash-object -t tree /dev/null)"
  fi
  # Only added lines, prefixed with their file name
  text=$( { git diff "$range" --unified=0 --no-color; git diff --cached --unified=0 --no-color; } |
    awk '/^\+\+\+ b\//{f=substr($0,7);next} /^\+/ && !/^\+\+\+/{print f": "substr($0,2)}')
  # Plus author/committer emails of the commits being pushed
  text=$(printf '%s\n%s' "$text" "$(git log --format='commit %h: %ae %ce' "$range..HEAD" 2>/dev/null | sed 's/[^ ]*@users\.noreply\.github\.com//g; s/noreply@github\.com//g')")
  # Plus new files not yet added
  untracked=$(git ls-files -z --others --exclude-standard | xargs -0 -r grep -nH "" 2>/dev/null)
  text=$(printf '%s\n%s' "$text" "$untracked")
fi

found=0
check() { # label, extended regex, [exclude regex]
  local hits
  hits=$(printf '%s\n' "$text" | grep -E -- "$2" | { [ -n "${3:-}" ] && grep -Ev -- "$3" || cat; })
  if [ -n "$hits" ]; then
    found=1
    printf '\n## %s\n%s\n' "$1" "$hits"
  fi
}

check "IPv4 address" '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' '\b(127\.0\.0\.1|0\.0\.0\.0|192\.0\.2\.[0-9]{1,3}|192\.168\.4\.1)\b'
check "MAC address" '\b([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b'
check "Email address" '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' 'noreply@anthropic\.com|@example\.(com|org)'
check "JWT / HA long-lived token" 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
check "Long hex string (key?)" '\b[0-9A-Fa-f]{32,}\b'
check "Password / key / token value" '(password|passwd|secret|token|api_?key|bindkey|bthome_?key)["'"'"' ]*[:=] *["'"'"']?[^ "'"'"'<{!$]{4,}' '<[A-Z_]+>|!secret'
check "Latitude / longitude" '(latitude|longitude|lat|lon)["'"'"' ]*[:=] *-?[0-9]+\.[0-9]{3,}'
check "UK postcode" '\b[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}\b'

if [ -n "${SCAN_DENYLIST:-}" ] && [ -f "$SCAN_DENYLIST" ]; then
  while IFS= read -r term; do
    case "$term" in ''|\#*) continue ;; esac
    check "Denylisted: $term" "$(printf '%s' "$term" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"
  done < "$SCAN_DENYLIST"
fi

if [ $found -eq 0 ]; then echo "scan-secrets: clean"; else echo; echo "scan-secrets: REVIEW THE HITS ABOVE"; fi
exit $found
