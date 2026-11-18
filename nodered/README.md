# Example Node-RED flows

`heating-flows.json` holds four tabs. Import it with Menu → Import, then:

1. Open **Heating config** on tab 40 and set your entity IDs and notify services
   (see [../PLACEHOLDERS.md](../PLACEHOLDERS.md)).
2. Point the Home Assistant server and MQTT broker config nodes at yours. If you
   already have them, delete the imported copies and pick yours in each node.
3. Add a `file` context store to Node-RED's `settings.js`, so the integral and the
   day statistics survive restarts:
   ```js
   contextStorage: {
       default: "memory",
       memory: { module: "memory" },
       file: { module: "localfilesystem" },
   },
   ```
4. Create the helpers from [`../homeassistant/packages/heating.yaml`](../homeassistant/packages/heating.yaml),
   deploy, then press **Set starting values** once on tab 42.

| Tab | Flow |
|---|---|
| `40 Heating - Control` | Every 60 s: schedule, weather curve + PI, stage clamp, relay, eBUS SetMode (off until enabled), plus ebusd read requests |
| `41 Heating - Comfort` | Comfort events (notify, mark the day, demote one stage) and the Comfort-mode button |
| `42 Heating - Nightly` | 03:00 review: day stats, learning per stage, promotion check with approval. Starting-values button |
| `43 Heating - Heartbeat` | Every 60 s while live: heartbeat to the Shelly failsafe (KVS over MQTT RPC), plus the heating season (`fs_season`). Mirrors the Shelly's failsafe mode into HA |

Tab 40 also runs the ebusd watchdog (no bus signal, or no flow temperature for
10 min = eBUS down). The control loop falls back to the panel flow at once, but the
phones are only told once eBUS has been down for 3 minutes, and "eBUS is back" only
follows an "eBUS lost". Shorter drops (a Wi-Fi blip on a stick behind a repeater heals
in about 20 s) go to the logbook as "eBUS blip". The control law writes a one-line status, and the next heating
block, to `input_text.heating_status` / `heating_next`.

**Dry-run:** `input_boolean.heating_live` off means everything is calculated and
written to the heating helpers, but the relay is never switched and nothing is sent
over eBUS. It starts off.
