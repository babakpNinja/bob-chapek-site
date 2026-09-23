# Site versions

Frozen reference builds of the page. `versions/<id>/index.html` is a copy of
the live page at the moment it shipped; it references the shared `/assets/`, so
no image or video is duplicated here. Older versions stay in the store for
comparison and never age out.

| Version | What it was | Date | Commit |
| --- | --- | --- | --- |
| 1.0 | Book site: cover, buy row, 7 cuts, career record, passcode gate | 2026-09-23 | `a1f26f1d` |

## Switching back

The footer **Version** toggle lists every version; clicking one opens that
snapshot (behind the passcode gate, like the rest of the site). The active
version is marked. To go back to a version the served page changes to that
snapshot (a fresh deploy); versions made later stay in the store, so you can
compare or return forward again.

So "go back to version 5" means: restore `versions/5/index.html` as the served
`index.html` and deploy. It is a page reference and comparison system, not a
rollback of data or of the deploy history.

## Making a new version

When a major structural or feature change ships:

    python tools/make_version.py 1.1 "short description"

Run it from the repository root. It snapshots the current `index.html`,
appends to `versions.json`, rewrites this file, and (with `--deploy`) pushes
the result. Bump the version whenever the page changes shape, not for copy edits.
