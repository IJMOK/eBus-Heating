# eBUS stick and ebusd setup

Goal: the boiler's eBUS data appears in Home Assistant through MQTT discovery,
**read-only**. Nothing is written to the boiler in this step.

```
boiler eBUS ──2 wires──► eBUS Adapter Stick C6 ──Wi-Fi, TCP :9999──► ebusd add-on ──► Mosquitto ──► HA (MQTT discovery)
```

Sources: [stick](https://adapter.ebusd.eu/v5-c6/stick.en.html),
[first steps](https://adapter.ebusd.eu/v5-c6/steps.en.html),
[firmware](https://adapter.ebusd.eu/v5-c6/firmware.en.html),
[ebusd add-on](https://github.com/LukasGrebe/ha-addons/blob/main/ebusd/DOCS.md).

## 1. Update the firmware (USB, on your desk)

The stick ships with firmware already on it, but it may be old. WPS setup needs
firmware from 2024-10-27 or later. Update it over USB before anything else.

1. On a PC, open <https://adapter.ebusd.eu/v5-c6/firmware.en.html#flash> in
   **Chrome or Edge**. The flasher uses Web Serial; Firefox and Safari can't run it.
2. **Hold the stick's button while plugging in the USB-C cable** (bootloader mode).
3. Choose the newest firmware version → **Connect** → pick
   *USB JTAG/serial debug unit (COM…)* → **Install eBUS Adapter…**.
4. When it's done, unplug the USB briefly to leave bootloader mode.

## 2. Join it to Wi-Fi

Choose one of these:

| Method | How |
|---|---|
| **Flasher (easiest)** | With the stick plugged into USB, click **Connect** again on the firmware page → *Connect to network* → choose your SSID and enter the password. |
| **EBUS access point** | An unconfigured stick, or one whose button was held during boot, opens an **open** Wi-Fi network called `EBUS`. Join it and browse to <http://192.168.4.1>. |
| **WPS** | Unconfigured stick: press the button once after boot (the red LED stays on), then press WPS on the router. |

Then:

- Give the stick a **DHCP reservation** in your router. ebusd connects by IP, so
  this is `<STICK_IP>` from now on.
- The `EBUS` access point has no password. Check it is gone once the stick has
  joined your Wi-Fi.
- Plug it into its own **5 V USB supply rated at least 2 W (400 mA)**. Don't power
  it from anything inside the boiler.

### Check it from your PC

The stick serves a status JSON (read-only):

```sh
curl http://<STICK_IP>/api/v1/status
```

| Field | What to look for |
|---|---|
| `build` | Firmware date, should be the newest on the firmware page |
| `sta.rssi` | Wi-Fi signal: better than about −70 dBm is fine |
| `ap.on` | `false`, so the open setup network is off |
| `ebus.signal` | `true` once it's wired to the boiler |
| `busCount[0]` | Bytes received from the eBUS, should keep rising |
| `ebus.connected` | `true` once ebusd is connected to it |

### Reading the LEDs

| LED | Meaning |
|---|---|
| All except green fade 3× | Booting |
| Green **on** | Powered, **no eBUS** connected |
| Green **off** | eBUS connected, voltage OK, no traffic |
| Green **flashing** | eBUS connected and traffic seen ✅ |
| Red solid after a button press | WPS waiting |

| Button | Effect |
|---|---|
| Held while powering on | Bootloader (flashing) |
| Held during boot (LEDs fading) | Ignore saved settings, start the `EBUS` access point |
| Held after boot | Reboot |

## 3. Wire it to the boiler

See [02-wiring-safety.md](02-wiring-safety.md). It's 2 wires, polarity doesn't
matter, and the stick is galvanically isolated and draws almost nothing from the
bus. Once connected, the **green LED should start flashing**. With no Vaillant
controller on the bus there's less traffic, but the boiler itself still talks.

## 4. Install the ebusd add-on

> Use **either** this add-on **or** micro-ebusd on the stick (see below),
> never both. Two masters on one bus will collide.

1. HA → Settings → Add-ons → Add-on store → ⋮ → Repositories → add
   `https://github.com/LukasGrebe/ha-addons` → install **ebusd**.
2. Configuration:

   ```yaml
   network_device: "ens:<STICK_IP>:9999"   # ens = enhanced protocol, high speed
   seed_mqtt_cfg: true                      # adds --mqttint=mqtt-hassio.cfg and --mqttjson
   commandline_options:
     - "--scanconfig"
     - "--pollinterval=30"
     - "--httpport=8889"                    # read-only JSON: http://<HA_HOST>:8889/data
   ```

   In the add-on's Configuration tab (UI mode) `commandline_options` is a list with
   **one flag per entry**: type `--scanconfig`, not `- "--scanconfig"`. Pasting the YAML
   lines into the entries passes the dashes and quotes to ebusd, which then refuses to
   start (`invalid arguments`).

   - The Mosquitto add-on's host, user and password are picked up automatically.
     Don't set `--mqtthost` unless you're using an external broker.
   - No `--accesslevel` yet: without it ebusd can't write to the boiler at all.
     See the access-level section below for when to add it (with pinned definitions).
   - Checked on add-on 26.1.8. The schema has changed between versions, so compare
     the option names with the add-on's Configuration tab.
3. Start it and watch the log. You want to see:
   - `started with auto scan on enhanced device`
   - `device status: reset, supports info`
   - a scan result naming the boiler, e.g. `address 08: slave #… , scanned "MF=Vaillant;ID=BAI00;…"`

## 5. Check it from the command line (optional)

From the add-on's container, or any host that can reach port 8888:

```sh
ebusctl info          # signal, adapter, scanned devices
ebusctl find          # every message ebusd has a definition for
ebusctl read -c bai FlowTemp
```

## 6. Entities in Home Assistant

MQTT discovery creates a device for the boiler (`bai`) with sensors such as flow
and return temperature, modulation and burner status. The exact entity IDs depend
on the boiler and the ebusd config version. Map them once, see
[PLACEHOLDERS.md](../PLACEHOLDERS.md).

### What a stand-alone ecoTEC reports

Seen on an ecoTEC with no Vaillant controller (scan: `MF=Vaillant; ID=BAI00`,
ebusd 26.1). Read the data yourself with `curl http://<HA_HOST>:8889/data`, and
the definitions with `curl "http://<HA_HOST>:8889/data/bai?def&write"`.

| Use | ebusd message (`bai`) | Notes |
|---|---|---|
| Actual flow | `FlowTemp` | `temp` and `sensor` fields |
| Flow setpoint in use | `FlowTempDesired` | Shows the panel setting when nothing else is commanding it |
| Return | `ReturnTemp` | |
| Burner | `Flame`, `ModulationDesired` | |
| Heat demand on terminals 3-4 | `DCRoomthermostat` | `on` = contact closed. Handy to confirm the relay works |
| Pressure | `WaterPressure` | |
| Hot water | `StorageTemp`, `StorageTempDesired`, `HwcImpellorSwitch` | ebusd uses the same names for every ecoTEC. On a **combi** "Storage" is the hot-water outlet sensor and setpoint, not a tank; `HwcImpellorSwitch` is the tap-flow sensor |
| Counters | `HcStarts`, `HcHours`, `HwcStarts`, `PrEnergySumHc1` … | |
| Faults | `Currenterror`, `Errorhistory` | |

The bus should show `"masters": 2` in `global` (boiler + ebusd) if there is no
controller.

### The flow-setpoint write: `SetMode` (B5 10 00)

This is the message a Vaillant controller sends to the boiler. In ebusd's
config it is `bai SetMode` (newer configs call it `SetModeOverride`):

```
hcmode;flowtempdesired;hwctempdesired;hwcflowtempdesired;ign;disablehc;disablehwctapping;disablehwcload;ign_1;remotecontrolhcpump;releasebackup;releasecooling
```

- MQTT: publish the value string to `ebusd/bai/SetMode/set`.
- It carries **hot-water fields as well as heating**. On a combi,
  `disablehwctapping` = 1 means **no hot water at the taps**, and
  `hwctempdesired` overrides the panel's hot-water setting. Send the hot-water
  setpoint your panel already uses, with both disable bits at 0.
- The boiler drops back to its own settings if the message isn't repeated, so
  the control flow re-sends it every few minutes.

### ⚠️ `--accesslevel=*` exposes installer parameters

With `--accesslevel=*`, ebusd will also write installer settings such as
`FlowsetHcMax`, `PartloadHcKW`, fan-speed offsets and **`SetFactoryValues`**.
Anything that can publish to the broker can then change them, and depending on
`mqtt-hassio.cfg` they may show up as controls in HA.

On the BAI00 tested here, the active `SetMode` write sits at access level `install`
upstream, and the installer settings at `install_NOT_YET_CONFIRMED`. ebusd matches
levels as whole words, so `--accesslevel=install` would unlock only `SetMode` today.
But an upstream config update that confirms those settings would quietly unlock them
too. So:

- **Until you start writing (shadow stage): leave `--accesslevel` off.** ebusd
  then can't write anything, whatever a flow or dashboard does. Check with
  `curl "http://<HA_HOST>:8889/data/bai?def&write"`: only passive messages
  should have `"write": true`.
- **When you start writing: pin the definitions and give `SetMode` its own level.**
  [`tools/pin-ebusd-config.py`](../tools/pin-ebusd-config.py) mirrors the definitions
  ebusd loads today (top-level and Vaillant CSVs plus their includes) into a folder and
  changes one line: the active `SetMode` write moves from `install` to `heating`.

  ```sh
  python tools/pin-ebusd-config.py ebusd-config        # then copy the folder to the add-on's
                                                       # config share (addon_configs/<slug>_ebusd/)
  ```

  Add two entries to the add-on's `commandline_options` (`/config/` in the add-on is
  `addon_configs/<slug>_ebusd/` on the host):

  ```yaml
     - "--configpath=/config/ebusd-config/"
     - "--accesslevel=heating"
  ```

  Restart the add-on and check:
  - the log has the same scan result as before and no `ERR` loading files;
  - `curl "http://<HA_HOST>:8889/data/bai/SetMode?def"` still shows the message, and
    the number of `messages` in `http://<HA_HOST>:8889/data` matches the count from before;
  - `mqtt-hassio.cfg` keeps `filter-level = ^$`, so `SetMode` (level `heating`) never
    becomes an HA entity. Writes go only to `ebusd/bai/SetMode/set` from the flow.

  The definitions no longer update by themselves: re-run the tool, diff and redeploy
  when you want upstream changes.

## Alternative: micro-ebusd

The stick can run ebusd itself (**micro-ebusd**, needs a paid token from the
adapter's website) and publish straight to MQTT, with no add-on. It's simpler but
less configurable. If you use it, **don't** run the ebusd add-on as well.
