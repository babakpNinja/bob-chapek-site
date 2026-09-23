#!/bin/sh
# Emit the nginx map blocks for the passcode gate (issues #37, #48, #49).
#
# Kept as its own script, taking the secrets as arguments, so it can be tested
# without a container and without nginx: the test asserts both passcodes land in
# the verifier map and that an empty reviewer value adds no line. This is where
# "either key opens the one door" is decided, so it is exactly the part that
# must not be taken on trust.
#
# Usage: gate-map.sh <main-passcode> <reviewer-passcode-or-empty> <cookie-token>
#
# The cookie token is derived from the MAIN passcode by the caller (entrypoint),
# not here, so this script stays a pure formatter with no hashing of its own.
set -eu

MAIN=${1:?usage: gate-map.sh <main> <reviewer-or-empty> <token>}
REVIEWER=${2-}
TOKEN=${3:?usage: gate-map.sh <main> <reviewer-or-empty> <token>}

# nginx needs a bucket big enough for a long passcode as a map key.
printf 'map_hash_bucket_size 128;\n'
# The verifier: one map, one line per accepted value. Both passcodes are entries
# in the SAME map, so either opens the one door and neither is privileged. A
# wrong value matches no line and the map yields its default of 0. Each value is
# quoted so a literal with punctuation is matched exactly, never read as nginx
# syntax. A duplicate key is an nginx config error, so the reviewer line is
# written only when it is set AND differs from the main value.
printf 'map $http_x_passcode $bpc_codeok {\n'
printf '  default 0;\n'
printf '  "%s" 1;\n' "$MAIN"
if [ -n "$REVIEWER" ] && [ "$REVIEWER" != "$MAIN" ]; then
  printf '  "%s" 1;\n' "$REVIEWER"
fi
printf '}\n'
# The access cookie carries the token, never a passcode. It is hex, so it is
# safe as both a cookie value and a map key.
printf 'map $cookie_bpcgate $bpc_ok { default 0; "%s" 1; }\n' "$TOKEN"
