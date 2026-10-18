# Shelly relay and failsafe

The Shelly 1 Gen4 does three jobs:
1. **The heat-demand relay:** dry contacts across the boiler's 24 V room-stat terminals.
2. **The failsafe:** a script that runs the heating on its own when Home
   Assistant stops sending a heartbeat.
3. **A Bluetooth proxy** for the BLU H&T room sensor, so HA can read it.

> *Status:* configuration and the failsafe script tested on the bench (relay not
> wired): the switch from `ha` to `local` works on firmware 2.0.1. See [testing.md](testing.md).

## 1. Bench setup

Power it from a **12 V DC** supply (`+12V` and `⊥`) on the desk, so there's no
mains wiring yet. Leave `L`, `N`, `+`, `O`, `I` and `SW` empty.

1. Join `Shelly1G4-…`, browse to `http://192.168.33.1`, set Wi-Fi.
2. Update the firmware. Tested on **2.0.1**, which includes BTHome components.
3. DHCP reservation (or static IP) → `<SHELLY_IP>`.
4. Settings:

| Setting | Value | Why |
|---|---|---|
| Access point | **off** | It is open by default |
| Bluetooth RPC | **off** | Otherwise phones nearby can configure it without a password |
| Matter | off (unless you use it) | One less way in |
| Switch → power-on state | **On** | A power cut must never leave the heating off |
| Switch → input mode | **Detached** | The SW input isn't used |
| Input → factory reset | off | |
| Authentication | **set a password** | Anyone on your Wi-Fi could switch the heating |
| Mode | **Wi-Fi** (ships as Matter) | Never press the button 5× (that switches to Zigbee) |

> **Power-on state only applies to a real power cut.** After a software restart
> (firmware update, `Shelly.Reboot`) the relay keeps its previous state. Tested:
> power cut → ON (`reset_reason` 1); soft restart → unchanged (`reset_reason` 3).

> **Calling the Shelly's API with a password:** it uses HTTP digest with
> **SHA-256**. On Windows, `curl --digest` hands this to SSPI, which only does
> MD5, and fails with 401. Use a client that does SHA-256 digest, or RPC over MQTT.

## 2. Bind the BLU H&T

1. On the BLU, check the display shows Bluetooth, not Zigbee. Hold the button
   5 s to toggle Bluetooth, 10 s to toggle Zigbee. **30 s is a factory reset.**
2. Shelly web UI → **Components → Add device**. Press the BLU's button once while
   it scans. Add it with temperature, humidity and battery.
3. Note the temperature component id (e.g. `bthomesensor:203`) for the script.
4. Check the signal with `BTHomeDevice.GetStatus` (`rssi`, `last_updated_ts`).
   Better than about −85 dBm at its final position.
   **`Shelly.GetStatus` does not include BTHome components** (firmware 2.0.1). Use
   `BTHomeDevice.GetStatus` / `BTHomeSensor.GetStatus` or `Shelly.GetComponents`,
   otherwise a working sensor looks dead.
5. Add it as a **component only, don't pair it**. If it ends up under Bluetooth →
   *Paired devices*, delete it there. Paired, the Shelly keeps trying to connect to
   it, and readings drop out while connected.

## 3. Into Home Assistant

1. Add the Shelly integration (it's auto-discovered) and enter the password.
2. Integration options → **Bluetooth scanning: Passive**.
3. HA discovers the BLU through the **BTHome** integration. Add it.

## 4. MQTT (heartbeat and failsafe mode)

The heartbeat is an RPC call (`KVS.Set "hb"`) sent over MQTT, which avoids HTTP
digest auth in Node-RED.

Shelly → Settings → MQTT:
- server `<HA_HOST>:1883`, user and password of a Mosquitto login
- **RPC over MQTT on**, topic prefix left at its default (`<SHELLY_MQTT_PREFIX>`)

The script publishes its mode, retained, on `heating/failsafe/mode`.

## 5. The failsafe script

[`shelly/failsafe.js`](../shelly/failsafe.js). Settings are at the top of the file.

| Mode | When | What the relay does |
|---|---|---|
| `ha` | HA's heartbeat changed in the last **15 min** | Nothing: HA is in control |
| `local` | Heartbeat stale, BLU reading fresh (< 30 min) | Thermostat: on < 19.5 °C, off > 20.5 °C in schedule periods; on < 15.5, off > 16.5 outside them |
| `timed` | Heartbeat **and** BLU stale | On during the fixed schedule, off outside it |
| `warm` | No clock either | **On** |

- **Fixed schedule:** weekdays 05:00–07:00 and 16:00–22:30, weekends 09:00–22:30.
  It matches the main schedule without the phone alarm.
- **Staleness without a clock:** it's measured with the Shelly's uptime, so
  `local` mode works even before the clock is set.
- **After boot**, the script waits one full stale period (15 min) for a heartbeat
  before taking over.
- **HA only sends the heartbeat while it is in live control** and its control
  loop has run in the last 3 minutes. In dry-run, or if Node-RED stalls, the
  Shelly runs the heating itself. A wired relay is never left stuck.
- The mode is also kept in KVS `fs_mode`.
- **Out of season** (`input_boolean.heating_season` off), HA writes KVS `fs_season` =
  `false` (on a change and hourly, live or not) and the script keeps the relay **off** in
  `local`, `timed` and `warm`. Turning live control off is not a summer switch on its
  own: the failsafe would still heat on a cool evening.
- **Mode reaches HA without Node-RED.** Every mode change is published (retained) on
  MQTT, re-sent on each MQTT reconnect, and also POSTed to an HA webhook, retried every
  minute until HA accepts it. The automations in `homeassistant/packages/heating.yaml`
  set `input_text.heating_failsafe_mode` and notify on each change. To set it up, add
  a long random `heating_failsafe_webhook: <WEBHOOK_ID>` to `secrets.yaml`, restart
  HA (or reload automations), and store the URL on the Shelly:
  `KVS.Set {"key": "fs_webhook", "value": "http://<HA_HOST>:8123/api/webhook/<WEBHOOK_ID>"}`.
  Without the key the script just skips the webhook.

Load it with **Scripts → Add script**, or `Script.Create` + `Script.PutCode`.
Leave **"Run on startup" off** until the tests in [testing.md](testing.md) pass.

## 6. Wiring to the boiler

See [02-wiring-safety.md](02-wiring-safety.md). The Shelly's `O`/`I` replace the
wire link on the boiler's **24V= RT** terminals. It is powered from the boiler's
fused spur (`L`, `N`), and the 12 V bench supply is removed first.
