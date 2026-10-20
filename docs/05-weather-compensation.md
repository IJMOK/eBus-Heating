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
| **Warm-up boost** | The first 45 min of each heating period (`heating_boost_minutes`), and with optimum start on, the whole warm-up until the "warm by" time |
| **Comfort mode** | Dashboard button: 4 h at 60 °C, at least the Home temperature. Calls for heat until 1 °C above set |
| **Comfort guard** | Room more than 1 °C below set for 30 min while the curve is limiting the flow. Stays at 60 °C until within 0.3 °C. Counts as a **comfort event** |
| **Outdoor temperature missing** | Holds the last value. If there has never been one, 60 °C |
| **eBUS down** | No boiler data for 10 min. The boiler runs at its panel setting and nothing is written |

## Heat demand (the relay)

Hysteresis on the room temperature: **on below set − 0.2 °C, off above set + 0.2 °C**.
**Heating season** (`input_boolean.heating_season`) off = summer: no demand at all except
the comfort button, and the Shelly failsafe holds the relay off too.
If the room sensor goes stale (no temperature or humidity update for 90 min), the
relay follows the schedule like a timer. HA only records a reading when the value
changes, so a steady room can be quiet for half an hour or more; the longer limit
stops that looking like a dead sensor. A sensor that really dies is caught sooner
by the Shelly, which sees every packet (failsafe mode `timed` after 30 min).

## Schedule

Every weekday has a **day type** (`input_select.heating_day_mon` … `_sun`: Work, Home or
Out). Each period has its own times and temperature:

| Day type | Heating periods |
|---|---|
| **Work**, with a phone alarm today | Warm by the earliest alarm, until `latest alarm + hold`, at `heating_work_morning_temp`; then `heating_work_evening_start` to `heating_work_end` at `heating_work_evening_temp` |
| **Work**, no alarm today | Runs as a Home day |
| **Home** | `heating_home_start` to `heating_home_end` at `heating_home_temp` |
| **Out** | Evening only: `heating_out_start` to `heating_out_end` at `heating_out_temp` |
| **Off** (calendar only) | No period: the night temperature all day |

Outside the periods the house holds `heating_setpoint_night`.

**Calendar overrides:** an event in a calendar called **Heating** whose title starts with
`Home`, `Work`, `Out` or `Off` sets the day type of every date it covers (all-day events are
easiest). `sensor.heating_calendar_days` reads it every 15 minutes for today and the next two
days; its state says `no calendar` until the calendar exists. Precedence: **away > calendar >
holiday at home > the week**.

**Holiday at home** (`input_boolean.heating_holiday_home`): every day is a Home day and phone
alarms are ignored, e.g. over Christmas. A calendar event still changes a single date.

**Away** (`input_boolean.heating_away`): holds `heating_away_temp` (16 °C) all day. With a
return time in `heating_away_return`, it warms up so the house is at the Home temperature by
then: the learned warm-up rate from the current room temperature, up to 6 hours early
(coming back from 16 °C takes longer than a normal morning). The warm-up runs at 60 °C
and is learned from like any other. At the return time Away switches itself off and the
schedule takes over. Away days don't count in the nightly review. Without a return time
it holds until you switch it off. If HA is down while you're away, the Shelly failsafe
runs its own schedule (warmer than needed, never colder).

When each period starts depends on **optimum start** (`input_boolean.heating_optimum_start`):

- **Off** (default): the morning starts a fixed `heating_preheat_minutes` before the alarm;
  the other periods start at their times.
- **On**: every period starts just early enough to be at its temperature by its time:
  `(period temperature − room) ÷ warm-up rate + 10 min`, at most `heating_preheat_max` (120 min)
  early. Already warm means no prestart; a mild day (faster rate) starts later. Once a
  period has started it stays on. Warm-ups run at 60 °C, so the rate stays valid whatever
  stage the curve is at.
- **The warm-up rate is learned in both modes** from real warm-ups (live, a period starting
  with the room 0.5 °C or more below its temperature, until it reaches that − 0.2 °C), in four
  outdoor bands (below 0, 0-5, 5-10, above 10 °C). It starts from cautious guesses of
  1.0 / 1.3 / 1.6 / 2.0 °C/h and moves 30 % towards each new result. Each warm-up goes to
  the logbook, and `input_text.heating_warmup` shows the rates. With it off, the hall
  board and `heating_next` show when optimum start *would* have begun, so you can compare
  before switching it on.

Helpers: `heating_preheat_minutes` (60), `heating_preheat_max` (120), `heating_alarm_hold_minutes` (60).
Starting values ("Set starting values" button): all period temperatures 19.5 °C; Work evening
16:00–22:30, Home 09:00–22:30, Out 17:30–22:30; Monday to Friday Work, weekends Home.

- Alarms come from each phone's **next alarm** sensor, if they fall today
  between 04:00 and 10:00. The earliest is the "warm by" time and the latest sets the
  end of the morning. Each is remembered after it has rung.
- If every phone sensor is unavailable on a weekday, the flow assumes 06:00, unless
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
