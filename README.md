# bkrsclb-theme

Shopify theme source for **bkrsclb.com** (BKRSCLB store).

This repo is a series of one-time export snapshots downloaded from Shopify admin —
not a live-synced copy and not a deployment pipeline. The live theme lives in
Shopify. This exists to give tools like Claude Design a real source for the
theme's components, styles and structure, so selectors can be verified against
actual markup instead of guessed from `assets/base.css`.

## What each commit tracks

| Ref | Date | Shopify theme |
| --- | --- | --- |
| tag `live-fabric-15aug2026` (`2b01d1c`) | 2026-08-15 | **Fabric — Android Download Banner** (live) |
| `main` | 2026-08-18 | **bakery-bar-band-aug-18-preview** (preview/duplicate) |

`main` currently tracks the **preview** theme, which adds the Bakery band, the
join bar and a subscription template on top of the live theme. To see exactly
what the preview adds:

```sh
git diff live-fabric-15aug2026..main -- sections/ templates/ assets/
```

The live-theme snapshot is preserved at the tag, so nothing was lost by moving
`main` forward.

## Pulling a fresh snapshot

Shopify admin → Online Store → Themes → **…** on the theme → **Download theme
file**. Then, from the repo root:

```sh
rsync -a --delete \
  --exclude='.git/' --exclude='.gitignore' --exclude='README.md' --exclude='.DS_Store' \
  /path/to/theme_export__.../ .
git add -A && git commit
```

Tag the commit with the theme name and export date so the table above stays
useful.

## Note on `.gitignore`

It is `.DS_Store`, `node_modules/`, `*.log` — three lines, 30 bytes. It has never
excluded `*.liquid`, and all 299+ Liquid files have been tracked since the first
commit. If a tool reports that this repo "has no Liquid files," that is a bad
read of the repo, not a `.gitignore` problem — check
`git ls-files '*.liquid' | wc -l` before changing anything.
