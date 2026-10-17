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

### Reading the Shelly 1 Gen4 label

| Terminal | Mains use (this job) | DC use (bench only) |
|---|---|---|
| **O**, **I** | Dry relay contact → boiler **24V= RT** | same |
| **SW** | leave empty | — |
| **12V** | leave empty | 12 V DC **+** |
| **L** | Live (230 V) | also **⊥** (−) for 12 V and 24–48 V DC |
| **N** | Neutral | also **+** for 24–48 V DC |

O and I are a dry contact (16 A/240 V~, 10 A/30 V DC). They switch the boiler's own
24 V loop and are separate from the Shelly's power. Relay on means O–I closed, which
means heat demand.

### Wiring

```
 FUSED SPUR (boiler supply)                SHELLY 1 GEN4  (own enclosure, outside the boiler)
   load side  L (brown) ───────────────────►  L
              N (blue)  ───────────────────►  N
              E (g/y)   ──► earth terminal in the enclosure (no earth on the Shelly)
                                              12V, SW ── empty
 BOILER LOW-VOLTAGE STRIP (ecoTEC example)
   Burner  [ ⊥ ][ – ]  factory link stays in      2-core 0.5–1.0 mm²
   24V= RT [ • ][ • ]  ◄── factory link out ───── O
                   ▲───────────────────────────── I     (either way round)
   BUS     [ – ][ + ]  eBUS stick
```

### Steps

1. Take the 12 V bench supply off the Shelly. **Never connect 12 V and mains together.**
2. Turn the boiler off, **isolate it at the fused spur (fuse out)**, and prove it dead.
3. **Low voltage:** run 2-core 0.5–1.0 mm² through a grommet, away from mains
   cables. Unplug **24V= RT**, remove the wire link, fit the two cores, refit the
   plug. Connect them to **O** and **I** at the Shelly. Leave the **Burner** link in.
   Never use **RT 230V~**.
4. **Mains** (BS 7671; use an electrician if you aren't competent): 3-core 1.0 mm²
   from the **load side of the boiler's fused spur** to the Shelly's enclosure.
   Brown → **L**, blue → **N**, earth to a terminal in the enclosure.
   Powering it from the spur means the boiler and the relay always lose and regain
   power together. A separate plug-in supply could fail on its own and leave the
   relay open, with no heat.
5. Mount the Shelly **outside the boiler casing** (the metal blocks Wi-Fi and
   Bluetooth, and it's hot inside), within Bluetooth range of the room sensor.
6. Refit the covers and restore power. The relay clicks **on** (power-on state);
   check that eBUS `DCRoomthermostat` reads `on`. Then run [testing.md](testing.md).

If an eBUS controller such as tado was fitted, its cable to **BUS** can be reused
for the stick. Remember the boiler then has no room control until the relay is in:
with the link in, it calls for heat non-stop.

## Afterwards

Refit every cover, restore power, and check that the boiler starts normally
with no fault codes. Then check the stick's green LED is flashing.
