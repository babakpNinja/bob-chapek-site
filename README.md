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

### What unlisted does and does not do

It stops search engines from listing the page. It does NOT make the page private:
anyone with the URL can open and reshare it, so treat the link as public. If the
client wants true access control, that is a separate change: HTTP basic auth at
the nginx or Railway layer, which is a deliberate decision and not applied here.

If a crawler already indexed the URL, the noindex tag stops future indexing but
does not remove an existing search result. Removing it needs Search Console,
which is Babak's account, so that step is his to run.
