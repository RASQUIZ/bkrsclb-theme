#!/usr/bin/env bash
#
# snapshot.sh — mirror the LIVE bkrsclb.com theme into this repo, commit, tag, push.
#
# Why this exists
# ---------------
# This repo is only useful if it matches what is actually serving bkrsclb.com.
# Its whole job is to let a person (or a tool) verify CSS selectors against real
# emitted markup instead of guessing from assets/base.css. A stale repo is worse
# than no repo: it looks authoritative and is wrong. In Aug 2026 a stale read of
# this repo produced an enhancement pack where ~10 selectors matched nothing and
# 3 actively broke the store. Run this after ANY theme change — CLI push, theme
# editor edit, app install, or publish.
#
# Usage
#   ./snapshot.sh                 # snapshot live theme, commit, tag, push
#   ./snapshot.sh --dry-run       # show what would change, touch nothing
#   ./snapshot.sh --no-push       # commit + tag locally, don't push
#   ./snapshot.sh --theme 12345   # snapshot a specific theme id instead of live
#
# Env
#   BKRS_STORE   default bkrsclb-store.myshopify.com
#
# Requires: shopify CLI (authenticated), git, rsync, python3.

set -euo pipefail

STORE="${BKRS_STORE:-bkrsclb-store.myshopify.com}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
PUSH=1
THEME_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-push) PUSH=0 ;;
    --theme)   THEME_ID="${2:-}"; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

cd "$REPO"

# ---------------------------------------------------------------- preconditions
git rev-parse --git-dir >/dev/null 2>&1 || die "$REPO is not a git repository"
command -v shopify >/dev/null || die "shopify CLI not found on PATH"
command -v rsync   >/dev/null || die "rsync not found"
command -v python3 >/dev/null || die "python3 not found"

if [ -n "$(git status --porcelain)" ]; then
  die "working tree is dirty. Commit or stash first — this script overwrites theme files."
fi

# ------------------------------------------------------------- find live theme
say "Querying $STORE for the live theme…"
LIST_JSON="$(shopify theme list --store "$STORE" --json)" \
  || die "could not list themes. Try: shopify theme list --store $STORE"

read -r RESOLVED_ID THEME_NAME <<EOF
$(printf '%s' "$LIST_JSON" | python3 -c '
import json, sys
want = sys.argv[1] if len(sys.argv) > 1 else ""
themes = json.load(sys.stdin)
if want:
    t = next((x for x in themes if str(x["id"]) == want), None)
    if not t: sys.exit("theme id %s not found on this store" % want)
else:
    t = next((x for x in themes if x.get("role") == "live"), None)
    if not t: sys.exit("no theme is marked live on this store")
print(t["id"], t["name"])
' "$THEME_ID")
EOF

[ -n "${RESOLVED_ID:-}" ] || die "could not resolve a theme id"
say "Theme: $THEME_NAME  (#$RESOLVED_ID)"

# ------------------------------------------------------------------- pull it
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
say "Pulling theme into a scratch dir…"
shopify theme pull --store "$STORE" --theme "$RESOLVED_ID" --path "$TMP" >/dev/null 2>&1 \
  || die "theme pull failed"

# Guard against a partial/empty pull wiping the repo. If these are missing the
# pull did not produce a real theme and rsync --delete would be destructive.
[ -f "$TMP/layout/theme.liquid" ] || die "pull looks incomplete (no layout/theme.liquid) — aborting before rsync"
LIQ_COUNT="$(find "$TMP" -name '*.liquid' | wc -l | tr -d ' ')"
[ "$LIQ_COUNT" -ge 50 ] || die "pull returned only $LIQ_COUNT .liquid files — aborting as a safety check"
say "Pulled $LIQ_COUNT .liquid files."

# --------------------------------------------------------------- sync to repo
# --delete so files removed in Shopify are removed here too. The excludes are
# repo-owned files that must survive: git metadata, our docs, this script.
RSYNC_ARGS=(-a --delete
  --exclude '.git/' --exclude '.gitignore' --exclude 'README.md'
  --exclude 'snapshot.sh' --exclude '.DS_Store')

if [ "$DRY_RUN" -eq 1 ]; then
  say "DRY RUN — changes that would be applied:"
  # rsync itemises time-only changes as ..t; git does not track mtime, so
  # those are noise. Show real content changes, additions and deletions only.
  rsync "${RSYNC_ARGS[@]}" --dry-run --itemize-changes "$TMP"/ "$REPO"/ \
    | grep -vE '^[<>.]f\\.\\.t' \
    | grep -vE '^\.d' | head -60
  echo
  say "DRY RUN — no files written, nothing committed."
  exit 0
fi

rsync "${RSYNC_ARGS[@]}" "$TMP"/ "$REPO"/

# ------------------------------------------------------------ anything to do?
if [ -z "$(git status --porcelain)" ]; then
  say "Repo already matches the live theme. Nothing to commit."
  exit 0
fi

git add -A
CHANGED="$(git diff --cached --numstat | wc -l | tr -d ' ')"
say "$CHANGED file(s) changed."

# ------------------------------------------------------------- secret scan
# This repo is on GitHub. A theme export carries config/settings_data.json and
# any app-injected snippets, so scan before every push rather than trusting it.
say "Scanning staged diff for credentials…"
if git diff --cached | grep -nEi \
    'shpat_|shpca_|shppa_|shpss_|sk_live_|pk_live_|AIza[0-9A-Za-z_-]{20}|-----BEGIN [A-Z ]*PRIVATE KEY|(api[_-]?key|access[_-]?token|client[_-]?secret|password)["'"'"']?\s*[:=]\s*["'"'"'][^"'"'"']{12,}' \
    >/tmp/bkrs_secret_hits 2>/dev/null; then
  echo
  printf '\033[31mPossible credentials in the diff — NOT committing:\033[0m\n'
  head -12 /tmp/bkrs_secret_hits
  rm -f /tmp/bkrs_secret_hits
  git reset >/dev/null
  die "review the findings above. Files are updated on disk but nothing was staged."
fi
rm -f /tmp/bkrs_secret_hits
say "Clean."

# ---------------------------------------------------------------- commit
STAMP="$(date +%Y-%m-%d)"
SLUG="$(printf '%s' "$THEME_NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' \
  | cut -c1-40)"

NEW_FILES="$(git diff --cached --name-status | grep -c '^A' || true)"
DEL_FILES="$(git diff --cached --name-status | grep -c '^D' || true)"
MOD_FILES="$(git diff --cached --name-status | grep -c '^M' || true)"

MSG_FILE="$(mktemp)"
{
  printf 'Snapshot: %s (%s)\n\n' "$THEME_NAME" "$STAMP"
  printf 'Live theme #%s on %s, pulled with shopify theme pull.\n' "$RESOLVED_ID" "$STORE"
  printf '%s modified, %s added, %s removed.\n\n' "$MOD_FILES" "$NEW_FILES" "$DEL_FILES"
  if [ "$NEW_FILES" -gt 0 ]; then
    printf 'Added:\n'
    git diff --cached --name-status | awk '$1=="A"{print "  " $2}' | head -25
    printf '\n'
  fi
  if [ "$DEL_FILES" -gt 0 ]; then
    printf 'Removed:\n'
    git diff --cached --name-status | awk '$1=="D"{print "  " $2}' | head -25
    printf '\n'
  fi
  printf 'Diff scanned for credentials before commit; none found.\n\n'
  printf 'Generated by snapshot.sh\n'
} > "$MSG_FILE"

git commit -q -F "$MSG_FILE"
rm -f "$MSG_FILE"
COMMIT="$(git rev-parse --short HEAD)"
say "Committed $COMMIT"

# ------------------------------------------------------------------- tag
TAG="live-${SLUG}-$(date +%Y%m%d)"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  n=2
  while git rev-parse -q --verify "refs/tags/${TAG}-${n}" >/dev/null; do n=$((n+1)); done
  TAG="${TAG}-${n}"
fi
git tag -a "$TAG" -m "Live theme snapshot: $THEME_NAME (#$RESOLVED_ID), $STAMP"
say "Tagged $TAG"

# ------------------------------------------------------------------ push
if [ "$PUSH" -eq 1 ]; then
  say "Pushing…"
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  git push -q origin "$BRANCH" --follow-tags || die "push failed — commit and tag exist locally"
  say "Pushed $BRANCH and $TAG to origin."
else
  say "Skipped push (--no-push). Run: git push origin HEAD --follow-tags"
fi

echo
say "Done. $THEME_NAME is mirrored at $COMMIT / $TAG"
