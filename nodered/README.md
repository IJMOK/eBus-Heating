# Example Node-RED flows

`heating-flows.json` holds three tabs. Import it with Menu → Import, then:

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

Heartbeat to the Shelly and the ebusd watchdog follow once the relay is fitted.

**Dry-run:** `input_boolean.heating_live` off means everything is calculated and
written to the heating helpers, but the relay is never switched and nothing is sent
over eBUS. It starts off.
