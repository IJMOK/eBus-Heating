# Placeholder convention

Nothing in this repo is copied from a real installation. Replace these values
with your own.

## Values: `<UPPER_SNAKE>` in angle brackets

| Placeholder | Meaning |
|---|---|
| `<STICK_IP>` | eBUS Adapter Stick C6 IP address |
| `<SHELLY_IP>` | Shelly 1 Gen4 IP address |
| `<HA_HOST>` | Home Assistant host name or IP |
| `<MQTT_USER>` / `<MQTT_PASSWORD>` | Mosquitto credentials |
| `<BTHOME_KEY>` | Shelly BLU H&T encryption key |
| `<BLU_MAC>` | Shelly BLU H&T MAC address |
| `<SHELLY_MQTT_PREFIX>` | The Shelly's MQTT topic prefix (default: its device id, e.g. `shelly1g4-<mac>`) |
| `<NOTIFY_SERVICE>` | Your phone's notify service, e.g. `notify.mobile_app_<phone>` |
| `<WEBHOOK_ID>` | A long random ID for the failsafe-mode webhook (kept in `secrets.yaml`) |

## Entity IDs: generic names

| Entity | Meaning |
|---|---|
| `sensor.outdoor_temperature` | Outdoor temperature (e.g. Met Office) |
| `sensor.room_temperature` | Master room sensor |
| `switch.heating_relay` | Shelly relay across boiler terminals 3-4 |
| `sensor.ebusd_flow_temperature` | Actual flow temperature from eBUS |
| `sensor.ebusd_return_temperature` | Actual return temperature from eBUS |
| `input_select.heating_stage` | Handover stage 0-3 |
| `input_number.heating_*` | Tunables (slope, offset, Kp, Ki, stage floor, setpoints) |
| `input_boolean.heating_dry_run` | Calculate and log only; no writes |

Entity IDs created by ebusd's MQTT discovery depend on your boiler. Map them
once in the Node-RED flows' config node.

## Allowed IP addresses

Only `127.0.0.1`, `0.0.0.0`, the documentation range `192.0.2.0/24` and
the factory setup addresses of the eBUS stick (`192.168.4.1`) and the Shelly (`192.168.33.1`) may
appear in this repo. [`tools/scan-secrets.sh`](tools/scan-secrets.sh) flags
everything else.
