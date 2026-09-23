# Behind the Castle Walls site

Static site for Bob Chapek's memoir, served by nginx on Railway (project
`bob-chapek-advisor-site`, service `chapek-site`). Content lives in `index.html`,
`press-kit.html` and `404.html`; the video masters are fetched at build time from
the `media-v1` release and checked against `media.sha256`.

## Unlisted toggle

The site is currently UNLISTED while we await Bob's approval: search engines may
not list it, but anyone with the link can still open and share it. This is
temporary and it is reversible in one place per file. To re-list the site, do
all four of the following:

1. `index.html`: delete the `<meta name="robots" ...>` line that begins
   `noindex, nofollow, noarchive` (marked UNLISTED in the head).
2. `press-kit.html`: change its robots meta back to `index,follow`.
3. `robots.txt`: replace the `Disallow: /` block with
   `User-agent: *` then `Allow: /`, and restore the line
   `Sitemap: https://bob-chapek.com/sitemap.xml`.
4. `sitemap.xml`: restore the two `<url>` entries (homepage and press kit).
5. `Dockerfile`: remove the `add_header X-Robots-Tag ...` clause from the
   `default.conf` line.

To unlist again, reverse those five steps.

## Passcode gate

While the preview is unlisted, it also sits behind a server-enforced passcode so
the content is not served to anyone who has not entered it. This is the second
layer, separate from the unlisted toggle above.

- The passcode is read at container start from the Railway variable
  `PREVIEW_PASSCODE` (default `bob-ninja`). To change it, set that variable on
  the service and redeploy. No code edit.
- The check happens in nginx, not in JavaScript: an unauthenticated request is
  redirected to `gate.html` (the lightbox) and never receives the page or its
  assets, so the passcode cannot be read from view-source or bypassed on the
  client. On success nginx sets an HttpOnly cookie; the lightbox only posts the
  code to that endpoint and then reloads.
- To turn the gate OFF (unlisted-only, the fallback), set
  `PREVIEW_PASSCODE=__OFF__` and redeploy.

## Admin area (`/admin/`)

The admin dashboard (feature flags, version control, and the planned content
editor) lives at `/admin/` and is protected by HTTP basic auth enforced by
nginx, not by JavaScript.

- The credentials come ONLY from the Railway service variables `ADMIN_USER` and
  `ADMIN_PASS`; they are read at container start and hashed into
  `/etc/nginx/.htpasswd` inside the container. No username or password is ever
  written into `index.html`, the dashboard, or any served asset, and none is
  committed to git.
- **Fail closed:** if `ADMIN_PASS` is unset, the `/admin/` location answers
  `404` rather than falling back to a guessable default. There is no default
  admin password.
- The `/admin/` location is longest-prefix, so it beats the `location /`
  passcode gate: reach the dashboard with the admin credentials, not the
  preview cookie. Admin auth is independent of the preview passcode, so both
  can be on at once.
- Revoking access is a variable change and a redeploy; rotating the password is
  the same. The `.htpasswd` is generated fresh at every container start.

## Asset caching (why a changed image can look unchanged)

A CDN/browser caches a file under its URL. When an image changes but its
filename does not, the cache keeps serving the old bytes, so a freshly deployed
page can show the previous image. That reads as "the deploy failed" when the
origin is perfectly correct (this bit us: Bob saw the old cover after it shipped).

Two mechanisms prevent that here:

- **Content-stamped asset URLs.** At container start `stamp-assets.sh` rewrites
  every asset reference in the served HTML to `assets/foo.jpg?v=<sha1>`, using the
  sha1 prefix of the file's own bytes. A changed file gets a new URL, so no cache
  can resolve it to the old object; an unchanged file keeps its URL and stays
  cacheable. The page in git is left clean, because the stamp is added at start
  and only the served copy carries it. This covers `index.html` and the
  `/versions/<id>/` snapshots, which share the same `/assets/`.
- **Explicit cache headers in nginx.** A stamped asset is content-addressed, so
  it is safe to cache for a year (`immutable`). An asset without a stamp is still
  mutable and gets a short `max-age=3600`. Everything else, the HTML above all,
  is `no-store`, so a deploy is visible on the next load.

If you ever see a changed asset look stale in the browser, confirm against the
origin before suspecting the deploy: fetch the plain URL with `?cb=<ts>` added,
or check `curl -I` for the `Cache-Control`/`age` headers. A stale asset at the
edge looks exactly like deploy drift.

To remove the gate from the image entirely, delete the `COPY entrypoint.sh` /
`ENTRYPOINT` lines from the Dockerfile. The whole gate lives in `entrypoint.sh`,
which the Dockerfile runs as the container entrypoint.

The passcode is a real protection, not just a curtain: the page source is never
sent to an unauthenticated client. It is not HTTP basic auth, so there is no
second username prompt; the only thing a visitor sees is the lightbox.

### What unlisted does and does not do

It stops search engines from listing the page. It does NOT make the page private:
anyone with the URL can open and reshare it, so treat the link as public. If the
client wants true access control, that is a separate change: HTTP basic auth at
the nginx or Railway layer, which is a deliberate decision and not applied here.

If a crawler already indexed the URL, the noindex tag stops future indexing but
does not remove an existing search result. Removing it needs Search Console,
which is Babak's account, so that step is his to run.
