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
     - "--accesslevel=*"
     - "--pollinterval=30"
   ```

   - The Mosquitto add-on's host, user and password are picked up automatically.
     Don't set `--mqtthost` unless you're using an external broker.
   - `--accesslevel=*` makes every message definition visible, including
     the install-level writes we need later. Visible is not the same as written:
     nothing is written until a flow does it.
   - *Untested:* check the option names against the add-on's Configuration tab,
     because the schema has changed between versions.
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

*To be filled in from a real install:* the entity list and the write message for
the flow setpoint.

## Alternative: micro-ebusd

The stick can run ebusd itself (**micro-ebusd**, needs a paid token from the
adapter's website) and publish straight to MQTT, with no add-on. It's simpler but
less configurable. If you use it, **don't** run the ebusd add-on as well.
