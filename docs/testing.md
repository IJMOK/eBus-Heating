# Failsafe tests

Run these **before** the relay goes live: Shelly fitted on the boiler's 24V= RT
terminals, script running, HA in live control at Stage 0. Write the result and
the date in the last column. Repeat after any firmware or flow change.

| # | Test | How | Expected | Result |
|---|---|---|---|---|
| 1 | Relay switches the boiler | Toggle the Shelly in HA (heating on at the panel) | Boiler fires / stops; `DCRoomthermostat` follows (on = closed) | 2026-10-18 ✅ contact closed, flame on after ~30 s (17 % modulation), flow 25.9 → 32.4 °C; off stopped it |
| 2 | Power cut | Switch off the boiler's spur 10 s, back on | Shelly comes back with the relay **ON**; script runs; mode `ha` once the heartbeat arrives | 2026-10-18 ✅ back in ~25 s, relay ON, script running, mode `ha`. HA showed a stale "off" for ~90 s until the Shelly integration reconnected (fix: relay re-sent every 5 min) |
| 3 | Soft restart | Shelly → Reboot | Relay keeps its state; script runs; mode `ha` | 2026-10-18 ✅ relay kept off, script running in seconds, mode `ha`; HA reconnected in ~50 s |
| 4 | HA/Node-RED stops | Stop the Node-RED add-on | After 15 min mode `local`; relay follows the BLU (on < 19.5, off > 20.5 in periods) | 2026-10-18 ✅ last heartbeat 06:47, mode `local` at 07:02 (15 min); relay off (setback, room 19 °C) |
| 5 | HA back | Start Node-RED | Mode `ha` within 1 min; notification "HA is back in control"; HA sets the relay | 2026-10-18 ✅ mode `ha` 24 s after the first heartbeat; notification arrived. Mode changes while Node-RED was down never reached HA (nothing to relay them) |
| 6 | Dry-run hands over | Turn `heating_live` off | Heartbeat stops; after 15 min mode `local` | 2026-10-18 ✅ last heartbeat ~07:43:30, mode `local` at 07:58:52 (15 min); logbook + notification |
| 7 | BLU lost too | Take a battery out of the BLU (with Node-RED stopped) | After 30 min mode `timed`; relay follows the fixed schedule | 2026-10-18 ✅ last packet 07:05:55, mode `timed` at 07:35:59; battery back → `local` within a minute |
| 8 | eBUS stick unplugged | Pull the stick's USB power | After 10 min notification "eBUS lost"; status `eBUS DOWN`; target 60, no writes; relay keeps room control | 2026-10-18 ✅ "eBUS lost" ~30 s after unplugging (ebusd signal off; the 10-min FlowTemp check is the backstop); `eBUS DOWN`, target 60 |
| 9 | eBUS back | Plug the stick in | Notification "eBUS is back"; values update | 2026-10-18 ✅ signal back 08:02:51, "eBUS is back" at 08:03:32 |
| 10 | Wi-Fi down | Switch the Shelly's AP off at the router (or power the router off) | Mode `local` after 15 min, heating carries on | 2026-10-18 ✅ Shelly MAC-banned 17 min: no reboot, script kept running, mode `local`, reconnected in seconds. HA kept showing `ha` (mode change made offline was never published; fixed: the script re-publishes on MQTT reconnect) |
| 11 | Comfort mode | Press the dashboard button | Timer 4 h; target 60; demand on until set + 1 °C; notification | 2026-10-18 ✅ after two fixes (dashboard tile used `toggle` on an input_button; Node-RED ignored the first-ever press from `unknown`): timer 4 h, set 19.5, demand ON, notification |

Restore everything after each test (battery back in, add-ons running, `heating_live` back on).

## Stage 1 checkpoint: SetMode

Run once, before setting `ebusWriteEnabled: true`, with
[`tools/setmode-check.py`](../tools/setmode-check.py). The heating must be calling,
so raise the set point a little (stay within 0.5 °C of the room so it doesn't
count as a short day). Pass `--hwc` exactly as the panel shows it.

| Check | Expected | Result (2026-10-28, combi, panel 60 °C flow / 50 °C hot water, sent 55 °C) |
|---|---|---|
| ebusd echo on `ebusd/bai/SetMode` | Sent values, all disable bits 0 | ✅ `auto`, 55, 50, disable bits 0 |
| Boiler takes the target | `FlowTempDesired` = sent value | ✅ 60 → 55 within about 2 min, before the relay closed |
| Burner fires at it | Flame on, target still the sent value | ✅ relay on 19:03, flame on, 17 % modulation |
| Hot tap during the test | `HwcDemand` yes, normal hot water, back to heating after | ✅ flow up to about 64 °C during the draw (boiler's own hot-water control), heating resumed when the tap closed |
| Stop sending | Boiler goes back to its own target by itself | ✅ back to 60 about 15 min after the last send (19:08 → 19:23), so no extra failsafe needed |

## Bench results (relay not wired)

| Date | Test | Result |
|---|---|---|
| 2026-10-17 | Power cut (12 V supply unplugged 10 s) | Relay came back **ON** (`reset_reason` 1) ✅ |
| 2026-10-17 | Soft restart | Relay kept its state (`reset_reason` 3); a script not set to run on startup stays stopped ✅ (as expected) |
| 2026-10-17 | Script on real firmware (2.0.1) | Runs, about 1.5 KB memory, mode `ha` during the 15-min grace period ✅ |
| 2026-10-17 | No heartbeat (HA in dry-run) | After 15 min: mode **`local`**, relay off at 23 °C (> 20.5) ✅ |
| 2026-10-17 | Mode to HA | Retained MQTT → Node-RED → `input_text.heating_failsafe_mode` = `local`, logbook entry and notifications ✅ |
| 2026-10-17 | Live control on (`heating_live`) | Heartbeat over MQTT RPC; Shelly back to **`ha`** within 30 s; "HA is back in control" logged; HA kept the relay off (room above set) ✅ |
| 2026-10-17 | Live control off again (test 6) | Heartbeat stopped; after **15 min** Shelly back to **`local`** ✅ |
