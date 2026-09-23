#!/bin/sh
# Server-enforced passcode gate for the private preview (issue #37).
#
# The lock is nginx, not JavaScript. An unauthenticated request never receives
# the page or its assets; it is redirected to the lightbox (gate.html). The only
# way in is the cookie the server sets once it has itself compared the passcode,
# so view-source reveals nothing and the gate cannot be skipped from the client.
#
#   - the passcode lives in the Railway variable PREVIEW_PASSCODE, read at start,
#     so it changes with one variable and a redeploy - no code edit.
#   - PREVIEW_PASSCODE=__OFF__ switches the gate off entirely: the site falls
#     back to unlisted-only (#36). Both toggles are documented in README.md.
#
# How it holds together:
#   $http_x_passcode (the value the lightbox posts) is compared by an nginx map
#   generated below, which is the server-side check. On a match nginx sets an
#   HttpOnly session cookie whose value is a secret token (also generated below).
#   A second map accepts that cookie for the content locations. Both secrets are
#   root-owned files inside the container, never served to a client.
set -eu

: "${PREVIEW_PASSCODE:=bob-ninja}"

CONF=/etc/nginx/conf.d/default.conf
ROOT=/usr/share/nginx/html

# `COPY .` drops the build-only files into the served root; they name the
# fallback passcode and the deploy internals, so they must never be fetchable.
# The Dockerfile also removes them, but this runs at start too, so a cached image
# layer cannot leave them served.
rm -f "$ROOT/entrypoint.sh" "$ROOT/Dockerfile" "$ROOT/README.md" \
      "$ROOT/media.sha256" "$ROOT/.gitignore" "$ROOT/.dockerignore"

# ---- /admin/ credentials (issue #45) -----------------------------------------
# The admin credentials live ONLY in Railway service variables (ADMIN_USER /
# ADMIN_PASS), read here at start. They are never written into git, index.html or
# any served asset. Fail CLOSED: with no ADMIN_PASS set, /admin/ is disabled
# outright (404) rather than falling back to a guessable default baked in the
# repo. nginx checks the basic-auth password itself, so view-source sees nothing.
HTPASSWD=/etc/nginx/.htpasswd
ADMIN_ENABLED=0
if [ -n "${ADMIN_USER:-}" ] && [ -n "${ADMIN_PASS:-}" ]; then
  # -apr1 is the MD5 crypt nginx understands; openssl is already in the image.
  printf '%s:%s\n' "$ADMIN_USER" "$(openssl passwd -apr1 "$ADMIN_PASS")" > "$HTPASSWD"
  # The nginx master runs as root but its workers run as the unprivileged
  # `nginx` user, and it is the worker that reads this file to check the
  # credentials. Root-only (600) fails closed on the read -> every authed
  # request 500s. Group-read for the nginx group lets the worker read it while
  # keeping it out of reach of anyone else.
  chown root:nginx "$HTPASSWD"
  chmod 640 "$HTPASSWD"
  ADMIN_ENABLED=1
  echo "[entrypoint] admin auth ON (user: $ADMIN_USER)"
else
  echo "[entrypoint] ADMIN_PASS unset - /admin/ DISABLED (fail closed)"
fi

# The admin dashboard shows gate + unlisted state. Derive both truthfully at
# start (the gate from the passcode var, unlisted from the meta actually shipped
# in index.html) so the page reports reality rather than a hardcoded guess.
if [ "$PREVIEW_PASSCODE" = "__OFF__" ]; then GATE_STATE=off; else GATE_STATE=on; fi
if grep -q 'name="robots" content="noindex' "$ROOT/index.html" 2>/dev/null; then
  UNLISTED=true
else
  UNLISTED=false
fi
mkdir -p "$ROOT/admin"
printf '{"gate":"%s","unlisted":%s}\n' "$GATE_STATE" "$UNLISTED" > "$ROOT/admin/status.json"
# The dashboard reads versions.json from its own path so a single location block
# gates the page, the status and the version listing together.
if [ -f "$ROOT/versions/versions.json" ]; then
  cp "$ROOT/versions/versions.json" "$ROOT/admin/versions.json"
else
  printf '[]\n' > "$ROOT/admin/versions.json"
fi

# ---- the /admin/ location ------------------------------------------------
# Shared by both branches (gate on and off): admin auth is independent of the
# preview passcode. Written once here and `include`d, so the two server blocks
# cannot drift. Longest-prefix match means /admin/ beats the `location /` gate,
# so the dashboard is reached with the admin credentials, not the preview cookie.
ADMIN_CONF=/etc/nginx/admin.conf
if [ "$ADMIN_ENABLED" = "1" ]; then
  cat > "$ADMIN_CONF" <<'CONF'
  # Everything under /admin/ needs the basic-auth credentials nginx holds in
  # /etc/nginx/.htpasswd (generated at start from the Railway variables). The
  # check is the server's; no credential is in any served file.
  location /admin/ {
    auth_basic "Admin";
    auth_basic_user_file /etc/nginx/.htpasswd;
    add_header X-Robots-Tag "noindex, nofollow, noarchive" always;
    add_header Cache-Control "no-store" always;
    try_files $uri $uri/ =404;
  }
CONF
else
  # Fail closed: no credentials configured means the admin area does not exist.
  cat > "$ADMIN_CONF" <<'CONF'
  location /admin/ { return 404; }
CONF
fi

if [ "$PREVIEW_PASSCODE" = "__OFF__" ]; then
  echo "[entrypoint] PREVIEW_PASSCODE=__OFF__ - passcode gate DISABLED (unlisted only)"
  cat > "$CONF" <<'CONF'
server {
  listen 8080;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;
  add_header X-Robots-Tag "noindex, nofollow, noarchive" always;

  location = /gate-api/check { return 404; }
  location = /gate.html      { return 404; }
  include /etc/nginx/admin.conf;
  location / { try_files $uri $uri/ =404; }
}
CONF
else
  # token is derived from the passcode but is not the passcode; it is what the
  # cookie carries. hex, so it is safe as both a cookie value and an nginx map key.
  TOKEN=$(printf '%s' "$PREVIEW_PASSCODE" | sha256sum | cut -d' ' -f1)

  # Printf-inject the secrets into the generated config. The `%s` placeholders
  # keep the literals (which may contain characters meaningful to the shell) from
  # being interpreted. Server-side only - this file is never served.
  printf 'map_hash_bucket_size 128;\n'                                                  >  "$CONF"
  printf 'map $http_x_passcode $bpc_codeok { default 0; "%s" 1; }\n' "$PREVIEW_PASSCODE" >> "$CONF"
  printf 'map $cookie_bpcgate   $bpc_ok     { default 0; "%s" 1; }\n' "$TOKEN"          >> "$CONF"
  cat >> "$CONF" <<'CONF'

server {
  listen 8080;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;
  add_header X-Robots-Tag "noindex, nofollow, noarchive" always;
  # Railway terminates TLS and forwards to :8080, so an absolute redirect would
  # name the internal port and the browser could not follow it. Relative it is.
  absolute_redirect off;

  # The verifier. The lightbox POSTs the passcode in the X-Passcode header; the
  # $bpc_codeok map compares it. Only on a match does nginx set the session
  # cookie. A GET, or a wrong passcode, is refused here and no cookie is issued.
  location = /gate-api/check {
    add_header Cache-Control "no-store" always;
    if ($request_method != POST) { return 403; }
    if ($bpc_codeok = 0)         { return 403; }
    # No `always`: the Set-Cookie must ride only on the 200, never on the 403,
    # or a wrong passcode would be handed the access cookie by the error reply.
    add_header Set-Cookie "bpcgate=$bpc_cookieval; Path=/; HttpOnly; SameSite=Lax";
    default_type application/json;
    return 200 '{"ok":true}';
  }

  # The lightbox is reachable before the code is accepted (otherwise it could not be shown).
  # Never cached, so acceptance is not sticky from a cached redirect. A location's
  # own add_header replaces the inherited ones, so X-Robots-Tag is repeated here.
  location = /gate.html {
    add_header X-Robots-Tag "noindex, nofollow, noarchive" always;
    add_header Cache-Control "no-store" always;
  }

  # Everything else is gated. Any request without the access cookie is sent to
  # the lightbox, carrying the URI so it lands there after the code is accepted.
  include /etc/nginx/admin.conf;
  location / {
    if ($bpc_ok = 0) { return 302 /gate.html?rd=$request_uri; }
    try_files $uri $uri/ =404;
  }
}
CONF
  # $bpc_cookieval is not a real variable; substitute the token literally.
  sed -i "s/bpcgate=\$bpc_cookieval/bpcgate=$TOKEN/" "$CONF"
fi

nginx -t
echo "[entrypoint] starting nginx on :8080"
exec nginx -g 'daemon off;'
