#!/usr/bin/env python3
# seerr-gate: answers Caddy's forward_auth on request.jukeluke.com. It asks
# Seerr who owns the request's session and replies 502 for the user ids in
# SEERR_GATE_BLOCKED, 200 for everyone else; see ../seerr.nix for why.

import json
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT    = int(os.environ["SEERR_GATE_PORT"])
ME      = os.environ["SEERR_GATE_UPSTREAM"] + "/api/v1/auth/me"
BLOCKED = {int(i) for i in os.environ["SEERR_GATE_BLOCKED"].split(",") if i}

TTL = 60    # seconds a verdict is reused; a session never changes owner
MAX = 4096  # verdicts held before the cache is dropped and rebuilt

cache = {}


def blocked(cookie):
    """Whether Seerr resolves this Cookie header to a blocked user.

    The header is handed to Seerr untouched rather than parsed here, so the
    verdict is about exactly the session Seerr itself would pick. Anything
    but a clean answer allows the request: if Seerr is down the real proxy
    shows that on its own, and a logged-out visitor is nobody yet.
    """
    now = time.monotonic()
    hit = cache.get(cookie)
    if hit and hit[0] > now:
        return hit[1]
    try:
        req = urllib.request.Request(ME, headers={"Cookie": cookie})
        with urllib.request.urlopen(req, timeout=5) as r:
            user = json.load(r)
    except (OSError, ValueError):
        return False
    verdict = isinstance(user, dict) and user.get("id") in BLOCKED
    if verdict:
        print(f"blocking user {user['id']}", flush=True)
    if len(cache) >= MAX:
        cache.clear()
    cache[cookie] = (now + TTL, verdict)
    return verdict


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        cookie = "; ".join(self.headers.get_all("Cookie", []))
        # An empty 502 is what Caddy sends when an upstream is down, and
        # Cloudflare swaps it for its own "Bad gateway" page.
        code = 502 if "connect.sid" in cookie and blocked(cookie) else 200
        self.send_response(code)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_request(self, code="-", size="-"):
        pass  # one line per proxied request otherwise


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
