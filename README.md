# bkrsclb-theme

Shopify theme source for **bkrsclb.com** (BKRSCLB store).

A series of snapshots of the live theme, pulled from Shopify admin. Not a
live-synced copy and not a deployment pipeline — the live theme lives in
Shopify. This repo exists so that selectors can be verified against the
markup the store actually emits, instead of guessed from `assets/base.css`.

**A stale snapshot is worse than none.** It looks authoritative and is wrong.
In Aug 2026 a stale read of this repo produced an enhancement pack in which
~10 selectors matched nothing and 3 actively broke the store.

## Keeping it current

```sh
./snapshot.sh              # pull the live theme, commit, tag, push
./snapshot.sh --dry-run    # show what changed, touch nothing
./snapshot.sh --no-push    # commit and tag locally
./snapshot.sh --theme ID   # snapshot a specific theme instead of live
```

Run it after **any** theme change: a `shopify theme push`, an edit in the
theme editor, publishing a different theme, or installing an app.

It resolves the live theme itself (`shopify theme list --json`), so there is
no theme id to maintain. It is idempotent — if the repo already matches, it
says so and exits without committing, which makes it safe on a schedule.

Safety rails, in order: refuses a dirty worktree; aborts if the pull returns
no `layout/theme.liquid` or fewer than 50 `.liquid` files (so a partial pull
can never `rsync --delete` the repo); scans the staged diff for Shopify,
Stripe and Google keys before committing.

Requires the Shopify CLI (authenticated), `git`, `rsync` and `python3`.

## Snapshots

Every run tags `live-<theme-slug>-<date>`, so any past state stays diffable.

| Tag | Date | Shopify theme |
| --- | --- | --- |
| `live-fabric-15aug2026` (`2b01d1c`) | 2026-08-15 | Fabric — Android Download Banner |
| `live-bakery-bar-band-bkrsclb-enhance-v2-20260824` | 2026-08-24 | BAKERY bar + band + BKRSCLB enhance v2 |

```sh
git tag -l 'live-*'                                   # every snapshot
git diff live-fabric-15aug2026..main -- sections/ templates/ assets/
```

## Reading this repo correctly

`base.css` carries orphan rules for classes **no Liquid file emits** —
`.drawer__title`, `.drawer-toggle` and `.drawer__close` are all confirmed
dead here. Before relying on any selector:

```sh
grep -rl --include='*.liquid' 'your-class-name' .     # 0 files = dead
```

Also check whether the value is written as an inline custom property in
Liquid (Horizon does this constantly, e.g. `--gallery-aspect-ratio` in
`snippets/card-gallery.liquid`). An inline declaration beats any external
stylesheet regardless of specificity.

And mind load order: Horizon ships most component CSS in per-block
`{% stylesheet %}` tags that Shopify injects through `{{ content_for_header }}`.
A stylesheet linked before that point loses every equal-specificity tie.

## Note on `.gitignore`

Three lines, 30 bytes: `.DS_Store`, `node_modules/`, `*.log`. It has never
excluded `*.liquid`, and 300+ Liquid files have been tracked since the first
commit. If a tool claims this repo "has no Liquid files", that is a bad read
of the repo — check `git ls-files '*.liquid' | wc -l` before changing anything.
