# Failsafe tests

Run these **before** the relay goes live: Shelly fitted on the boiler's 24V= RT
terminals, script running, HA in live control at Stage 0. Write the result and
the date in the last column. Repeat after any firmware or flow change.

| # | Test | How | Expected | Result |
|---|---|---|---|---|
| 1 | Relay switches the boiler | Toggle the Shelly in HA (heating on at the panel) | Boiler fires / stops; `DCRoomthermostat` follows (on = closed) | |
| 2 | Power cut | Switch off the boiler's spur 10 s, back on | Shelly comes back with the relay **ON**; script runs; mode `ha` once the heartbeat arrives | |
| 3 | Soft restart | Shelly → Reboot | Relay keeps its state; script runs; mode `ha` | |
| 4 | HA/Node-RED stops | Stop the Node-RED add-on | After 15 min mode `local`; relay follows the BLU (on < 19.5, off > 20.5 in periods) | |
| 5 | HA back | Start Node-RED | Mode `ha` within 1 min; notification "HA is back in control"; HA sets the relay | |
| 6 | Dry-run hands over | Turn `heating_live` off | Heartbeat stops; after 15 min mode `local` | |
| 7 | BLU lost too | Take a battery out of the BLU (with Node-RED stopped) | After 30 min mode `timed`; relay follows the fixed schedule | |
| 8 | eBUS stick unplugged | Pull the stick's USB power | After 10 min notification "eBUS lost"; status `eBUS DOWN`; target 60, no writes; relay keeps room control | |
| 9 | eBUS back | Plug the stick in | Notification "eBUS is back"; values update | |
| 10 | Wi-Fi down | Switch the Shelly's AP off at the router (or power the router off) | Mode `local` after 15 min, heating carries on | |
| 11 | Comfort mode | Press the dashboard button | Timer 4 h; target 60; demand on until day set + 1 °C; notification | |

Restore everything after each test (battery back in, add-ons running, `heating_live` back on).

## Bench results (relay not wired)

| Date | Test | Result |
|---|---|---|
| 2026-10-17 | Power cut (12 V supply unplugged 10 s) | Relay came back **ON** (`reset_reason` 1) ✅ |
| 2026-10-17 | Soft restart | Relay kept its state (`reset_reason` 3); a script not set to run on startup stays stopped ✅ (as expected) |
| 2026-10-17 | Script on real firmware (2.0.1) | Runs, about 1.5 KB memory, mode `ha` during the 15-min grace period ✅ |
| 2026-10-17 | No heartbeat (HA in dry-run) | After 15 min: mode **`local`**, relay off at 23 °C (> 20.5) ✅ |
| 2026-10-17 | Mode to HA | Retained MQTT → Node-RED → `input_text.heating_failsafe_mode` = `local`, logbook entry and notifications ✅ |
