# Failsafe tests

> Written in P5, before going live.

| Test | Expected | Result |
|---|---|---|
| Pull stick power | ebusd watchdog: room-stat mode at panel 60 °C, notification | |
| Stop Home Assistant | Shelly heartbeat goes stale; local thermostat after 15 min | |
| Power-cycle the Shelly | Comes back in its configured power-on state (not off), script runs | |
