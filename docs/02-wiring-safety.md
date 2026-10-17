# Wiring and safety

> ⚠️ The boiler contains **230 V mains** and is a **gas appliance**. In the UK,
> only a Gas Safe registered engineer may touch gas parts. Everything here is on
> the **low-voltage control terminals** only. If you aren't comfortable working
> near mains terminals, get an electrician or heating engineer to do it.

## Before opening anything

1. Turn the boiler off at its front panel.
2. **Isolate it at the fused spur**, switch off, and remove the fuse if the spur
   allows it. Leave a note on the spur.
3. Wait a few minutes for the pump to stop and anything hot to cool.
4. Prove it dead: the display must be off. Use a voltage tester on the 230 V terminals if you have one.
5. Take a photo of the terminal strip **before** you change anything.

## eBUS (the adapter stick)

- Vaillant ecoTEC boilers have an **eBUS** terminal pair on the control
  electronics' plug strip, usually marked **BUS** (sometimes `+`/`−`). It sits
  next to the 24 V room-stat terminals **3-4-5**. **Check your boiler's
  installation manual for the exact position**, because layouts vary between
  models and generations.
- Use **2-core cable, about 0.5–0.75 mm²**. **Polarity doesn't matter.**
- Bring the cable out through a cable gland or grommet and keep it away from mains cables.
- Mount the stick **outside** the boiler casing, where Wi-Fi reaches it. Power
  it from its own USB supply.
- If a Vaillant controller (VRC/sensoCOMFORT) is fitted, it shares the same bus.
  This build assumes **no** Vaillant controller on the eBUS.

## Room-stat terminals 3-4 (the Shelly relay)

On the ecoTEC tested here the low-voltage strip reads, left to right:
**Burner** (– ⊥, factory wire link) · **24V= RT** (factory wire link) · **BUS – +**,
with **RT 230V~** and **L N 230V~** further along.

- **24V= RT** is the 24 V room-stat loop: closed means heat demand. **Never
  connect 230 V to it.**
- **Remove the wire link** from 24V= RT and connect the Shelly's **O** and **I**
  (dry contacts) in its place. With the link in, the boiler calls for heat
  non-stop.
- **Leave the Burner link in.** That input is for an underfloor safety
  thermostat; opening it stops the burner.
- **RT 230V~** is a 230 V thermostat input. **Don't use it.**
- The Shelly is powered at **L/N from the boiler's fused spur**, which is mains
  wiring: get it done competently, with the spur isolated. Take the 12 V bench
  supply off first, and never connect both.
- If an eBUS controller such as tado was fitted, its cable to **BUS** can be
  reused for the stick. Remember the boiler then has no room control until the
  relay is in.

## Afterwards

Refit every cover, restore power, and check that the boiler starts normally
with no fault codes. Then check the stick's green LED is flashing.
