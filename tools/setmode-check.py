"""Stage 1 checkpoint: check one SetMode on the real boiler before the flows may write.

    MQTT_PASSWORD=... python tools/setmode-check.py --host <HA_HOST> --mqtt-user <MQTT_USER> \
        --flow 55 --hwc 50

Before you start: the heating must be calling (turn the room set point up a little), the
boiler's front panel shows its hot-water setting (pass that exact value as --hwc), and
someone can run a hot tap when asked.

1. Baseline: reads the boiler's own flow target (FlowTempDesired), checks SetMode is writable.
2. Send: publishes `auto;FLOW;HWC;-;0;0;0;0;0;0` to <prefix>/<circuit>/SetMode/set every 60 s
   (both hot-water disable bits 0) and logs target, flow, flame and hot-water demand. It checks
   ebusd's decoded echo of what went on the bus, and asks you to run a hot tap.
3. Revert: stops sending and times how long the boiler takes to go back to its own target.
   That's how long a stopped HA/Node-RED leaves your last flow target in place.

Ctrl+C during the send phase skips straight to the revert phase. Stdlib only. The MQTT
password is read from the MQTT_PASSWORD environment variable, never from the command line.
"""
import argparse
import json
import os
import select
import socket
import struct
import sys
import time
import urllib.request


class Mqtt:
    """Just enough MQTT 3.1.1: connect, subscribe, QoS 0 publish, receive."""

    def __init__(self, host, port, user, password):
        self.s = socket.create_connection((host, port), timeout=10)
        self.buf = b""
        flags, payload = 0x02, self._str("setmode-check-%d" % os.getpid())   # clean session
        if user:
            flags |= 0x80; payload += self._str(user)
        if password:
            flags |= 0x40; payload += self._str(password)
        self._packet(0x10, self._str("MQTT") + bytes([4, flags]) + struct.pack(">H", 60) + payload)
        kind, body = self._read_packet(10)
        if kind != 0x20 or body[1] != 0:
            raise SystemExit("MQTT connect refused (return code %s)" % (body[1] if body else "?"))

    @staticmethod
    def _str(s):
        b = s.encode()
        return struct.pack(">H", len(b)) + b

    def _packet(self, head, body):
        n, ln = len(body), b""
        while True:
            d, n = n % 128, n // 128
            ln += bytes([d | (0x80 if n else 0)])
            if not n:
                break
        self.s.sendall(bytes([head]) + ln + body)

    def _read_packet(self, timeout):
        end = time.time() + timeout
        while True:
            if len(self.buf) >= 2:
                mult, n, i = 1, 0, 1
                while i < len(self.buf):
                    n += (self.buf[i] & 0x7F) * mult
                    mult *= 128
                    i += 1
                    if not self.buf[i - 1] & 0x80:
                        if len(self.buf) >= i + n:
                            head, body = self.buf[0], self.buf[i:i + n]
                            self.buf = self.buf[i + n:]
                            return head & 0xF0, body
                        break
            left = end - time.time()
            if left <= 0 or not select.select([self.s], [], [], left)[0]:
                return None, None
            chunk = self.s.recv(4096)
            if not chunk:
                raise SystemExit("MQTT connection closed")
            self.buf += chunk

    def subscribe(self, topic):
        self._packet(0x82, struct.pack(">H", 1) + self._str(topic) + bytes([0]))

    def publish(self, topic, payload):
        self._packet(0x30, self._str(topic) + payload.encode())

    def messages(self, timeout):
        """Yield (topic, payload) received within timeout seconds."""
        end = time.time() + timeout
        while time.time() < end:
            kind, body = self._read_packet(end - time.time())
            if kind == 0x30:
                tl = struct.unpack(">H", body[:2])[0]
                yield body[2:2 + tl].decode(errors="replace"), body[2 + tl:].decode(errors="replace")
            elif kind is None:
                return

    def ping(self):
        self._packet(0xC0, b"")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--host", required=True, help="host running ebusd and the MQTT broker")
    ap.add_argument("--http-port", type=int, default=8889, help="ebusd --httpport (read-only JSON)")
    ap.add_argument("--mqtt-host", help="MQTT broker, if not --host")
    ap.add_argument("--mqtt-port", type=int, default=1883)
    ap.add_argument("--mqtt-user")
    ap.add_argument("--prefix", default="ebusd", help="ebusd MQTT topic prefix")
    ap.add_argument("--circuit", default="bai")
    ap.add_argument("--flow", type=float, required=True, help="flow target to send, below your panel setting")
    ap.add_argument("--hwc", type=float, required=True, help="the hot-water setting shown on your boiler's panel")
    ap.add_argument("--minutes", type=float, default=5, help="how long to keep sending")
    ap.add_argument("--revert-max", type=float, default=40, help="give up waiting for the revert after this many minutes")
    a = ap.parse_args()

    base = "http://%s:%d/data/%s" % (a.host, a.http_port, a.circuit)

    def read(msg):
        try:
            with urllib.request.urlopen("%s/%s?maxage=0&required" % (base, msg), timeout=15) as r:
                fields = json.load(r).get(a.circuit, {}).get("messages", {}).get(msg, {}).get("fields") or {}
            return [f.get("value") for f in fields.values()]
        except Exception:
            return None

    def one(msg):
        v = read(msg)
        return v[0] if v else None

    # --- 1. Baseline ---
    with urllib.request.urlopen(base + "?def&write", timeout=15) as r:
        writable = [k for k, v in json.load(r).get(a.circuit, {}).get("messages", {}).items()
                    if v.get("write") and not v.get("passive")]
    if not any(k.split("-")[0] == "SetMode" for k in writable):
        raise SystemExit("SetMode isn't writable in ebusd. See docs/03-ebusd-setup.md (pin the config, --accesslevel).")
    own = one("FlowTempDesired")
    print("Writable on %s: %s" % (a.circuit, ", ".join(sorted(writable))))
    print("Boiler's own flow target (FlowTempDesired): %s °C" % own)
    if own is None:
        raise SystemExit("Can't read FlowTempDesired. Check ebusd's HTTP port and the circuit name.")
    if a.flow >= own:
        raise SystemExit("--flow %.0f isn't below the boiler's own %.0f °C, so a change couldn't be seen." % (a.flow, own))
    if not 20 <= a.flow <= 75 or not 35 <= a.hwc <= 65:
        raise SystemExit("--flow or --hwc looks wrong; refusing to send.")

    mq = Mqtt(a.mqtt_host or a.host, a.mqtt_port, a.mqtt_user, os.environ.get("MQTT_PASSWORD"))
    topic = "%s/%s/SetMode" % (a.prefix, a.circuit)
    payload = "auto;%g;%g;-;0;0;0;0;0;0" % (a.flow, a.hwc)
    mq.subscribe(topic)
    seen = {"target": False, "flame": False, "hwc": False, "echo": None}

    def status(prefix=""):
        target, flow, flame, hwc = one("FlowTempDesired"), one("FlowTemp"), one("Flame"), one("HwcDemand")
        print("%s %s target %s | flow %s | flame %s | hot water %s" % (time.strftime("%H:%M:%S"), prefix, target, flow, flame, hwc), flush=True)
        return target, flame, hwc

    def check_echo(timeout):
        for t, p in mq.messages(timeout):
            if t != topic:
                continue
            try:
                d = {k: (v.get("value") if isinstance(v, dict) else v) for k, v in json.loads(p).items()}
            except ValueError:
                d = {"raw": p}
            ok = (d.get("flowtempdesired") == a.flow and d.get("hwctempdesired") == a.hwc
                  and d.get("disablehwctapping") == 0 and d.get("disablehc") == 0 and d.get("disablehwcload") == 0)
            if seen["echo"] is None:
                print("  ebusd echo: %s -> %s" % (json.dumps(d), "matches" if ok else "DOESN'T MATCH"))
            seen["echo"] = ok if seen["echo"] is None else seen["echo"] and ok

    # --- 2. Send ---
    print("\nSending %s to %s/set every 60 s for %g min. Ctrl+C skips to the revert check." % (payload, topic, a.minutes))
    last_sent, asked = 0, False
    start = time.time()
    try:
        while time.time() - start < a.minutes * 60:
            mark = " "
            if time.time() - last_sent >= 60:
                mq.publish(topic + "/set", payload)
                last_sent, mark = time.time(), "*"
            check_echo(3)
            target, flame, hwc = status(mark)
            seen["target"] |= target == a.flow
            seen["flame"] |= flame == "on" and target == a.flow
            seen["hwc"] |= hwc == "yes"
            if seen["target"] and not asked:
                print(">>> The boiler took %g °C. Run a hot tap for about a minute now." % a.flow)
                asked = True
            mq.ping()
            time.sleep(12)
    except KeyboardInterrupt:
        print("\nStopped sending.")

    # --- 3. Revert ---
    print("\nNot sending any more. Waiting for the boiler to go back to its own %s °C..." % own)
    t0 = last_sent or time.time()
    reverted = None
    while time.time() - t0 < a.revert_max * 60:
        target, _, _ = status("  ")
        if target is not None and target != a.flow:
            reverted = time.time() - t0
            break
        try:
            mq.ping()
        except OSError:
            pass
        time.sleep(30)

    # --- Summary ---
    yes = lambda b: "PASS" if b else "FAIL"
    print("\nSummary")
    print("  ebusd echo of the sent payload ......... %s" % ("not seen" if seen["echo"] is None else yes(seen["echo"])))
    print("  boiler took the flow target ............ %s" % yes(seen["target"]))
    print("  burner fired at that target ............ %s" % ("PASS" if seen["flame"] else "not seen (was the heating calling?)"))
    print("  hot water ran during the test .......... %s" % ("PASS" if seen["hwc"] else "not seen (run a hot tap)"))
    if reverted is not None:
        print("  went back to its own target after ...... %.0f min after the last send" % (reverted / 60))
    else:
        print("  went back to its own target ............ NOT within %g min: the boiler keeps the last target, "
              "so plan a failsafe for when HA stops" % a.revert_max)
    print("Check that the hot water was its normal temperature at the tap. Then set ebusWriteEnabled: true.")
    return 0 if seen["target"] and seen["echo"] is not False else 1


if __name__ == "__main__":
    sys.exit(main())
