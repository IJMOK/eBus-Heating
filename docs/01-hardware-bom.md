# Hardware and parts list

| Part | Job | Notes |
|---|---|---|
| **Vaillant ecoTEC** boiler (tested: an 800-series combi, eBUS ID `BAI00`) | The boiler | No Vaillant controller on the eBUS. The front-panel heating flow temperature stays the **hard ceiling** |
| **eBUS Adapter Stick C6** ([adapter.ebusd.eu](https://adapter.ebusd.eu/v5-c6/stick.en.html)) | Reads the boiler and sends the flow setpoint | Wi-Fi to the host, own USB-C 5 V supply (≥ 2 W), eBUS connector included, galvanically isolated, polarity-free |
| **Shelly 1 Gen4** | Heat-demand relay across the boiler's 24 V room-stat terminals, runs the failsafe script, Bluetooth proxy | Dry (potential-free) contacts. Powered 110–240 V AC, 24–48 V DC or 12 V DC. Use it in Wi-Fi mode, not Zigbee |
| **Shelly BLU H&T Display ZB** | Master room temperature | Bluetooth mode only (it can't do Bluetooth and Zigbee at once). 2 × CR2032. About 10 m indoor range to the Shelly |
| **Home Assistant** with Mosquitto, Node-RED and the ebusd add-on | Runs the control | Outdoor temperature from the Met Office integration (any outdoor sensor works) |
| 2-core cable, 0.5–0.75 mm² | Boiler eBUS terminals to the stick | |
| 12 V DC plug-in supply (optional) | Configure the Shelly on the bench without mains wiring | Must be stabilised DC |

## Why these parts

- **eBUS rather than OpenTherm:** Vaillant ecoTEC boilers speak eBUS natively, so
  you read flow and return temperatures, modulation and faults, and set the flow
  temperature, with no extra bridge in the boiler.
- **A relay as well as eBUS:** the relay gives a simple on/off path that keeps
  working when eBUS, ebusd or Home Assistant doesn't. The boiler then just runs
  at its own panel setting.
- **The Shelly runs the failsafe locally:** it has the room sensor bound
  directly, so it can keep the house warm with no network at all.
- **The BLU H&T** talks to the Shelly over Bluetooth, and HA reads it through the
  Shelly acting as a Bluetooth proxy, so no extra Bluetooth hardware is needed.

## Not used

- **Shelly Plus Add-on / DS18B20 probes:** flow and return temperatures come from
  eBUS instead.
- **micro-ebusd** (ebusd on the stick, paid token): a valid alternative to the
  ebusd add-on, but never run both. See [03-ebusd-setup.md](03-ebusd-setup.md).
