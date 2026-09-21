FROM nginx:alpine
COPY . /usr/share/nginx/html

# The video masters live outside git, as assets on the `media-v1` GitHub
# release, so this repo carries zero mp4 (see reports/chapek/trailer/README-media.md).
# They are fetched into the image at build time and checked against media.sha256:
# a 404, an HTML error page, or a truncated download fails the build rather than
# shipping a broken player. The `.mp4` files are git-ignored, so a local build
# with them present is fine too - the fetch is a no-op when the file is already
# there and its checksum matches.
RUN set -eux; \
    cd /usr/share/nginx/html; \
    apk add --no-cache curl openssl; \
    base="https://github.com/babakpNinja/bob-chapek-site/releases/download/media-v1"; \
    while read -r sum name; do \
      case "$name" in ''|\#*) continue;; esac; \
      if [ -s "assets/$name" ] && echo "$sum  assets/$name" | sha256sum -c - >/dev/null 2>&1; then continue; fi; \
      curl -fsSL "$base/$name" -o "assets/$name"; \
      echo "$sum  assets/$name" | sha256sum -c -; \
    done < media.sha256; \
    apk del curl

# UNLISTED (temporary, awaiting Bob's approval). Two mechanisms live in this
# image and both are documented in README.md:
#   - X-Robots-Tag "noindex, nofollow, noarchive": added by the nginx config the
#     entrypoint writes at start, so every response carries it.
#   - the passcode gate (issue #37): entrypoint.sh writes the nginx config and an
#     htpasswd from the Railway variable PREVIEW_PASSCODE at start. The passcode
#     is enforced by nginx, never by client JS; __OFF__ disables it. See the
#     README for both toggles.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# `COPY .` also drops the build-only files into the served root. They name the
# fallback passcode and the deploy internals, so they must not be fetchable - the
# gate protects the site, but no reason to serve its own how-to. Removed after the
# fetches above have used media.sha256.
RUN rm -f /usr/share/nginx/html/entrypoint.sh /usr/share/nginx/html/Dockerfile \
    /usr/share/nginx/html/README.md /usr/share/nginx/html/media.sha256 \
    /usr/share/nginx/html/.gitignore
EXPOSE 8080
