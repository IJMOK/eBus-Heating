"""Pin the ebusd message definitions locally and give SetMode its own access level.

    python tools/pin-ebusd-config.py OUT_DIR [--level heating]

Mirrors what ebusd loads from its online config server for a Vaillant system
(https://ebus.github.io/en/: the top-level *.csv, vaillant/*.csv and every include file
those load with `!load`) into OUT_DIR. Then it changes exactly one
thing: the active write of `bai SetMode` moves from level "install" to LEVEL.

Run ebusd with `--configpath=OUT_DIR --accesslevel=LEVEL`. ebusd matches access
levels as whole tokens, so only SetMode becomes writable. Every installer setting
(FlowsetHcMax, SetFactoryValues, ...) stays locked, and because the files are local
an upstream relabel can't unlock them. Re-run this to pick up upstream changes and
review the diff before deploying.
"""
import argparse
import json
import os
import sys
import urllib.request

BASE = "https://ebus.github.io/en/"
UA = {"User-Agent": "eBus-Heating pin-ebusd-config"}


def get(rel):
    with urllib.request.urlopen(urllib.request.Request(BASE + rel, headers=UA), timeout=30) as r:
        return r.read()


def listing(rel, ext):
    raw = get(rel + "?t=" + ext).decode().strip()
    names = (json.loads(raw) if raw.startswith('"') else raw).split("\n")
    return [n for n in names if n and not n.endswith("/")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--level", default="heating")
    a = ap.parse_args()
    if not a.level.isalnum() or a.level in ("install", "service"):
        sys.exit("level must be a new alphanumeric word")

    files = listing("", "csv") + ["vaillant/" + n for n in listing("vaillant/", "csv")]
    if "vaillant/08.bai.csv" not in files:
        sys.exit("vaillant/08.bai.csv missing from the listing")

    done = set()
    while files:
        rel = files.pop(0)
        if rel in done:
            continue
        done.add(rel)
        data = get(rel)
        folder = rel.rsplit("/", 1)[0] + "/" if "/" in rel else ""
        for line in data.decode("utf-8").splitlines():   # includes: "[cond]!load,name.inc,..."
            if "!load," in line:
                files.append(folder + line.split("!load,", 1)[1].split(",", 1)[0])
        if rel == "vaillant/08.bai.csv":
            data = patch(data.decode("utf-8"), a.level).encode("utf-8")
        path = os.path.join(a.out, *rel.split("/"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
    print("pinned %d files into %s; SetMode write level = %s" % (len(done), a.out, a.level))


def patch(text, level):
    """Move the one active SetMode write from 'install' to LEVEL; fail on anything unexpected."""
    old = "w,,install,SetMode,"
    lines = text.split("\n")
    hits = [i for i, l in enumerate(lines) if l.startswith(old)]
    if len(hits) != 1:
        sys.exit("expected exactly one '%s...' line in 08.bai.csv, found %d" % (old, len(hits)))
    lines[hits[0]] = "w,," + level + ",SetMode," + lines[hits[0]][len(old):]
    return "\n".join(lines)


if __name__ == "__main__":
    main()
