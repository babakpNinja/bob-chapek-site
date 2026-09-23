#!/usr/bin/env python3
"""The /admin/ write-back for the smallest flag: the passcode gate (#51).

The dashboard used to be read-only. Making ONE panel actually write needs a
server-side writer: the site is a static nginx container, and a browser cannot
hold the credential that flips a production variable. So this is a tiny Python
backend that nginx proxies to, and it holds the write credential in a Railway
service variable, never in a served file.

What it can write is deliberately one thing, the passcode gate: set
`PREVIEW_PASSCODE=__OFF__` (the documented off-switch) or set it back to a
passcode, then re-trigger the deploy so the container rebuilds its config. Every
other flag (unlisted, versions, content) is a bigger change and stays for a later
slice.

Security shape, because this endpoint mutates production:

  - **Loopback only.** It binds 127.0.0.1, so the only way in is through nginx.
  - **Behind the admin auth.** The nginx location that proxies to it carries the
    same `auth_basic` as `/admin/`, and it is written only when admin auth is
    configured. No request reaches this process that nginx did not authenticate.
  - **Fail closed.** No `ADMIN_RAILWAY_TOKEN` set means every write is refused, with a
    message saying so; the read-only flag list still renders. Enabling the panel
    is setting the variable, not editing code.
  - **Nothing secret is echoed.** The token and the passcode are never logged and
    never returned; the status body names only whether a gate is on and whether
    the writer is configured.
  - **One narrow contract.** Only the known flag and the known values are
    accepted; anything else is a 400. The GraphQL it will run is fixed.

Run it directly for a local check (the token can be a dummy; writes then fail
with a clear error, which is the point):

    ADMIN_RAILWAY_TOKEN=x python3 admin_writeback.py --port 9099
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RAILWAY_API = "https://backboard.railway.com/graphql/v2"
# Railway refuses a request with no User-Agent at the edge (Cloudflare 1010), and
# a project token rides the Project-Access-Token header, not Authorization.
# Both were found the hard way; do not "simplify" them away.
UA = "bob-chapek-admin-writeback/1.0"

GATE_OFF = "__OFF__"
MAX_BODY = 4096          # a flag request is a few dozen bytes; anything larger is a probe
MIN_PASSCODE = 6


def validate_flag(flag: str, value: str, passcode: str = "") -> dict[str, str]:
    """Map one (flag, value) to the exact variable upsert, or raise ValueError.

    This is the whole write contract in one place, so a test can prove the
    endpoint cannot be talked into writing something else. Only the gate flag
    exists today; `__OFF__` is the documented off-switch, and turning the gate
    back ON requires an actual passcode (there is no "true" value that would
    quietly restore a guessable default).
    """
    if flag != "gate":
        raise ValueError(f"unknown flag '{flag}'")
    if value == "off":
        return {"PREVIEW_PASSCODE": GATE_OFF}
    if value == "on":
        code = (passcode or "").strip()
        if len(code) < MIN_PASSCODE:
            raise ValueError(f"passcode must be at least {MIN_PASSCODE} characters")
        if code == GATE_OFF:
            raise ValueError("that is the off-switch, not a passcode")
        return {"PREVIEW_PASSCODE": code}
    raise ValueError(f"unknown value '{value}' for gate (use on or off)")


def upsert_mutation() -> str:
    """The one GraphQL the writer runs. Fixed, so no input can shape it."""
    return ("mutation($input:VariableCollectionUpsertInput!){"
            "variableCollectionUpsert(input:$input)}")


def redeploy_mutation() -> str:
    # Redeploy the CURRENT image. This intentionally does not pass a commit sha:
    # that would need RAILWAY_GIT_COMMIT_SHA in the container, which is not
    # guaranteed, and the goal is only to restart the container so it re-reads
    # PREVIEW_PASSCODE. No new code is deployed here.
    return ("mutation($s:String!,$e:String!){serviceInstanceRedeploy("
            "serviceId:$s,environmentId:$e)}")


def upsert_input(project_id: str, environment_id: str, service_id: str,
                 variables: dict[str, str]) -> dict:
    return {"projectId": project_id, "environmentId": environment_id,
            "serviceId": service_id, "variables": variables}


def token_configured(env: dict | None = None) -> bool:
    """Fail closed: no token means the writer refuses, it does not guess one."""
    env = env if env is not None else os.environ
    return bool((env.get("ADMIN_RAILWAY_TOKEN") or "").strip())


def railway_ids(env: dict | None = None) -> dict[str, str]:
    """The ids the redeploy needs, from Railway's injected vars.

    Railway injects RAILWAY_PROJECT_ID / RAILWAY_ENVIRONMENT_ID /
    RAILWAY_SERVICE_ID into a service; ADMIN_RAILWAY_* are an explicit override
    for when a container does not see them.
    """
    env = env if env is not None else os.environ
    pick = {"project_id": ("ADMIN_RAILWAY_PROJECT_ID", "RAILWAY_PROJECT_ID"),
            "environment_id": ("ADMIN_RAILWAY_ENVIRONMENT_ID", "RAILWAY_ENVIRONMENT_ID"),
            "service_id": ("ADMIN_RAILWAY_SERVICE_ID", "RAILWAY_SERVICE_ID")}
    out: dict[str, str] = {}
    for key, names in pick.items():
        out[key] = next((env.get(n, "") for n in names if env.get(n)), "")
    return out


def graphql(query: str, variables: dict, token: str) -> dict:
    """One call to Railway with a project token. Raises RuntimeError on failure."""
    body = json.dumps({"query": query, "variables": variables}).encode()
    req = urllib.request.Request(
        RAILWAY_API, data=body,
        headers={"Project-Access-Token": token, "Content-Type": "application/json",
                 "User-Agent": UA, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            payload = json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as err:
        raise RuntimeError(f"railway http {err.code}") from err
    except urllib.error.URLError as err:
        raise RuntimeError(f"railway unreachable: {err.reason}") from err
    if payload.get("errors"):
        raise RuntimeError("railway graphql: " + str(payload["errors"])[:200])
    return payload.get("data") or {}


def apply_flag(flag: str, value: str, passcode: str, env: dict | None = None,
               gql=graphql) -> dict:
    """Validate, upsert the variable, then redeploy. Returns a small result dict.

    Raises ValueError for a bad request (400) and RuntimeError if Railway refuses
    or the writer is not configured (500/503). The gql call is injectable so a
    test can prove the exact mutation without touching Railway.
    """
    env = env if env is not None else os.environ
    variables = validate_flag(flag, value, passcode)
    if not token_configured(env):
        raise RuntimeError("writer is not configured (ADMIN_RAILWAY_TOKEN unset); "
                           "the panel is read-only until it is")
    ids = railway_ids(env)
    missing = [k for k, v in ids.items() if not v]
    if missing:
        raise RuntimeError("railway ids missing: " + ", ".join(missing))
    token = env["ADMIN_RAILWAY_TOKEN"].strip()

    gql(upsert_mutation(), {"input": upsert_input(
        ids["project_id"], ids["environment_id"], ids["service_id"], variables)}, token)
    # A variable change does not rebuild on its own; the container regenerates its
    # config at START, so the new value only takes effect on a restart.
    gql(redeploy_mutation(),
        {"s": ids["service_id"], "e": ids["environment_id"]}, token)
    return {"ok": True, "flag": flag, "value": value, "redeployed": True,
            "note": "the gate flips when the container restarts"}


def status_body(env: dict | None = None) -> dict:
    """What the panel may show: state and whether writing is even possible.

    Read from THIS process's environment, so it reports the passcode the running
    container was started with, not a guess from the page.
    """
    env = env if env is not None else os.environ
    code = env.get("PREVIEW_PASSCODE", "")
    return {
        "gate": "off" if code == GATE_OFF else "on",
        "can_write": token_configured(env),
        "writable_flags": ["gate"],
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "admin-writeback"
    # HTTP/1.1 with an explicit Content-Length (set in _send). The default is
    # HTTP/1.0, which closes the socket after every reply; nginx may then reuse
    # that closed upstream connection for the next request and answer 502 even
    # though this process handled the call fine. 1.1 keep-alive is the fix.
    protocol_version = "HTTP/1.1"

    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):  # never echo request lines: they may carry a passcode
        sys.stderr.write("[writeback] %s\n" % (fmt % args).replace("\n", " ")[:200])

    def do_GET(self):
        if self.path.rstrip("/") in ("/status", ""):
            return self._send(200, status_body())
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path.rstrip("/") != "/flag":
            return self._send(404, {"error": "not found"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return self._send(400, {"error": "bad length"})
        if n <= 0 or n > MAX_BODY:
            return self._send(400, {"error": "bad request body"})
        try:
            payload = json.loads(self.rfile.read(n).decode() or "{}")
        except (ValueError, UnicodeDecodeError):
            return self._send(400, {"error": "invalid json"})
        if not isinstance(payload, dict):
            return self._send(400, {"error": "invalid json"})
        try:
            result = apply_flag(str(payload.get("flag", "")), str(payload.get("value", "")),
                                str(payload.get("passcode", "")))
        except ValueError as err:
            return self._send(400, {"error": str(err)})
        except RuntimeError as err:
            code = 503 if "not configured" in str(err) else 500
            return self._send(code, {"error": str(err)})
        return self._send(200, result)


def main() -> int:
    ap = argparse.ArgumentParser(description="admin write-back (loopback only)")
    ap.add_argument("--host", default="127.0.0.1",
                    help="bind address; keep it loopback so only nginx can reach it")
    ap.add_argument("--port", type=int, default=9099)
    a = ap.parse_args()
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    print(f"[writeback] listening on {a.host}:{a.port} "
          f"(write={'on' if token_configured() else 'OFF - no ADMIN_RAILWAY_TOKEN'})",
          flush=True)
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
