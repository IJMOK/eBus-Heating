# eBus-Heating

Replace a cloud thermostat (tado) with **Home Assistant + Node-RED** driving a
**Vaillant ecoTEC** boiler over **eBUS**, with **weather compensation**, a
**room-temperature trim**, and a **Shelly relay failsafe** that keeps the house
warm if Home Assistant, Wi-Fi or the eBUS link goes down.

> **Status (October 2026): Stage 1 (capped), flow writes about to start.** HA
> switches the boiler through the Shelly relay on room temperature. The Shelly
> failsafe is wired, runs on boot and passed all [11 failsafe tests](docs/testing.md).
> ebusd is set up so that only the flow-setpoint command can be written. That
> command passed its [checkpoint on the real boiler](docs/testing.md#stage-1-checkpoint-setmode),
> so the flows are next to write it; until then the boiler runs at its panel flow
> temperature. [Results](docs/results.md) follow as the stages progress.

## How it works

```
 Met Office ──┐                         ┌──► eBUS Adapter Stick C6 ──► boiler flow setpoint
 room sensor ─┼─► Node-RED control law ─┤      (via ebusd + MQTT)
 HA helpers ──┘                         └──► Shelly 1 Gen4 relay ──► boiler terminals 3-4 (heat demand)

 Shelly failsafe script: no heartbeat from HA for 15 min → local thermostat
 on the Bluetooth room sensor → if that is stale too → timed schedule
```

- The boiler's own front-panel flow temperature (60 °C here) stays as the
  **hard ceiling**. Nothing in this project can make the boiler run hotter.
- Node-RED works out a flow target from outdoor temperature, then trims it with
  a PI term on the room error.
- Control is handed over in **stages**: shadow → capped → assisted → auto.
  You approve each promotion; any comfort problem demotes it automatically.
- A **heating season** switch turns everything off for summer, the failsafe
  included.

## Contents

| Path | What |
|---|---|
| [`docs/01-hardware-bom.md`](docs/01-hardware-bom.md) | Parts list and why each part |
| [`docs/02-wiring-safety.md`](docs/02-wiring-safety.md) | Isolation, eBUS and relay wiring |
| [`docs/03-ebusd-setup.md`](docs/03-ebusd-setup.md) | Stick firmware/Wi-Fi, ebusd add-on, MQTT entities |
| [`docs/04-shelly-failsafe.md`](docs/04-shelly-failsafe.md) | Shelly setup, BTHome sensor, failsafe script |
| [`docs/05-weather-compensation.md`](docs/05-weather-compensation.md) | The control law and its tunables |
| [`docs/06-staged-handover.md`](docs/06-staged-handover.md) | Stages, promotion, demotion, learning |
| [`docs/07-dashboard.md`](docs/07-dashboard.md) | Dashboard |
| [`enclosure/`](enclosure/) | 3D-printable wall box for the Shelly and the stick (OpenSCAD + STLs) |
| [`docs/testing.md`](docs/testing.md) | Failsafe tests to pass before going live |
| [`docs/results.md`](docs/results.md) | What happened, and the final learned curve |
| [`shelly/failsafe.js`](shelly/failsafe.js) | Shelly script |
| [`nodered/`](nodered/) | Example Node-RED flows (sanitised) |
| [`homeassistant/`](homeassistant/) | HA helper package and dashboard YAML |
| [`PLACEHOLDERS.md`](PLACEHOLDERS.md) | Placeholders to replace with your own values |
| [`tools/pin-ebusd-config.py`](tools/pin-ebusd-config.py) | Pins the ebusd definitions so only `SetMode` is writable |
| [`tools/setmode-check.py`](tools/setmode-check.py) | Stage 1 checkpoint: checks one `SetMode` on the real boiler and times how long it holds |
| [`tools/scan-secrets.sh`](tools/scan-secrets.sh) | Pre-push check for IPs, keys and personal data |

## Disclaimer

Working inside a boiler is dangerous: it has mains voltage and is a gas
appliance. Isolate it before opening any cover. In the UK, only a Gas Safe
registered engineer may work on gas parts. This guide covers only the
low-voltage control terminals. Use it at your own risk.

## Licence

[MIT](LICENSE).
