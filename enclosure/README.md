# Heating box (Shelly 1 Gen4 + eBUS stick)

A wall box next to the boiler, **79 × 155 × 28.5 mm** outside, with 6 mm rounded corners, a rounded lid edge, a fine V line where the lid meets the base and a chamfered foot against the wall. Design: [`heating-box.scad`](heating-box.scad) (parametric OpenSCAD), sized from the parts measured on 2026-10-20. Ready-to-print STLs are in [`stl/`](stl/).

- **Left side, mains:** the fused-spur flex to the Shelly's **L/N**, with its earth core in a Wago 221 in the pocket. A clamp bar holds the flex so a pull can't reach the terminals. No vents on this side.
- **Right side, low voltage:** **O/I** to the boiler's 24V= RT, the eBUS pair, the stick and its USB-C lead. Vents are on the right-hand wall only.
- **Divider:** it runs up to just below the Shelly's terminal strip, meeting it between **L** and **12V**.
- **Lid:** four screws, so it needs a tool to open. It's marked **230 V / ISOLATE AT SPUR** over the mains side, and has ribs that hold the Shelly and the stick in place. Tongues on the lid close the cable slots down to each cable.
- **Wall fixing:** two countersunk No. 8 screws, both on the low-voltage side.

## Print
- **Material:** flame-retardant ABS (UL94 V-0).
- **Settings:** 0.2 mm layers, at least 5 perimeters (2.5 mm walls solid), 30 % infill, enclosure on the printer.
- **Orientation:**
  - `base`: floor down.
  - `lid`: already flipped, outer face down.
  - `clamp_mains`, `clamp_lv`: flat.
- **Test fit first:** print `testfit` (the floor plus 4 mm of walls) to check the Shelly, the stick, the Wago and the cable slots before the full base.
- **Export a part after changing a size:** `openscad -D 'part="base"' -o base.stl heating-box.scad`. Parts: base, lid, clamp_mains, clamp_lv, testfit. Previews: `assembly`, `inside`.

## Hardware
- 4 × M3 × 10 countersunk self-tapping screws for the lid.
- 4 × M3 × 12 self-tapping screws for the two clamps.
- 2 × No. 8 × 30 wall screws and plugs.
- 1 × Wago 221-413 for the earth.

## Fitting
**Isolate at the fused spur (fuse out) and prove it dead before touching L/N.** The wiring rules are in the public repo's `docs/02-wiring-safety.md`. If you're not competent with mains, have an electrician do the L/N side.

- The low-voltage clamp squeezes the round cable by 30 % and has two ridges on the floor either side of the bar, so the cable takes a slight S-bend. Tighten both screws evenly until the bar sits on its bosses.
- The sheath of each cable must run past its clamp into the box. Only the cores go to the terminals, kept short, with no bare copper showing at the Shelly.
- The flex is flat 2-core (5.5 × 3.3 mm), so there's no earth core and the Wago pocket isn't needed. Set `earth_pocket = false` to drop it, or just leave it empty. If you ever fit 3-core flex, its earth goes into a Wago there, since the Shelly has no earth terminal.
- Flat flex that size is usually 0.5 mm², which is only rated 3 A: check that the spur's fuse is 3 A.
- Unused **12V** and **SW** terminals: leave them empty, screws tightened down.
- Keep mains cores in the left compartment and low-voltage cores in the right; only the last few mm at the Shelly's terminal strip cross.
