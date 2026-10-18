# Dashboard

[`homeassistant/dashboards/heating.yaml`](../homeassistant/dashboards/heating.yaml):
create a new dashboard → Edit → Raw configuration editor → paste it, then swap in
your entity IDs.

| Section | Shows |
|---|---|
| **Now** | Status line, for example `S1 \| LIVE \| period \| set 19.5 \| room 19.3 \| out 4.2 \| curve 52.6 \| target 52.6 (curve) \| demand ON`. Also stage, live/dry-run, floor, slope, offset, days to promotion, and the last decision with its reason. Tiles: room, set, outdoor, flow target, flow, return, demand, flame, modulation, burner minutes today, Comfort-mode button and timer |
| **Room and weather** | 48 h of room against set, and outdoor |
| **Boiler** | 24 h of flow target, the unclamped curve, actual flow and return; modulation; heating period, demand and flame |
| **Handover** | Heating season, stage, live switch, good days, comfort event today, Approve-promotion button, integral |
| **Tuning / Schedule** | All tunables, setpoints, preheat, hold, boost, schedule times, next phone alarm |
| **Boiler health** | Water pressure, heating starts and hours, eBUS signal, room sensor battery |

The values that come from Node-RED (flow target, curve, modulation, flame,
demand, period, burner minutes, failsafe mode, next heating block) are helpers in
[`packages/heating.yaml`](../homeassistant/packages/heating.yaml), so they get
history like any sensor.
