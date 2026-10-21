#!/usr/bin/env python3
# fanctl: reads calliope's temperatures and sets its fans over in-band IPMI,
# serving a small page and JSON API on localhost. Manual mode hands control
# back to the iDRAC as soon as anything runs hot or stops reporting; see
# ../fans.nix for the bands and why they sit where they do.

import glob
import json
import os
import re
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

IPMITOOL = os.environ["FANCTL_IPMITOOL"]
SMARTCTL = os.environ["FANCTL_SMARTCTL"]
PAGE     = os.environ["FANCTL_PAGE"]
PORT     = int(os.environ["FANCTL_PORT"])
STATE    = os.path.join(os.environ["STATE_DIRECTORY"], "state.json")

INTERVAL  = 15  # seconds between sensor sweeps
MIN_SPEED = 10  # percent

# Upper bounds (°C, inclusive) of cool, normal, warm and hot; above the last
# is danger. Manual mode gives up the moment anything reaches hot.
BANDS = {
    "inlet":   [18, 27, 32, 38],
    "exhaust": [35, 45, 55, 65],
    "cpu":     [50, 70, 80, 90],
    "hdd":     [30, 40, 45, 50],
    "nvme":    [40, 55, 65, 70],
}
NAMES = ["cool", "normal", "warm", "hot", "danger"]
TRIP  = NAMES.index("hot")

lock   = threading.Lock()
wake   = threading.Event()
state  = {"mode": "auto", "speed": 30, "tripped": None}
status = {"temps": [], "fans": [], "updated": None, "error": None}


def band(kind, value):
    for name, limit in zip(NAMES, BANDS[kind]):
        if value <= limit:
            return name
    return NAMES[-1]


def reading(name, kind, value):
    return {"name": name, "kind": kind, "value": value, "band": band(kind, value)}


def ipmi(*args):
    return subprocess.run([IPMITOOL, *args], capture_output=True, text=True,
                          check=True, timeout=30).stdout


# `ipmitool sdr type X` rows: name | id | status | entity | reading
def sdr(kind):
    rows = []
    for line in ipmi("sdr", "type", kind).splitlines():
        f = [x.strip() for x in line.split("|")]
        if len(f) != 5:
            continue
        m = re.match(r"-?\d+(\.\d+)?", f[4])
        rows.append((f[0], f[3], f[2], float(m.group()) if m else None))
    return rows


# Both CPU sensors are just "Temp"; entity 3.N (processor N) tells them apart.
def system_temps():
    out = []
    for name, entity, _, value in sdr("temperature"):
        if value is None:
            continue
        if name.startswith("Inlet"):
            out.append(reading("Inlet", "inlet", value))
        elif name.startswith("Exhaust"):
            out.append(reading("Exhaust", "exhaust", value))
        elif entity.startswith("3."):
            out.append(reading("CPU" + entity[2:], "cpu", value))
    return out


def fans():
    return [{"name": name.removesuffix(" RPM"), "rpm": value, "ok": st == "ok"}
            for name, _, st, value in sdr("fan") if name.endswith("RPM")]


# SAS disks via smartctl (the kernel's drivetemp is SATA-only); the NVMe via
# its hwmon node. The USB chainloader stick is skipped.
def drive_temps():
    out = []
    for path in sorted(glob.glob("/sys/block/sd*")):
        if "/usb" in os.path.realpath(path):
            continue
        dev = os.path.basename(path)
        r = subprocess.run([SMARTCTL, "-j", "-A", "-n", "standby", "/dev/" + dev],
                           capture_output=True, text=True, timeout=30)
        try:
            out.append(reading(dev, "hdd", json.loads(r.stdout)["temperature"]["current"]))
        except (ValueError, KeyError, TypeError):
            pass
    for path in sorted(glob.glob("/sys/class/nvme/nvme*/hwmon*/temp1_input")):
        with open(path) as f:
            out.append(reading("nvme" + path.split("/")[4][4:], "nvme", int(f.read()) / 1000))
    return out


def load():
    try:
        with open(STATE) as f:
            state.update(json.load(f))
    except (OSError, ValueError):
        pass


def save():
    with open(STATE + ".tmp", "w") as f:
        json.dump(state, f)
    os.replace(STATE + ".tmp", STATE)


def apply():
    if state["mode"] == "manual":
        ipmi("raw", "0x30", "0x30", "0x01", "0x00")
        ipmi("raw", "0x30", "0x30", "0x02", "0xff", "0x%02x" % state["speed"])
    else:
        ipmi("raw", "0x30", "0x30", "0x01", "0x01")


def unsafe(temps, error):
    if error:
        return error
    hot = [t for t in temps if NAMES.index(t["band"]) >= TRIP]
    if hot:
        t = max(hot, key=lambda t: NAMES.index(t["band"]))
        return "%s reached %g °C" % (t["name"], t["value"])
    for kind, what in (("cpu", "CPU"), ("hdd", "drive")):
        if not any(t["kind"] == kind for t in temps):
            return "no %s temperature reading" % what
    return None


def tick():
    temps, fan, error = [], [], None
    try:
        temps, fan = system_temps(), fans()
    except (subprocess.SubprocessError, OSError) as e:
        error = "IPMI read failed: %s" % e
    temps += drive_temps()

    with lock:
        try:
            # Manual is re-asserted every sweep: a BMC reset quietly reverts to auto.
            if state["mode"] == "manual":
                reason = unsafe(temps, error)
                if reason:
                    print("tripping to auto:", reason, flush=True)
                    state.update(mode="auto", tripped={"at": time.time(), "reason": reason})
                    save()
                apply()
        except (subprocess.SubprocessError, OSError) as e:
            error = "IPMI write failed: %s" % e
        status.update(temps=temps, fans=fan, updated=time.time(), error=error)


def loop():
    while True:
        try:
            tick()
        except Exception as e:  # never let the watchdog thread die
            print("tick failed:", e, flush=True)
        wake.wait(INTERVAL)
        wake.clear()


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, ctype="application/json"):
        data = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
            with open(PAGE, "rb") as f:
                self.send(200, f.read(), "text/html")
        elif path == "/api/status":
            with lock:
                body = {**status, **state, "bands": BANDS, "minSpeed": MIN_SPEED}
            self.send(200, json.dumps(body))
        else:
            self.send(404, '{"error": "not found"}')

    def do_POST(self):
        if self.path != "/api/mode":
            return self.send(404, '{"error": "not found"}')
        # Requiring JSON forces a CORS preflight, which this server never
        # answers, so another site open in a LAN browser cannot POST here.
        if self.headers.get("Content-Type", "").split(";")[0].strip() != "application/json":
            return self.send(415, '{"error": "expected application/json"}')
        try:
            req = json.loads(self.rfile.read(min(int(self.headers.get("Content-Length", 0)), 1024)))
            mode, speed = req["mode"], req.get("speed", state["speed"])
            if mode not in ("auto", "manual") or type(speed) is not int \
                    or not MIN_SPEED <= speed <= 100:
                raise ValueError
        except (ValueError, KeyError, TypeError):
            return self.send(400, '{"error": "want {mode: auto} or {mode: manual, speed: %d-100}"}' % MIN_SPEED)

        with lock:
            state.update(mode=mode, speed=speed, tripped=None)
            save()
            try:
                apply()
            except (subprocess.SubprocessError, OSError) as e:
                return self.send(502, json.dumps({"error": "IPMI write failed: %s" % e}))
        print("set", mode, "%d%%" % speed if mode == "manual" else "", flush=True)
        wake.set()  # check temperatures against the new setting right away
        self.send(200, '{"ok": true}')

    def log_request(self, code="-", size="-"):
        pass  # the page polls every few seconds; changes are printed above


if __name__ == "__main__":
    load()
    threading.Thread(target=loop, daemon=True).start()
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
