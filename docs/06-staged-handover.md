# Staged handover

The curve takes over from "60 °C on demand" in four stages
(`input_select.heating_stage`). A nightly review at 03:00 learns and checks for
promotion. **It never promotes by itself**: you get a notification with an
**Approve** button, and there's a matching dashboard button. Any comfort event
demotes one stage straight away.

| Stage | Flow | stage_floor | Learning | Exit |
|---|---|---|---|---|
| **0 Shadow** | Fixed 60 °C (panel). Relay on/off by room temperature. Curve logged only | — | none | Live control on **and** 7 heating days logged |
| **1 Capped** | Curve, floor 50 °C, so it barely differs from 60 | 50 | **raise-only** | 7 good days **and** a cold snap passed: ≥ 2 consecutive days with mean outdoor ≤ 2 °C and no comfort events |
| **2 Assisted** | Curve | 45 → 40 → 35, one step per promotion | asymmetric | 7 good days per step. At 35, the next promotion goes to Stage 3 |
| **3 Auto** | Curve | 30 | asymmetric, slope clamped 0.8–2.0 | — |

## Definitions

| Term | Meaning |
|---|---|
| Heating day | Heat demand on for ≥ 60 min that day |
| Good day | A heating day with no comfort event, room within ±0.5 °C of set for ≥ 90 % of occupied minutes, and < 30 min more than 0.5 °C below set. Occupied minutes exclude boosts and hot-water draws |
| Short day | A heating day with a comfort event, or ≥ 30 occupied minutes more than 0.5 °C below set |
| Good-day counter | Stage 0: live heating days. Stage 1+: **consecutive** good heating days. A short day resets it; a non-heating day leaves it alone |

## Learning (nightly)

| Stage | After a short day | After a good day |
|---|---|---|
| 1 | raise | — |
| 2, 3 | raise | lower |

- **Raise:** if the day's mean outdoor temperature was below 5 °C, **slope +0.1**;
  otherwise **offset +2 °C**.
- **Lower:** **offset −1 °C** until it reaches 0, then **slope −0.05**. The floor
  only comes down through promotions.

Every decision and its reason goes to `input_text.heating_last_decision` and the
logbook.

## Demotion

A comfort event:
- drops one stage (Stage 0 is the bottom), with the floor for that stage
  (Stage 1: 50, Stage 2: 35)
- resets the good-day counter
- marks the day and notifies you.

The comfort guard keeps the flow at 60 °C until the room recovers.

## Manual control

- **Comfort mode** button: 60 °C for 4 hours.
- **Heating season** off (summer): no heat demand at all except comfort mode, and
  the Shelly failsafe keeps the relay off too.
- **Before the first Stage 1 write**, check one `SetMode` by hand on your boiler
  (flow setpoint taken, hot water unchanged), then set `ebusWriteEnabled: true` in
  the Heating config node.
- You can set `heating_stage`, the floor and the tunables by hand at any time.
- **Set starting values** (Node-RED tab 42) resets everything to Stage 0 with the
  starting tunables.
