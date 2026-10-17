# Weather compensation control law

Every 60 s Node-RED works out a flow temperature for the boiler:

```
flow  = set + slope × (set − outdoor) + offset + Kp × err + I        err = set − room
final = clamp(flow, stage_floor, 60)
```

- **set**: the room setpoint now. The day value during heating periods, the
  night setback otherwise.
- **slope × (set − outdoor)**: the weather curve. Colder outside means a hotter flow.
- **offset**: shifts the whole curve.
- **Kp × err**: a quick nudge for the room error now.
- **I**: the integral. It adds `Ki × err` every minute and is clamped to ±5 °C.
  It only runs from Stage 1, while there is heat demand and the curve is in
  charge, so it can't wind up during boosts, hot water or overrides.
- **60 °C** is the boiler's own front-panel setting and the hard ceiling. Nothing
  can go above it.
- **stage_floor** is the lowest flow the current handover stage allows. See
  [06-staged-handover.md](06-staged-handover.md).

## Starting values

| Tunable | Start | Helper |
|---|---|---|
| slope | 1.8 | `input_number.heating_slope` |
| offset | +5 °C | `input_number.heating_offset` |
| Kp | 3 | `input_number.heating_kp` |
| Ki | 0.02 per min | `input_number.heating_ki` |
| I clamp | ±5 °C | fixed |

With a 19.5 °C setpoint and the room on target, that gives about **60 °C at
−3 °C outside, 50 °C at +3 °C, and 43 °C at +10 °C**. That's a house that is
comfortable all year at a 60 °C flow, eased off as it gets milder.

## Overrides (flow 60 °C)

| Override | When |
|---|---|
| **Warm-up boost** | The first 45 min of each heating period (`heating_boost_minutes`) |
| **Comfort mode** | Dashboard button: 4 h at 60 °C on the day setpoint. Calls for heat until 1 °C above the day setpoint |
| **Comfort guard** | Room more than 1 °C below set for 30 min while the curve is limiting the flow. Stays at 60 °C until within 0.3 °C. Counts as a **comfort event** |
| **Outdoor temperature missing** | Holds the last value. If there has never been one, 60 °C |
| **eBUS down** | No boiler data for 10 min. The boiler runs at its panel setting and nothing is written |

## Heat demand (the relay)

Hysteresis on the room temperature: **on below set − 0.2 °C, off above set + 0.2 °C**.
If the room sensor goes stale (> 30 min), the relay follows the schedule like a
timer.

## Schedule

| Day | Heating periods (day setpoint) |
|---|---|
| Weekday with a phone alarm today | `alarm − preheat` to `alarm + hold`, then evening start to period end |
| Weekday without an alarm | Weekend start to period end |
| Weekend | Weekend start to period end |

Helpers: `heating_preheat_minutes` (60), `heating_alarm_hold_minutes` (60),
`heating_weekday_evening_start` (16:00), `heating_weekend_start` (09:00),
`heating_period_end` (22:30).

- The alarm comes from the phone's **next alarm** sensor, if it falls today
  between 04:00 and 10:00. It is remembered after it has rung.
- If the phone sensor is unavailable on a weekday, the flow assumes 06:00, unless
  an "alarm off" calendar has an entry active now.

## Combi boilers and hot water

While a tap is running the boiler is in hot-water mode, so the flow readings
aren't heating data. The integral and the comfort-guard timer pause while
`HwcDemand` or `HwcImpellorSwitch` shows a draw.

## Sending the flow temperature

`bai SetMode` over MQTT (`ebusd/bai/SetMode/set`), re-sent every 4 minutes and
on every change. It always carries the boiler's hot-water setting, with both
hot-water disable bits off. See [03-ebusd-setup.md](03-ebusd-setup.md).
Writes are off until the Stage 1 checkpoint, which verifies the payload on the
real boiler.
