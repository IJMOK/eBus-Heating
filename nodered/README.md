# Example Node-RED flows

Sanitised copies of the flows. Import them, then set your entity IDs in the config node (see ../PLACEHOLDERS.md).

| File | Flow |
|---|---|
| `01-control.json` | Control loop, every 60 s |
| `02-heartbeat.json` | Heartbeat to the Shelly (KVS) |
| `03-ebusd-watchdog.json` | Falls back to on/off room-stat mode if ebusd goes away |
| `04-nightly.json` | 03:00 stats, learning, promotion check |
| `05-comfort.json` | Comfort guard, warm-up boost, Comfort-mode button |
